#!/usr/local/bin/bash
# This file contains the install script to install traefik as Jailman Reverse Proxy

# init blueprint
initblueprint "$1"

# Set default variable values
iptmp=${ip4_addr%/*}
domain_name="${domain_name:-$iptmp}"
productionurl="https://acme-v02.api.letsencrypt.org/directory"
stagingurl="https://acme-staging-v02.api.letsencrypt.org/directory"

# Copy the needed config files
iocage exec "${1}" mkdir /config/temp/
iocage exec "${1}" mkdir /config/dynamic/
cp "${includes_dir}"/traefik.toml /mnt/"${global_dataset_config}"/"${1}"/
cp "${includes_dir}"/firewall.rules /mnt/"${global_dataset_config}"/"${1}"/
cp "${includes_dir}"/ssl.yml /mnt/"${global_dataset_config}"/"${1}"/dynamic/

cp "${includes_dir}"/buildin_middlewares.toml /mnt/"${global_dataset_config}"/"${1}"/dynamic/buildin_middlewares.toml
if [ -z "$cert_wildcard_domain" ];
then
	echo "wildcard not set, using non-wildcard config..."
	cp "${includes_dir}"/dashboard.toml /mnt/"${global_dataset_config}"/"${1}"/dynamic/dashboard.toml
else
	echo "wildcard set, using wildcard config..."
	cp "${includes_dir}"/dashboard_wildcard.toml /mnt/"${global_dataset_config}"/"${1}"/dynamic/dashboard.toml
fi

# Create DNS verification env-vars (as required by traefik)
mkdir -p /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/rc.conf.d
dnsenv=$(printenv | grep "jail_${1}_cert_env_" | grep -o 'env_.*' | cut -f2- -d_ | tr "\n" " "; echo)
iocage exec "$1" sysrc "traefik_env=${dnsenv}"

# Replace placeholders with actual config
iocage exec "${1}" sed -i '' "s|placeholderemail|${cert_email}|" /config/traefik.toml
iocage exec "${1}" sed -i '' "s|placeholderprovider|${dns_provider}|" /config/traefik.toml
iocage exec "${1}" sed -i '' "s|placeholderdashboardhost|${domain_name}|" /config/dynamic/dashboard.toml
iocage exec "${1}" chown -R traefik:traefik /config

if [ -z "$cert_wildcard_domain" ];
then
	echo "wildcard not set, not enabling wildcard config..."
else
	echo "wildcard set, enabling wildcard config..."
	iocage exec "${1}" sed -i '' "s|placeholderwildcard|${cert_wildcard_domain}|" /config/dynamic/dashboard.toml
fi

if [ -z "$cert_staging" ] || [ "$cert_staging" = "false" ];
then
	echo "staging not set, using production server for LetsEncrypt"
	iocage exec "${1}" sed -i '' "s|leserverplaceholder|${productionurl}|" /config/traefik.toml
else
	echo "staging set, using staging server for LetsEncrypt"
	iocage exec "${1}" sed -i '' "s|leserverplaceholder|${stagingurl}|" /config/traefik.toml
fi

if [ -z "$cert_strict_sni" ] || [ "$cert_strict_sni" = "false" ];
then
	echo "Strict SNI not set. Keeping strict SNI disabled..."
else
	echo "Strict SNI set to ENABLED. Enabling Strict SNI."
	echo "      sniStrict: true" >> /config/dynamic/ssl.yml
fi

if [ -z "$dashboard" ] || [ "$dashboard" = "false" ];
then
	echo "dashboard disabled. Keeping the dashboard disabled..."
	iocage exec "${1}" sed -i '' "s|dashplaceholder|false|" /config/traefik.toml
else
	echo "Dashboard set to on, enabling dashboard"
	iocage exec "${1}" sed -i '' "s|dashplaceholder|true|" /config/traefik.toml
fi

# Setup services
iocage exec "$1" sysrc "traefik_conf=/config/traefik.toml"
iocage exec "$1" sysrc "traefik_enable=YES"
iocage exec "$1" sysrc "firewall_script=/config/firewall.rules"
iocage exec "$1" sysrc "firewall_enable=YES"
iocage exec "$1" service ipfw start
iocage exec "$1" service traefik start

if [ -z "$dashboard" ] || [ "$dashboard" = "false" ];
then
	exitblueprint "${1}" "Traefik installed successfully, but you can not connect to the dashboard, as you had it disabled."
else
	exitblueprint "${1}" "Traefik installed successfully, you can now connect to the traefik dashboard: https://${domain_name}"
fi

