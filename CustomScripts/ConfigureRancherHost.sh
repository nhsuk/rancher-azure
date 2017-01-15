# Custom Script for Linux
# update_engine_client -update
export RANCHER_SERVER_URL=$1
export RANCHER_ENV=$2
export RANCHER_TOKEN=$3
export RANCHER_AGENT_DOCKER_IMAGE='rancher/agent:v1.1.3'

sudo docker run -e CATTLE_HOST_LABELS="type=azurehost" -d --privileged -v /var/run/docker.sock:/var/run/docker.sock  ${RANCHER_AGENT_DOCKER_IMAGE} ${RANCHER_SERVER_URL}/v1/projects/${RANCHER_ENV}/scripts/${RANCHER_TOKEN}
