# Custom Script for Linux
export HOST_IP=$(ip addr show eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*')

export RANCHER_SERVER_URL=$1
export RANCHER_ENVIRONMENT_NAME=$2
export ACCESS_KEY=$3
export SECRET_KEY=$4
export RANCHER_LABELS=$5

# DISABLE TRANSPARENT HUGEPAGE FILEs
# TODO: Make it persist across reboots
echo never > /sys/kernel/mm/transparent_hugepage/enabled

# CONFIGURE DOCKER SETTINGS
mkdir -p /etc/systemd/system/docker.service.d
echo """[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --storage-driver=overlay2
""" > /etc/systemd/system/docker.service.d/custom.conf

# INSTALL DOCKER
curl https://releases.rancher.com/install-docker/1.13.sh | sh
sleep 5


# GET RANCHER REGISTRY TOKEN
apt-get update && apt-get install -y jq
curl -u ${ACCESS_KEY}:${SECRET_KEY} ${RANCHER_SERVER_URL}/v2-beta/projects/ -o /tmp/rancher_envs.json
ENV_ID=$(jq --raw-output '.data[] | select(.name=="nhsuk_staging") | .id' /tmp/rancher_envs.json)

curl -u ${ACCESS_KEY}:${SECRET_KEY} ${RANCHER_SERVER_URL}/v2-beta/projects/${ENV_ID}/registrationtokens -o /tmp/rancher_specific_env.json
RANCHER_AGENT_DOCKER_IMAGE=$(jq --raw-output '.data[] | .image' /tmp/rancher_specific_env.json)
RANCHER_REGISTER_TOKEN=$(jq --raw-output '.data[] | .token' /tmp/rancher_specific_env.json)

# RUN RANCHER SERVER
sudo docker run -d --privileged \
                -e CATTLE_AGENT_IP=${HOST_IP} \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -v /var/lib/rancher:/var/lib/rancher \
                ${RANCHER_AGENT_DOCKER_IMAGE} \
                ${RANCHER_SERVER_URL}/v1/scripts/${RANCHER_TOKEN}
