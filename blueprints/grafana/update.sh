#!/usr/local/bin/bash
# This file contains the update script for Grafana

iocage exec "${1}" service grafana stop
iocage exec "${1}" sysrc grafana_conf="/config/grafana.conf"
iocage exec "${1}" sysrc grafana_enable="YES"
iocage exec "${1}" service grafana start
