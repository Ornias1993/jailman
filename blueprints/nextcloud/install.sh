#!/usr/local/bin/bash
# This script installs the current release of Nextcloud into a create jail
# Based on the example by danb35: https://github.com/danb35/freenas-iocage-nextcloud

initblueprint "$1"

# Initialise defaults
cert_type="${cert_type:-SELFSIGNED_CERT}"
cert_email="${cert_email:-placeholder@email.fake}"
mariadb_database="${mariadb_database:-$1}"
mariadb_user="${mariadb_user:-$mariadb_database}"

# Database Defaults
DB_HOST="jail_${link_mariadb}_ip4_addr"
DB_HOST="${!DB_HOST%/*}:3306"

#####
# 
# Input Sanity Check 
#
#####

if [ "$cert_type" != "STANDALONE_CERT" ] && [ "$cert_type" != "DNS_CERT" ] && [ "$cert_type" != "NO_CERT" ] && [ "$cert_type" != "SELFSIGNED_CERT" ]; then
  echo 'Configuration error, cert_type options: STANDALONE_CERT, DNS_CERT, NO_CERT or SELFSIGNED_CERT'
  exit 1
fi

if [ "$cert_type" == "DNS_CERT" ]; then
	if [ -z "${dns_plugin}" ] ; then
		echo "DNS_PLUGIN must be set to a supported DNS provider."
		echo "See https://caddyserver.com/docs under the heading of \"DNS Providers\" for list."
		echo "Be sure to omit the prefix of \"tls.dns.\"."
		exit 1
	elif [ -z "${dns_env}" ] ; then
		echo "DNS_ENV must be set to a your DNS provider\'s authentication credentials."
		echo "See https://caddyserver.com/docs under the heading of \"DNS Providers\" for more."
		exit 1
	else
		DL_FLAGS="tls.dns.${DNS_PLUGIN}"
		DNS_SETTING="dns ${DNS_PLUGIN}"
	fi 
fi  

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

fetch -o /tmp https://getcaddy.com
if ! iocage exec "${1}" bash -s personal "${DL_FLAGS}" < /tmp/getcaddy.com
then
	echo "Failed to download/install Caddy"
	exit 1
fi

iocage exec "${1}" sysrc redis_enable="YES"
iocage exec "${1}" sysrc php_fpm_enable="YES"


#####
# 
# Install Nextcloud
#
#####

FILE="latest-18.tar.bz2"
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


# Generate and install self-signed cert, if necessary
if [ "$cert_type" == "SELFSIGNED_CERT" ] && [ ! -f "/mnt/${global_dataset_config}/${1}/ssl/privkey.pem" ]; then
	echo "No ssl certificate present, generating self signed certificate"
	if [ ! -d "/mnt/${global_dataset_config}/${1}/ssl" ]; then
		echo "cert folder not existing... creating..."
		iocage exec "${1}" mkdir /config/ssl
	fi
		openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=${host_name}" -keyout "${includes_dir}"/privkey.pem -out "${includes_dir}"/fullchain.pem
	cp "${includes_dir}"/privkey.pem /mnt/"${global_dataset_iocage}"/jails/"$1"/root/config/ssl/privkey.pem
	cp "${includes_dir}"/fullchain.pem /mnt/"${global_dataset_iocage}"/jails/"$1"/root/config/ssl/fullchain.pem
fi

# Copy and edit pre-written config files
cp "${includes_dir}"/php.ini /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/php.ini
cp "${includes_dir}"/redis.conf /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/redis.conf
cp "${includes_dir}"/www.conf /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/php-fpm.d/

if [ "$cert_type" == "STANDALONE_CERT" ] && [ "$cert_type" == "DNS_CERT" ]; then
	cp "${includes_dir}"/remove-staging.sh /mnt/"${global_dataset_iocage}"/jails/"$1"/root/root/
fi

if [ "$cert_type" == "NO_CERT" ]; then
	echo "Copying Caddyfile for no SSL"
	cp "${includes_dir}"/Caddyfile-nossl /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/www/Caddyfile
elif [ "$cert_type" == "SELFSIGNED_CERT" ]; then
	echo "Copying Caddyfile for self-signed cert"
	cp "${includes_dir}"/Caddyfile-selfsigned /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/www/Caddyfile
else
	echo "Copying Caddyfile for Let's Encrypt cert"
	cp "${includes_dir}"/Caddyfile /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/www/
fi

cp "${includes_dir}"/caddy.rc /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/rc.d/caddy

iocage exec "${1}" sed -i '' "s/yourhostnamehere/${host_name}/" /usr/local/www/Caddyfile
iocage exec "${1}" sed -i '' "s/DNS-PLACEHOLDER/${DNS_SETTING}/" /usr/local/www/Caddyfile
iocage exec "${1}" sed -i '' "s/JAIL-IP/${ip4_addr%/*}/" /usr/local/www/Caddyfile
iocage exec "${1}" sed -i '' "s|mytimezone|${time_zone}|" /usr/local/etc/php.ini

