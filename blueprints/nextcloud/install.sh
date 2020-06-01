#!/usr/local/bin/bash
# This script installs the current release of Nextcloud into a create jail

initblueprint "$1"

# Initialise defaults
domain_name="${domain_name:-${jail_ip}}"
mariadb_database="${mariadb_database:-$1}"
mariadb_user="${mariadb_user:-$mariadb_database}"


#####
# 
# Fstab And Mounts
#
#####

# Create and Mount Nextcloud, Config and Files
createmount "${1}" "${global_dataset_config}"/"${1}"/config /usr/local/www/nextcloud/config
createmount "${1}" "${global_dataset_config}"/"${1}"/themes /usr/local/www/nextcloud/themes
createmount "${1}" "${global_dataset_config}"/"${1}"/files /config/files

iocage exec "${1}" chown -R www:www /config/files
iocage exec "${1}" chmod -R 770 /config/files


#####
# 
# Basic dependency install
#
#####


# Setup nginx
iocage exec "${1}" pw usermod www -G redis
cp "${includes_dir}"/www.conf /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/php-fpm.d/www.conf
iocage exec "$1" sed -i '' -e 's?listen = 127.0.0.1:9000?listen = /var/run/php-fpm.sock?g' /usr/local/etc/php-fpm.d/www.conf
iocage exec "$1" sed -i '' -e 's/;listen.owner = www/listen.owner = www/g' /usr/local/etc/php-fpm.d/www.conf
iocage exec "$1" sed -i '' -e 's/;listen.group = www/listen.group = www/g' /usr/local/etc/php-fpm.d/www.conf
iocage exec "$1" sed -i '' -e 's/;listen.mode = 0660/listen.mode = 0600/g' /usr/local/etc/php-fpm.d/www.conf
cp "${includes_dir}"/php.ini /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/php.ini
mv /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/nginx/nginx.conf /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/nginx/nginx.conf.bak
cp "${includes_dir}"/nginx.conf /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/nginx/nginx.conf
iocage exec "$1" sed -i '' -e "s/localhost/${domain_name}/g" /usr/local/etc/nginx/nginx.conf
cp "${includes_dir}"/redis.conf /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/redis.conf

iocage exec "${1}" sysrc redis_enable="YES"
iocage exec "${1}" sysrc nginx_enable="YES"
iocage exec "${1}" sysrc php_fpm_enable="YES"



iocage exec "${1}" sed -i '' "s|mytimezone|${time_zone}|" /usr/local/etc/php.ini

#####
# 
# Install Nextcloud
#
#####

FILE="latest-19.tar.bz2"
if ! iocage exec "${1}" fetch -o /tmp https://download.nextcloud.com/server/releases/"${FILE}" https://download.nextcloud.com/server/releases/"${FILE}".asc https://nextcloud.com/nextcloud.asc
then
	echo "Failed to download Nextcloud"
	exit 1
fi
iocage exec "${1}" gpg --import /tmp/nextcloud.asc
if ! iocage exec "${1}" gpg --verify /tmp/"${FILE}".asc
then
	echo "GPG Signature Verification Failed!"
	echo "The Nextcloud download is corrupt."
	exit 1
fi
iocage exec "${1}" tar xjf /tmp/"${FILE}" -C /usr/local/www/
iocage exec "${1}" chown -R www:www /usr/local/www/nextcloud/


iocage restart "${1}"

if [ "${reinstall}" = "true" ]; then
	echo "Reinstall detected, skipping generaion of new config and database"
else
	
	# Secure database, create Nextcloud DB, user, and password
	iocage exec "mariadb" mysql -u root -e "CREATE DATABASE ${mariadb_database};"
	iocage exec "mariadb" mysql -u root -e "GRANT ALL ON ${mariadb_database}.* TO ${mariadb_user}@${jail_ip} IDENTIFIED BY '${mariadb_password}';"
	iocage exec "mariadb" mysqladmin reload
	
	
	# Save passwords for later reference
	iocage exec "${1}" echo "Nextcloud database password is ${mariadb_password}" >> /root/"${1}"_mariadb_password.txt
	iocage exec "${1}" echo "Nextcloud Administrator password is ${ADMIN_PASSWORD}" >> /root/"${1}"_mariadb_password.txt
	
	# CLI installation and configuration of Nextcloud
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ maintenance:install --database=\"mysql\" --database-name=\"${mariadb_database}\" --database-user=\"${mariadb_user}\" --database-pass=\"${mariadb_password}\" --database-host=\"${link_mariadb_ip4_addr%/*}:3306\" --admin-user=\"admin\" --admin-pass=\"${admin_password}\" --data-dir=\"/config/files\""
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ config:system:set mysql.utf8mb4 --type boolean --value=\"true\""
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ db:add-missing-indices"
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ db:convert-filecache-bigint --no-interaction"
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ config:system:set logtimezone --value=\"${time_zone}\""
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set log_type --value="file"'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set logfile --value="/var/log/nextcloud.log"'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set loglevel --value="2"'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set logrotate_size --value="104847600"'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set memcache.local --value="\OC\Memcache\APCu"'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set redis host --value="/var/run/redis/redis.sock"'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set redis port --value=0 --type=integer'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set memcache.locking --value="\OC\Memcache\Redis"'
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ config:system:set overwritehost --value=\"${domain_name}\""
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ config:system:set overwriteprotocol --value=\"https\""
	if [ -z "$link_traefik" ];then
		iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ config:system:set overwrite.cli.url --value=\"http://${domain_name}/\""
	else
		iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ config:system:set overwrite.cli.url --value=\"https://${domain_name}/\""
	fi
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set htaccess.RewriteBase --value="/"'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:update:htaccess'
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ config:system:set trusted_domains 1 --value=\"${domain_name}\""
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ config:system:set trusted_domains 2 --value=\"${jail_ip}\""
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ app:enable encryption'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ encryption:enable'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ encryption:disable'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ background:cron'
	
fi

iocage exec "${1}" touch /var/log/nextcloud.log
iocage exec "${1}" chown www /var/log/nextcloud.log
iocage exec "${1}" su -m www -c 'php -f /usr/local/www/nextcloud/cron.php'
cp "${includes_dir}"/www-crontab /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/
iocage exec "${1}" crontab -u www /usr/local/etc/www-crontab

exitblueprint "$1"

if [ "${reinstall}" = "true" ]; then
	echo "You did a reinstall, please use your old database and account credentials"
else

	echo "Default user is admin, password is ${!ADMIN_PASSWORD}"
	echo ""

	echo "Database Information"
	echo "--------------------"
	echo "Database user = ${mariadb_user}"
	echo "Database password = ${mariadb_password}"
	echo ""
	echo "All passwords are saved in /root/${1}_mariadb_password.txt"
fi