# Custom Script for Linux
export HOST_IP=$(ip addr show eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*')

export RANCHER_SERVER_URL=$1
export RANCHER_TOKEN=$2
export RANCHER_LABELS=$3

export RANCHER_AGENT_DOCKER_IMAGE='rancher/agent:v1.2.1'

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

# RUN RANCHER SERVER
sudo docker run -d --privileged \
                -e CATTLE_AGENT_IP=${HOST_IP} \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -v /var/lib/rancher:/var/lib/rancher \
                ${RANCHER_AGENT_DOCKER_IMAGE} \
                ${RANCHER_SERVER_URL}/v1/scripts/${RANCHER_TOKEN}
