# Custom Script for Linux
export HOST_IP=$(ip addr show eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*')

export RANCHER_SERVER_URL=$1
export RANCHER_TOKEN=$2
export RANCHER_LABELS=$3

export RANCHER_AGENT_DOCKER_IMAGE='rancher/agent:v1.2.0'

# INSTALL DOCKER
curl https://releases.rancher.com/install-docker/1.12.sh | sh
sleep 5

# RUN RANCHER SERVER
sudo docker run -d --privileged \
                -e CATTLE_AGENT_IP=${HOST_IP} \
                -e CATTLE_HOST_LABELS="${RANCHER_LABELS}" \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -v /var/lib/rancher:/var/lib/rancher \
                ${RANCHER_AGENT_DOCKER_IMAGE} \
                ${RANCHER_SERVER_URL}/v1/scripts/${RANCHER_TOKEN}
