# Custom Script for Linux
export HOST_IP=$(ip addr show eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*')

export RANCHER_SERVER_URL=$1
export RANCHER_TOKEN=$2

export RANCHER_AGENT_DOCKER_IMAGE='rancher/agent:v1.2.2'
export SPLUNK_VERSION='6.6.2'
export SPLUNK_BUILD='4b804538c686'


# CONFIGURE DISK, IF DRIVE EXISTS, BUT PARTITION DOESN'T
if [ -b /dev/sdc ] && [ ! -b /dev/sdc1 ]; then
  parted --script /dev/sdc \
    mklabel gpt \
    mkpart primary ext4 1MiB 100%
  sync
  sleep 5
  mkfs.ext4 -m 1 /dev/sdc1
  mkdir -p /var/lib/docker
  echo "/dev/sdc1 /var/lib/docker ext4 defaults,noatime  0 2" >> /etc/fstab
  mount -a
fi

# UPGRADE SOFTWARE
apt-get update && apt-get upgrade -y

# DISABLE TRANSPARENT HUGEPAGE FILEs
# TODO: Make it persist across reboots
echo never > /sys/kernel/mm/transparent_hugepage/enabled

# Set mmap count for elastic-serch
sysctl -w vm.max_map_count=262144
echo "vm.max_map_count = 262144" > /etc/sysctl.d/99-mmap-count.conf

# CONFIGURE DOCKER SETTINGS
mkdir -p /etc/systemd/system/docker.service.d
echo """[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --storage-driver=overlay2
""" > /etc/systemd/system/docker.service.d/custom.conf

# INSTALL SPLUNk
wget https://download.splunk.com/products/universalforwarder/releases/${SPLUNK_VERSION}/linux/splunkforwarder-${SPLUNK_VERSION}-${SPLUNK_BUILD}-linux-2.6-amd64.deb
dpkg -i splunkforwarder-${SPLUNK_VERSION}-${SPLUNK_BUILD}-linux-2.6-amd64.deb

/opt/splunkforwarder/bin/splunk enable boot-start
/opt/splunkforwarder/bin/splunk start --accept-license --answer-yes

# INSTALL DOCKER
curl https://releases.rancher.com/install-docker/17.03.sh | sh
sleep 5

# RUN RANCHER SERVER
sudo docker run --rm --privileged \
                -e CATTLE_AGENT_IP=${HOST_IP} \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -v /var/lib/rancher:/var/lib/rancher \
                ${RANCHER_AGENT_DOCKER_IMAGE} \
                ${RANCHER_SERVER_URL}/v1/scripts/${RANCHER_TOKEN}
