# Custom Script for Linux
export HOST_IP=$(ip addr show eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*')

export RANCHER_SERVER_URL=$1
export RANCHER_ENV=$2
export RANCHER_TOKEN=$3
export CATTLE_HOST_LABELS=$4
export RANCHER_AGENT_DOCKER_IMAGE='rancher/agent:v1.1.3'

sudo docker run -e CATTLE_HOST_LABELS=${CATTLE_HOST_LABELS} -e CATTLE_AGENT_IP=${HOST_IP} -d --privileged -v /var/run/docker.sock:/var/run/docker.sock  ${RANCHER_AGENT_DOCKER_IMAGE} ${RANCHER_SERVER_URL}/v1/projects/${RANCHER_ENV}/scripts/${RANCHER_TOKEN}
