#!/usr/local/bin/bash
# This file contains an example install script to base your own jails on

initblueprint "$1"

# Initialise defaults
# You can add default values for the variables already loaded here.

# Example jail content
echo "Testvar = ${testvar}"
echo "required testvar2 = ${testvar2}"

echo "linked database ip: ${link_mariadb_ip4_addr}"

if [ "${reinstall}" = "true" ]; then
	echo "Reinstall detected..."
else
	echo "no reinstall detected, normal install proceeding..."
fi

exitblueprint "$1" "Exampleblueprint installation finished."
# you can add additional echo output (but only echo output) after the exitblueprint