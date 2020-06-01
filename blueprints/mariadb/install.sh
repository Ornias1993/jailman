#!/usr/local/bin/bash
# This script installs the current release of Mariadb and PhpMyAdmin into a created jail

#init jail
initblueprint "$1"

# Initialise defaults
cert_email="${cert_email:-placeholder@email.fake}"
DL_FLAGS=""
DNS_ENV=""

# Mount database dataset and set zfs preferences
iocage exec "${1}" rm -Rf /usr/local/etc/mysql/my.cnf
createmount "${1}" "${global_dataset_config}"/"${1}"/db /config/db
zfs set recordsize=16K "${global_dataset_config}"/"${1}"/db
zfs set primarycache=metadata "${global_dataset_config}"/"${1}"/db

iocage exec "${1}" "pw groupadd -n mysql -g 88"
iocage exec "${1}" "pw useradd -n mysql -u 88 -d /nonexistent -s /usr/sbin/nologin -g mysql"

iocage exec "${1}" chown -R mysql:mysql /config

iocage exec "${1}" sysrc mysql_optfile=/config/my.cnf
iocage exec "${1}" sysrc mysql_dbdir=/config/db
iocage exec "${1}" sysrc mysql_pidfile=/config/mysql.pid
iocage exec "${1}" sysrc mysql_enable="YES"
iocage exec "${1}" mkdir -p /usr/local/www/phpmyadmin
iocage exec "${1}" chown -R www:www /usr/local/www/phpmyadmin

cp "${includes_dir}"/my.cnf /mnt/"${global_dataset_iocage}"/jails/"$1"/root/config/my.cnf
iocage exec "${1}" sed -i '' "s|mypassword|${root_password}|" /config/my.cnf
iocage exec "${1}" ln -s /config/my.cnf /usr/local/etc/mysql/my.cnf

iocage exec "${1}" sysrc mysql_enable="YES"

# Setup nginx
cp "${includes_dir}"/config.inc.php /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/www/phpMyAdmin/config.inc.php
iocage exec "$1" sed -i '' -e 's?listen = 127.0.0.1:9000?listen = /var/run/php-fpm.sock?g' /usr/local/etc/php-fpm.d/www.conf
iocage exec "$1" sed -i '' -e 's/;listen.owner = www/listen.owner = www/g' /usr/local/etc/php-fpm.d/www.conf
iocage exec "$1" sed -i '' -e 's/;listen.group = www/listen.group = www/g' /usr/local/etc/php-fpm.d/www.conf
iocage exec "$1" sed -i '' -e 's/;listen.mode = 0660/listen.mode = 0600/g' /usr/local/etc/php-fpm.d/www.conf
iocage exec "$1" cp /usr/local/etc/php.ini-production /usr/local/etc/php.ini
iocage exec "$1" sed -i '' -e 's?;date.timezone =?date.timezone = "Universal"?g' /usr/local/etc/php.ini
iocage exec "$1" sed -i '' -e 's?;cgi.fix_pathinfo=1?cgi.fix_pathinfo=0?g' /usr/local/etc/php.ini
mv /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/nginx/nginx.conf /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/nginx/nginx.conf.bak
cp "${includes_dir}"/nginx.conf /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/nginx/nginx.conf
cp -Rf "${includes_dir}"/custom /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/nginx/custom

iocage exec "${1}" sysrc nginx_enable="YES"
iocage exec "${1}" sysrc php_fpm_enable="YES"

iocage restart "${1}"
sleep 10

if [ "${reinstall}" = "true" ]; then
	echo "Reinstall detected, skipping generaion of new config and database"
else
	# Secure database, set root password, create Nextcloud DB, user, and password

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

exitblueprint "$1"
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