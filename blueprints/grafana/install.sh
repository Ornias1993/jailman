#!/usr/local/bin/bash
#This file contains the install script for Grafana

#init jail
initblueprint "$1"

# Initialise defaults
user="${user:-$1}"

# Create config directories
iocage exec "${1}" mkdir -p /config/db
iocage exec "${1}" mkdir -p /config/logs
iocage exec "${1}" mkdir -p /config/plugins
iocage exec "${1}" mkdir -p /config/provisioning/datasources

# Setup basic config
cp "${includes_dir}"/grafana.conf /mnt/"${global_dataset_config}"/"${1}"
iocage exec "${1}" sed -i '' "s|jail_password|${password}|" /config/grafana.conf
iocage exec "${1}" chown -R grafana:grafana /config

# Setup connection to influxdb, if necessary
if [ -n "${link_influxdb}" ]; then
	if [ -n "${link_unifi}" ]; then
		cp "${includes_dir}"/influxdb.yaml /mnt/"${global_dataset_config}"/"${1}"/provisioning/datasources/unifi.yaml
		iocage exec "${1}" sed -i '' "s|datasource_name|unifi|" /config/provisioning/datasources/unifi.yaml
		iocage exec "${1}" sed -i '' "s|influxdb_ip|${link_influxdb_ip4_addr%/*}|" /config/provisioning/datasources/unifi.yaml
		iocage exec "${1}" sed -i '' "s|datasource_db|${link_unifi_influxdb_database:-$link_unifi}|" /config/provisioning/datasources/unifi.yaml
		iocage exec "${1}" sed -i '' "s|datasource_user|${link_unifi_influxdb_user:-$link_unifi}|" /config/provisioning/datasources/unifi.yaml
		iocage exec "${1}" sed -i '' "s|datasource_pass|${link_unifi_influxdb_password:-}|" /config/provisioning/datasources/unifi.yaml
	fi
else
	echo "Sorry, can't setup any grafana connections for you, as you didn't specify link_influxdb correctly..."
fi

# Set rc vars for startup and start grafana
iocage exec "${1}" sysrc grafana_conf="/config/grafana.conf"
iocage exec "${1}" sysrc grafana_enable="YES" 
iocage exec "${1}" service grafana start

exitblueprint "${1}"