iocage exec "${1}" sysrc caddy_enable="YES"
iocage exec "${1}" sysrc caddy_cert_email="${cert_email}"
iocage exec "${1}" sysrc caddy_SNI_default="${host_name}"
iocage exec "${1}" sysrc caddy_env="${dns_env}"

iocage restart "${1}"

if [ "${reinstall}" = "true" ]; then
	echo "Reinstall detected, skipping generaion of new config and database"
else
	
	# Secure database, create Nextcloud DB, user, and password
	iocage exec "mariadb" mysql -u root -e "CREATE DATABASE ${mariadb_database};"
	iocage exec "mariadb" mysql -u root -e "GRANT ALL ON ${mariadb_database}.* TO ${mariadb_user}@${ip4_addr%/*} IDENTIFIED BY '${mariadb_password}';"
	iocage exec "mariadb" mysqladmin reload
	
	
	# Save passwords for later reference
	iocage exec "${1}" echo "Nextcloud database password is ${mariadb_password}" >> /root/"${1}"_mariadb_password.txt
	iocage exec "${1}" echo "Nextcloud Administrator password is ${ADMIN_PASSWORD}" >> /root/"${1}"_mariadb_password.txt
	
	# CLI installation and configuration of Nextcloud
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ maintenance:install --database=\"mysql\" --database-name=\"${mariadb_database}\" --database-user=\"${mariadb_user}\" --database-pass=\"${mariadb_password}\" --database-host=\"${DB_HOST}\" --admin-user=\"admin\" --admin-pass=\"${admin_password}\" --data-dir=\"/config/files\""
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ config:system:set mysql.utf8mb4 --type boolean --value=\"true\""
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ db:add-missing-indices"
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ db:convert-filecache-bigint --no-interaction"
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ config:system:set logtimezone --value=\"${time_zone}\""
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set log_type --value="file"'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set logfile --value="/var/log/nextcloud.log"'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set loglevel --value="2"'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set logrotate_size --value="104847600"'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set memcache.local --value="\OC\Memcache\APCu"'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set redis host --value="/tmp/redis.sock"'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set redis port --value=0 --type=integer'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set memcache.locking --value="\OC\Memcache\Redis"'
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ config:system:set overwritehost --value=\"${host_name}\""
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ config:system:set overwriteprotocol --value=\"https\""
	if [ "$cert_type" == "NO_CERT" ]; then
		iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ config:system:set overwrite.cli.url --value=\"http://${host_name}/\""
	else
		iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ config:system:set overwrite.cli.url --value=\"https://${host_name}/\""
	fi
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set htaccess.RewriteBase --value="/"'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:update:htaccess'
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ config:system:set trusted_domains 1 --value=\"${host_name}\""
	iocage exec "${1}" su -m www -c "php /usr/local/www/nextcloud/occ config:system:set trusted_domains 2 --value=\"${ip4_addr%/*}\""
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ app:enable encryption'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ encryption:enable'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ encryption:disable'
	iocage exec "${1}" su -m www -c 'php /usr/local/www/nextcloud/occ background:cron'
	
fi

iocage exec "${1}" touch /var/log/nextcloud.log
iocage exec "${1}" chown www /var/log/nextcloud.log
iocage exec "${1}" su -m www -c 'php -f /usr/local/www/nextcloud/cron.php'
iocage exec "${1}" crontab -u www /mnt/includes/www-crontab

exitblueprint "$1" "Nextcloud is accessible at ${urltype}://${host_name}"

if [ "$cert_type" == "NO_CERT" ]; then
  urltype="http"
else
  urltype="https"
fi

if [ "${reinstall}" = "true" ]; then
	echo "You did a reinstall, please use your old database and account credentials"
else

	echo "Default user is admin, password is ${ADMIN_PASSWORD}"
	echo ""

	echo "Database Information"
	echo "--------------------"
	echo "Database user = ${mariadb_user}"
	echo "Database password = ${mariadb_password}"
	echo ""
	echo "All passwords are saved in /root/${1}_mariadb_password.txt"
fi

echo ""
if [ "$cert_type" == "STANDALONE_CERT" ] && [ "$cert_type" == "DNS_CERT" ]; then
  echo "You have obtained your Let's Encrypt certificate using the staging server."
  echo "This certificate will not be trusted by your browser and will cause SSL errors"
  echo "when you connect.  Once you've verified that everything else is working"
  echo "correctly, you should issue a trusted certificate.  To do this, run:"
  echo "iocage exec ${1}/root/remove-staging.sh"
  echo ""
elif [ "$cert_type" == "SELFSIGNED_CERT" ]; then
  echo "You have chosen to create a self-signed TLS certificate for your Nextcloud"
  echo "installation.  This certificate will not be trusted by your browser and"
  echo "will cause SSL errors when you connect.  If you wish to replace this certificate"
  echo "with one obtained elsewhere, the private key is located at:"
  echo "/config/ssl/privkey.pem"
  echo "The full chain (server + intermediate certificates together) is at:"
  echo "/config/ssl/fullchain.pem"
  echo ""
fi