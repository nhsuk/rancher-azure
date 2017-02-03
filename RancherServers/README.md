# Rancher Server Template

Arm template, which does the following:

- Provisions 3 Virtual Machines, with Linux
- All in an availibility group, to allow load balancing and HA.
- Uses the `choices-ansible` ansible credentials.

### Connecting via SSH/Ansible
The VMs aren't publically exposed to the internet. To access them via SSH, you need to connect through the public IP/DNS (or rancher.nhschoices.net) for the load balancer, which NATs the following ports:

- 40221 -> ch-p-rch01:22
- 40222 -> ch-p-rch02:22
- 40223 -> ch-p-rch03:22

### Ansible Rancher config deployment

The Rancher server runs in Docker, and needs a MySQL v5.7 server to run.

Currently we deploy a MySQL docker image on `ch-p-rch01` and use `/docker-data/mysql_data/` as the data directory for the MySQL files.

`ch-p-rch01/2/3` run rancher in HA mode, and connect to `ch-p-rch01` as the data source. Rancher publishes port `8080` over HTTP.

To enable HTTPS we run `nginx` on each host, which:

1. Redirects port 80 to 443.
2. Terminates SSL on port 443.
3. Sends traffic to the backend rancher-server docker container

The ansible config (`https://git.nhschoices.net/Infrastructure/choices-ansible`)

### Backups

All the rancher server configuration is stored in a MySQL database, so that's the only thing we need to backup.

Backups are done using a MySQL container in a cron job `/etc/cron.daily/rancher-mysql-backup`.

This uses the azurefilevolume docker driver which enables us to put the backups at rancherbackups storage account, in a file share.

### Restore the backups!

Download the backup from the rancherbackups storage account, run `MYSQL_PWD='$MYSQL_PASSWORD' mysql $MYSQL_DB -h $MYSQL_HOST -u$MYSQL_USER < $BACKUP_FILE"`

`gunzip < $BACKUP_FILE | MYSQL_PWD='$MYSQL_PASSWORD' mysql $MYSQL_DB -h $MYSQL_HOST -u$MYSQL_USER"`

This can be done against a running MySQL docker container by doing the following:

`docker run -v $BACKUP_FILE:/backup.tgz --link ${CONTAINER_NAME}:db sh -c 'gunzip < /backup.tgz | MYSQL_PWD='$MYSQL_PASSWORD' mysql $MYSQL_DB -h db -u$MYSQL_USER"`
