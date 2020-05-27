#!/usr/local/bin/bash
# This file contains the install script for bitwarden

#init jail
initblueprint "$1"

# Initialise defaults
admin_token="${admin_token:-$(openssl rand -base64 16)}"
mariadb_database="${mariadb_database:-$1}"
mariadb_user="${mariadb_user:-$1}"


#TODO LINK
DB_HOST="jail_${link_mariadb}_ip4_addr"
DB_HOST="${!DB_HOST%/*}:3306"
DB_STRING="mysql://${mariadb_user}:${mariadb_password}@${DB_HOST}/${mariadb_database}"

# install latest rust version, pkg version is outdated and can't build bitwarden_rs
iocage exec "${1}" "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"

# Install Bitwarden_rs
iocage exec "${1}" mkdir -p /usr/local/share/bitwarden/src
iocage exec "${1}" git clone https://github.com/dani-garcia/bitwarden_rs/ /usr/local/share/bitwarden/src
TAG=$(iocage exec "${1}" "git -C /usr/local/share/bitwarden/src tag --sort=v:refname | tail -n1")
iocage exec "${1}" "git -C /usr/local/share/bitwarden/src checkout ${TAG}"

iocage exec "${1}" "cd /usr/local/share/bitwarden/src && $HOME/.cargo/bin/cargo build --features mysql --release"
iocage exec "${1}" "cd /usr/local/share/bitwarden/src && $HOME/.cargo/bin/cargo install diesel_cli --no-default-features --features mysql"
iocage exec "${1}" cp -r /usr/local/share/bitwarden/src/target/release /usr/local/share/bitwarden/bin

# Download and install webvault
WEB_RELEASE_URL=$(curl -Ls -o /dev/null -w "%{url_effective}" https://github.com/dani-garcia/bw_web_builds/releases/latest)
WEB_TAG="${WEB_RELEASE_URL##*/}"
iocage exec "${1}" "fetch http://github.com/dani-garcia/bw_web_builds/releases/download/$WEB_TAG/bw_web_$WEB_TAG.tar.gz -o /usr/local/share/bitwarden"
iocage exec "${1}" "tar -xzvf /usr/local/share/bitwarden/bw_web_$WEB_TAG.tar.gz -C /usr/local/share/bitwarden/"
iocage exec "${1}" rm /usr/local/share/bitwarden/bw_web_"$WEB_TAG".tar.gz

if [ -f "/mnt/${global_dataset_config}/${1}/ssl/bitwarden-ssl.crt" ]; then
    echo "certificate exist... Skipping cert generation"
else
	"No ssl certificate present, generating self signed certificate"
	if [ ! -d "/mnt/${global_dataset_config}/${1}/ssl" ]; then
		echo "cert folder not existing... creating..."
		iocage exec "${1}" mkdir /config/ssl
	fi
	openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=localhost" -keyout /mnt/"${global_dataset_config}"/"${1}"/ssl/bitwarden-ssl.key -out /mnt/"${global_dataset_config}"/"${1}"/ssl/bitwarden-ssl.crt
fi

if [ "${reinstall}" = "true" ]; then
	echo "Reinstall of Bitwarden detected... using existing config and database"
else
	echo "No config detected, doing clean install, utilizing the Mariadb database ${DB_HOST}"
	iocage exec "${link_mariadb}" mysql -u root -e "CREATE DATABASE ${mariadb_database};"
	iocage exec "${link_mariadb}" mysql -u root -e "GRANT ALL ON ${mariadb_database}.* TO ${mariadb_user}@${ip4_addr%/*} IDENTIFIED BY '${mariadb_password}';"
	iocage exec "${link_mariadb}" mysqladmin reload
fi

iocage exec "${1}" "pw user add bitwarden -c bitwarden -u 725 -d /nonexistent -s /usr/bin/nologin"
iocage exec "${1}" chown -R bitwarden:bitwarden /usr/local/share/bitwarden /config
iocage exec "${1}" mkdir /usr/local/etc/rc.d /usr/local/etc/rc.conf.d
cp -rf "${includes_dir}/bitwarden.rc" /mnt/"${global_dataset_iocage}"/jails/"${1}"/root/usr/local/etc/rc.d/bitwarden
cp -rf "${includes_dir}/bitwarden.rc.conf" /mnt/"${global_dataset_iocage}"/jails/"${1}"/root/usr/local/etc/rc.conf.d/bitwarden
echo 'export DATABASE_URL="'"${DB_STRING}"'"' >> /mnt/"${global_dataset_iocage}"/jails/"${1}"/root/usr/local/etc/rc.conf.d/bitwarden
echo 'export ADMIN_TOKEN="'"${admin_token}"'"' >> /mnt/"${global_dataset_iocage}"/jails/"${1}"/root/usr/local/etc/rc.conf.d/bitwarden

if [ "${admin_token}" == "NONE" ]; then
	echo "Admin_token set to NONE, disabling admin portal"
else
	echo "Admin_token set and admin portal enabled"
	iocage exec "${1}" echo "${DB_NAME} Admin Token is ${admin_token}" > /root/"${1}"_admin_token.txt
fi

iocage exec "${1}" chmod u+x /usr/local/etc/rc.d/bitwarden
iocage exec "${1}" sysrc "bitwarden_enable=YES"
iocage exec "${1}" service bitwarden restart


exitblueprint "$1" "Bitwarden is now accessible at https://${ip4_addr%/*}:8000"
echo "Admin Token is ${admin_token}"