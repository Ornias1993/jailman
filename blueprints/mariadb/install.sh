#!/usr/local/bin/bash
# This script installs the current release of Mariadb and PhpMyAdmin into a created jail

#init jail
initblueprint "$1"

# Initialise defaults
cert_email="${cert_email:-placeholder@email.fake}"
DL_FLAGS=""
DNS_ENV=""

# Mount database dataset and set zfs preferences
iocage exec "${1}" service mysql-server stop
iocage exec "${1}" rm -Rf /var/db/mysql
createmount "${1}" "${global_dataset_config}"/"${1}"/db /var/db/mysql
zfs set recordsize=16K "${global_dataset_config}"/"${1}"/db
zfs set primarycache=metadata "${global_dataset_config}"/"${1}"/db

iocage exec "${1}" chown -R 88:88 /var/db/mysql

iocage exec "${1}" mkdir -p /usr/local/www/phpmyadmin
iocage exec "${1}" chown -R www:www /usr/local/www/phpmyadmin

#####
# 
# Install mariadb, Caddy and PhpMyAdmin
#
#####

fetch -o /tmp https://getcaddy.com
if ! iocage exec "${1}" bash -s personal "${DL_FLAGS}" < /tmp/getcaddy.com
then
	echo "Failed to download/install Caddy"
	exit 1
fi

iocage exec "${1}" sysrc mysql_enable="YES"

# Copy and edit pre-written config files
echo "Copying Caddyfile for no SSL"
cp "${includes_dir}"/caddy.rc /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/rc.d/caddy
cp "${includes_dir}"/Caddyfile /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/www/Caddyfile
iocage exec "${1}" sed -i '' "s/yourhostnamehere/${host_name}/" /usr/local/www/Caddyfile
iocage exec "${1}" sed -i '' "s/JAIL-IP/${ip4_addr%/*}/" /usr/local/www/Caddyfile

iocage exec "${1}" sysrc caddy_enable="YES"
iocage exec "${1}" sysrc php_fpm_enable="YES"
iocage exec "${1}" sysrc caddy_cert_email="${cert_email}"
iocage exec "${1}" sysrc caddy_env="${DNS_ENV}"

iocage restart "${1}"
sleep 10

if [ "${reinstall}" = "true" ]; then
	echo "Reinstall detected, skipping generaion of new config and database"
else
	
	# Secure database, set root password, create Nextcloud DB, user, and password
	cp "${includes_dir}"/my-system.cnf /mnt/"${global_dataset_iocage}"/jails/"$1"/root/var/db/mysql/my.cnf
	iocage exec "${1}" mysql -u root -e "DELETE FROM mysql.user WHERE User='';"
	iocage exec "${1}" mysql -u root -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
	iocage exec "${1}" mysql -u root -e "DROP DATABASE IF EXISTS test;"
	iocage exec "${1}" mysql -u root -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
	iocage exec "${1}" mysqladmin --user=root password "${root_password}"
	iocage exec "${1}" mysqladmin reload
	fi
cp "${includes_dir}"/my.cnf /mnt/"${global_dataset_iocage}"/jails/"$1"/root/root/.my.cnf
iocage exec "${1}" sed -i '' "s|mypassword|${root_password}|" /root/.my.cnf

# Save passwords for later reference
iocage exec "${1}" echo "MariaDB root password is ${root_password}" > /root/"${1}"_root_password.txt

exitblueprint "$1" "MariaDB is now accessible at http://${ip4_addr%/*}"
echo "All passwords are saved in /root/${1}_db_password.txt"
if [ "${reinstall}" = "true" ]; 
then
	echo "You did a reinstall, please use your old database and account credentials"
else
	echo "Database Information"
	echo "--------------------"
	echo "The MariaDB root password is ${root_password}"
	fi
echo ""