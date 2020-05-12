#!/usr/local/bin/bash
# shellcheck disable=SC1003

# yml Parser function
# Based on https://gist.github.com/pkuczynski/8665367
#
# This function is very picky and complex. Ignore with shellcheck for now.
# shellcheck disable=SC2086,SC2155
parse_yaml() {
   local prefix=${2}
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  "${1}" |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("export %s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

# automatic update function
gitupdate() {
echo "checking for updates using Branch: $1"
git fetch
git update-index -q --refresh
CHANGED=$(git diff --name-only origin/"$1")
if [ -n "$CHANGED" ];
then
    echo "script requires update"
    git reset --hard
    git checkout "${1}"
    git pull
    echo "script updated, please restart the script manually"
    exit 1
else
    echo "script up-to-date"
fi
}

jailcreate() {
echo "Checking config..."
blueprintpkgs="blueprint_${2}_pkgs"
blueprintports="blueprint_${2}_ports"
jailinterfaces="jail_${1}_interfaces"
jailip4="jail_${1}_ip4_addr"
jailgateway="jail_${1}_gateway"
jaildhcp="jail_${1}_dhcp"
setdhcp=${!jaildhcp}
extraconf="${1}_extraconf"
setextra="${!extraconf}"

if [ -z "${!jailinterfaces}" ]; then 
	jailinterfaces="vnet0:bridge0"
else
	jailinterfaces=${!jailinterfaces}
fi

if [ -z "${setdhcp}" ] && [ -z "${!jailip4}" ] && [ -z "${!jailgateway}" ]; then 
	echo 'no network settings specified in config.yml, defaulting to dhcp="on"'
	setdhcp="on"
fi

echo "Creating jail for $1"
# shellcheck disable=SC2154
pkgs="$(sed 's/[^[:space:]]\{1,\}/"&"/g;s/ /,/g' <<<"${global_jails_pkgs} ${!blueprintpkgs}")"
echo '{"pkgs":['"${pkgs}"']}' > /tmp/pkg.json
if [ "${setdhcp}" == "on" ]
then
	# shellcheck disable=SC2154
	if ! iocage create -n "${1}" -p /tmp/pkg.json -r "${global_jails_version}" interfaces="${jailinterfaces}" dhcp="on" vnet="on" allow_raw_sockets="1" boot="on" -b
	then
		echo "Failed to create jail"
		exit 1
	fi
else
	# shellcheck disable=SC2154
	if ! iocage create -n "${1}" -p /tmp/pkg.json -r "${global_jails_version}" interfaces="${jailinterfaces}" ip4_addr="vnet0|${!jailip4}" defaultrouter="${!jailgateway}" vnet="on" allow_raw_sockets="1" boot="on" ${setextra} -b
	then
		echo "Failed to create jail"
		exit 1
	fi
fi

rm /tmp/pkg.json
echo "creating jail config directory"
# shellcheck disable=SC2154
createmount "${1}" "${global_dataset_config}"
createmount "${1}" "${global_dataset_config}"/"${1}" /config

# Create and Mount portsnap
createmount "${1}" "${global_dataset_config}"/portsnap
createmount "${1}" "${global_dataset_config}"/portsnap/db /var/db/portsnap
createmount "${1}" "${global_dataset_config}"/portsnap/ports /usr/ports
if [ "${!blueprintports}" == "true" ]
then
	echo "Mounting and fetching ports"
	iocage exec "${1}" "if [ -z /usr/ports ]; then portsnap fetch extract; else portsnap auto; fi"
else
	echo "Ports not enabled for blueprint, skipping"
fi

echo "Jail creation completed for ${1}"

}

# $1 = jail name
# $2 = Dataset
# $3 = Target mountpoint
# $4 = fstab prefernces
createmount() {
	if [ -z "$2" ] ; then
		echo "ERROR: No Dataset specified to create and/or mount"
		exit 1
	else
		if [ ! -d "/mnt/$2" ]; then
			echo "Dataset does not exist... Creating... $2"
			zfs create "${2}"
		else
			echo "Dataset already exists, skipping creation of $2"
		fi

		if [ -n "$1" ] && [ -n "$3" ]; then
			iocage exec "${1}" mkdir -p "${3}"
			if [ -n "${4}" ]; then
				iocage fstab -a "${1}" /mnt/"${2}" "${3}" "${4}"
			else
				iocage fstab -a "${1}" /mnt/"${2}" "${3}" nullfs rw 0 0
			fi
		else
			echo "No Jail Name or Mount target specified, not mounting dataset"
		fi

	fi
}
export -f createmount
