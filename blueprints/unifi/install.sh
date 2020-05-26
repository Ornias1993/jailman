#!/usr/local/bin/bash
# This file contains the install script for unifi-controller & unifi-poller

#init jail
initblueprint "$1"

# Initialize variables
influxdb_database="${influxdb_database:-$1}"
influxdb_user="${influxdb_user:-$influxdb_database}"
poller_user="${poller_user:-$1}"

#TODO LINK
DB_IP="jail_${link_influxdb}_ip4_addr"
DB_IP="${!DB_IP%/*}"

# Enable persistent Unifi Controller data
iocage exec "${1}" mkdir -p /config/controller/mongodb
iocage exec "${1}" cp -Rp /usr/local/share/java/unifi /config/controller
iocage exec "${1}" chown -R mongodb:mongodb /config/controller/mongodb
cp "${includes_dir}"/mongodb.conf /mnt/"${global_dataset_iocage}"/jails/"${1}"/root/usr/local/etc
cp "${includes_dir}"/rc/mongod.rc /mnt/"${global_dataset_iocage}"/jails/"${1}"/root/usr/local/etc/rc.d/mongod
cp "${includes_dir}"/rc/unifi.rc /mnt/"${global_dataset_iocage}"/jails/"${1}"/root/usr/local/etc/rc.d/unifi
iocage exec "${1}" sysrc unifi_enable=YES
iocage exec "${1}" service unifi start

if [[ ! "${poller}" ]]; then
  echo "Unifi Poller not selected, skipping Unifi Poller installation."
else
	if [ -z "${influxdb_password}" ]; then
	echo "influxdb_password can't be empty"
	exit 1
	fi

	if [ -z "${link_influxdb}" ]; then
	echo "link_influxdb can't be empty"
	exit 1
	fi

	if [ -z "${poller_password}" ]; then
	echo "poller_password can't be empty"
	exit 1
	fi
  # Check if influxdb container exists, create unifi database if it does, error if it is not.
  echo "Installing Unifi Poller..."
  echo "Checking if the database jail and database exist..."
  if [[ -d /mnt/"${global_dataset_iocage}"/jails/"${link_influxdb}" ]]; then
    DB_EXISTING=$(iocage exec "${link_influxdb}" curl -G http://"${DB_IP}":8086/query --data-urlencode 'q=SHOW DATABASES' | jq '.results [] | .series [] | .values []' | grep "$influxdb_database" | sed 's/"//g' | sed 's/^ *//g')
    if [[ "$influxdb_database" == "$DB_EXISTING" ]]; then
      echo "${link_influxdb} jail with database ${influxdb_database} already exists. Skipping database creation... "
    else
      echo "${link_influxdb} jail exists, but database ${influxdb_database} does not. Creating database ${influxdb_database}."
      if [[ -z "${influxdb_user}" ]] || [[ -z "${influxdb_password}" ]]; then
        echo "Database username and password not provided. Cannot create database without credentials. Exiting..."
        exit 1
      else
        # shellcheck disable=SC2027,2086
        iocage exec "${link_influxdb}" "curl -XPOST -u ${influxdb_user}:${influxdb_password} http://"${DB_IP}":8086/query --data-urlencode 'q=CREATE DATABASE ${influxdb_database}'"
        echo "Database ${influxdb_database} created with username ${influxdb_user} with password ${influxdb_password}."
      fi
    fi
  else
    echo "Influxdb jail does not exist. Unifi-Poller requires Influxdb jail. Please install the Influxdb jail."
    exit 1
  fi

  # Download and install Unifi-Poller
  FILE_NAME=$(curl -s https://api.github.com/repos/unifi-poller/unifi-poller/releases/latest | jq -r ".assets[] | select(.name | contains(\"amd64.txz\")) | .name")
  DOWNLOAD=$(curl -s https://api.github.com/repos/unifi-poller/unifi-poller/releases/latest | jq -r ".assets[] | select(.name | contains(\"amd64.txz\")) | .browser_download_url")
  iocage exec "${1}" fetch -o /config "${DOWNLOAD}"

  # Install downloaded Unifi-Poller package, configure and enable 
  iocage exec "${1}" pkg install -qy /config/"${FILE_NAME}"
  cp "${includes_dir}"/up.conf /mnt/"${global_dataset_config}"/"${1}"
  cp "${includes_dir}"/rc/unifi_poller.rc /mnt/"${global_dataset_iocage}"/jails/"${1}"/root/usr/local/etc/rc.d/unifi_poller
  chmod +x /mnt/"${global_dataset_iocage}"/jails/"${1}"/root/usr/local/etc/rc.d/unifi_poller
  iocage exec "${1}" sed -i '' "s|influxdbuser|${influxdb_user}|" /config/up.conf
  iocage exec "${1}" sed -i '' "s|influxdbpass|${influxdb_password}|" /config/up.conf
  iocage exec "${1}" sed -i '' "s|unifidb|${influxdb_database}|" /config/up.conf
  iocage exec "${1}" sed -i '' "s|unifiuser|${poller_user}|" /config/up.conf
  iocage exec "${1}" sed -i '' "s|unifipassword|${poller_password}|" /config/up.conf
  iocage exec "${1}" sed -i '' "s|dbip|http://${DB_IP}:8086|" /config/up.conf


  iocage exec "${1}" sysrc unifi_poller_enable=YES
  iocage exec "${1}" service unifi_poller start

  echo "Please login to the Unifi Controller and add ${poller_user} as a read-only user."
  echo "In Grafana, add Unifi-Poller as a data source."
fi

exitblueprint "$1" "Unifi Controller is now accessible at https://${ip4_addr%/*}:8443"

