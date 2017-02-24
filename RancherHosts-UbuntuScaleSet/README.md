# Rancher Hosts Templates

Arm template, which does the following:

- Provisions a VM scale set
- VMs are based on Ubuntu

### Connecting via SSH

The VMs **shouldn't** need to be configured or managed at all, as they should be disposable.

The VMs are available via an Azure loadBalancer which is created in the template. This load balancers NATs with the following rules:

- 50000 -> host1:22
- 50001 -> host2:22
- 50002 -> host3:22
- 50003 -> host4:22

There's also the following load balancers rules which direct traffic to every host (if TCPcheck passes):

- TCP 80   -> TCP 80
- TCP 443  -> TCP 443
- TCP 8000 -> TCP 8000 (for the traefik stats page)

The username and password is defined by the parameter file.

### How they work?

When the VMs start up they run the script, which is in the `CustomScript` directory in this repo. This basically installs docker and runs the `docker run` command which appears on Rancher GUI add hosts pages:

`sudo docker run -d --privileged -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/rancher:/var/lib/rancher rancher/agent:v1.2.0 https://rancher.nhschoices.net/v1/scripts/$RANCHER_TOKEN`
