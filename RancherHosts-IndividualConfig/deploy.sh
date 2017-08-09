#!/bin/bash

set -e

usage() {

cat << EOF
usage: $0 options

This script install either the puppet master or client.

  OPTIONS:
    -n hostname
    -e rancherEnvironment
    -l Azure Deployment Location (Default: uksouth)
    -s vmSize (Default: "Standard_DS2_v2")
    -t rancher token
    -u adminUser
    -k SSH Publickey to push to the host
    -d disk Size (Default: 128)

EOF
}

while getopts ":hn:e:l:s:t:u:k:d:" opt; do
  case $opt in
    h)
      usage
      exit 1
      ;;
    n)
      RANCHER_HOST=$OPTARG
      ;;
    e)
      RANCHER_ENV=$OPTARG
      ;;
    l)
      LOCATION=$OPTARG
      ;;
    s)
      VM_SIZE=$OPTARG
      ;;
    t)
      RANCHER_JOIN_TOKEN=$OPTARG
      ;;
    u)
      ADMIN_USER=$OPTARG
      ;;
    k)
      PUBKEY_DEPLOY=$OPTARG
      ;;
    d)
      VM_OSDISK_SIZE=$OPTARG
      ;;

   esac
done

TRAFFIC_MANAGER_RSG="nhsuk-common"
INITIAL_LOCATION="uksouth"

if [ -z "$VM_SIZE" ]; then
  VM_SIZE="Standard_DS2_v2"
fi

if [ -z "$LOCATION" ]; then
  LOCATION="uksouth"
fi

if [ -z "$VM_OSDISK_SIZE" ]; then
  VM_OSDISK_SIZE="128"
fi

if [ -z "$RANCHER_ENV" ]; then
  echo "Rancher Env must be set"
  usage
  exit 1;
fi

if [ -z "$RANCHER_HOST" ]; then
  echo "Rancher Host must be set"
  usage
  exit 1;
fi

if [ -z "$RANCHER_JOIN_TOKEN" ]; then
  echo "Rancher Join Token must be set"
  usage
  exit 1;
fi

if [ -z "$ADMIN_USER" ]; then
  echo "Admin User must be set"
  usage
  exit 1;
fi


RSG="$RANCHER_HOST"
RANCHER_LABELS="provider=azure&location=$LOCATION"

SSHKEY_TEMP="$(mktemp -u)"
ssh-keygen -b 4096 -f "$SSHKEY_TEMP" -N '' -q
SSHKEY_PUB="$(cat "${SSHKEY_TEMP}.pub")"


echo "Creating Resource Group"
az group create \
  --location $INITIAL_LOCATION \
  --name "$RSG" \
  --tags rancher_env="$RANCHER_ENV"

# CHECK TM EXISTS, IF NOT, CREATE
az network traffic-manager profile show -n "$RANCHER_ENV" -g "$TRAFFIC_MANAGER_RSG" | grep name
if [ $? -ne 0 ]; then
  echo "Creating Traffic Manager"
  az network traffic-manager profile create \
    --resource-group "$TRAFFIC_MANAGER_RSG" \
    --name "$RANCHER_ENV" \
    --routing-method performance \
    --unique-dns-name "$RANCHER_ENV" \
    --monitor-port 8000 \
    --monitor-protocol http \
    --monitor-path '/dashboard/' \
    --tags "rancher_env=$RANCHER_ENV"
fi

echo "Creating VM"
az group deployment create \
  --resource-group "$RSG" \
  --name "$RANCHER_HOST" \
  --template-file vm.json \
  --parameters \
    vmName="$RANCHER_HOST" \
    rancherEnvironment="$RANCHER_ENV" \
    storageType=Premium_LRS \
    vmSize="$VM_SIZE" \
    adminUser="$ADMIN_USER" \
    location="$LOCATION" \
    diskSize="$VM_OSDISK_SIZE" \
    adminPublicKey="$SSHKEY_PUB"


FQDN=$(az vm show -g "$RSG" -n "$RANCHER_HOST" --query "fqdns" -o tsv -d)
PUBLIC_IP_ID=$(az network public-ip show -n "ip_$RANCHER_HOST" -g "$RSG" --query "id" -o tsv)

echo "Adding to $RANCHER_ENV traffic manager"
az network traffic-manager endpoint create \
  --name "$RANCHER_HOST" \
  --profile-name "$RANCHER_ENV" \
  --resource-group "$TRAFFIC_MANAGER_RSG" \
  --target-resource-id "$PUBLIC_IP_ID" \
  --type azureEndpoints

# CLEAR SSH KNOWN HOSTS, AND DISABLE STRICT HOST KEY CHECKING
if [ -f "~/.ssh/known_hosts" ]; then
  rm ~/.ssh/known_hosts
fi
mkdir -p ~/.ssh/
echo -e "Host $FQDN\n  StrictHostKeyChecking no" >> ~/.ssh/config

# LOG ONTO HOST, THEN RUN SETUP
ssh -i "$SSHKEY_TEMP" choicesadmin@"$FQDN" << EOF

sudo mkdir -p /etc/docker/
echo -e "{\n  \"storage-driver\": \"overlay2\"\n}" | sudo tee /etc/docker/daemon.json

curl https://releases.rancher.com/install-docker/17.03.sh | sh

sudo apt-mark hold docker-ce


sudo sed -i -e '/ResourceDisk.Format/c\ResourceDisk.Format=y' -e '/ResourceDisk.EnableSwap/c\ResourceDisk.EnableSwap=y' -e '/ResourceDisk.SwapSizeMB/c\ResourceDisk.SwapSizeMB=4096' /etc/waagent.conf
sudo systemctl restart walinuxagent.service


sudo docker run -e CATTLE_HOST_LABELS='$RANCHER_LABELS' --rm --privileged -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/rancher:/var/lib/rancher rancher/agent:v1.2.5 https://rancher.nhschoices.net/v1/scripts/$RANCHER_JOIN_TOKEN


# REMOVE TEMPORARY SSH CONFIG
rm ~/.ssh/*

# DEPLOY PUBLIC KEY, IF SET
if [ -n "$PUBKEY_DEPLOY" ]; then
  echo "$PUBKEY_DEPLOY" > ~/.ssh/authorized_keys
  chmod 400 ~/.ssh/authorized_keys
fi

EOF

# REMOVE TEMPORARY KEY USED TO DEPLOY HOST
rm $SSHKEY_TEMP ${SSHKEY_TEMP}.pub
