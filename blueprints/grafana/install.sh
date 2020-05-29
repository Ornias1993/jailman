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
  cp "${includes_dir}"/influxdb.yaml /mnt/"${global_dataset_config}"/"${1}"/provisioning/datasources
  iocage exec "${1}" sed -i '' "s|datasource_name|${datasource_name}|" /config/provisioning/datasources/influxdb.yaml
  iocage exec "${1}" sed -i '' "s|influxdb_ip|${link_influxdb_ip4_addr%/*}|" /config/provisioning/datasources/influxdb.yaml
  iocage exec "${1}" sed -i '' "s|datasource_db|${datasource_database}|" /config/provisioning/datasources/influxdb.yaml
  iocage exec "${1}" sed -i '' "s|datasource_user|${datasource_user}|" /config/provisioning/datasources/influxdb.yaml
  iocage exec "${1}" sed -i '' "s|datasource_pass|${datasource_password}|" /config/provisioning/datasources/influxdb.yaml
fi

# Set rc vars for startup and start grafana
iocage exec "${1}" sysrc grafana_conf="/config/grafana.conf"
iocage exec "${1}" sysrc grafana_enable="YES" 
iocage exec "${1}" service grafana start

exitblueprint "${1}" "Grafana is accessible at https://${ip4_addr%/*}:3000."
