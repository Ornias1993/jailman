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
if [ "$(git config --get remote.origin.url)" = "https://github.com/Ornias1993/jailman" ]
then
	echo "The repository has been moved, please reinstall using the new repository: jailmanager/jailman"
	exit 1
fi
if [ "$1" = "" ] || [ "$1" = "HEAD" ];
then
	echo "Detatched or invalid GIT HEAD detected, please reinstall"
else
	echo "checking for updates using Branch: $1"
	git fetch > /dev/null 2>&1
	git update-index -q --refresh > /dev/null 2>&1
	CHANGED=$(git diff --name-only "$1")
	if [ -n "$CHANGED" ];
	then
		echo "script requires update"
		git reset --hard > /dev/null 2>&1
		git pull > /dev/null 2>&1
		echo "script updated, please restart the script manually"
		exit 1
	else
		echo "script up-to-date"
	fi
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
blueprintextraconf="$blueprint_${2}_custom_iocage"
jailextraconf="jail_${1}_custom_iocage"
setextra="${!blueprintextraconf} ${!jailextraconf}"
reqvars=blueprint_${2}_reqvars
reqvars="${!reqvars} ${global_jails_reqvars}"

for reqvar in $reqvars
do
	varname=jail_${1}_${reqvar}
	if [ -z "${!varname}" ]; then
	echo "$varname can't be empty"
	exit 1
	fi
done

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
pkgs="$(sed 's/[^[:space:]]\{1,\}/"&"/g;s/ /,/g' <<<"${global_jails_pkgs} ${!blueprintpkgs}")"
echo '{"pkgs":['"${pkgs}"']}' > /tmp/pkg.json
if [ "${setdhcp}" == "on" ]
then
	if ! iocage create -n "${1}" -p /tmp/pkg.json -r "${global_jails_version}" interfaces="${jailinterfaces}" dhcp="on" vnet="on" allow_raw_sockets="1" boot="on" ${setextra} -b
	then
		echo "Failed to create jail"
		exit 1
	fi
else
	if ! iocage create -n "${1}" -p /tmp/pkg.json -r "${global_jails_version}" interfaces="${jailinterfaces}" ip4_addr="vnet0|${!jailip4}" defaultrouter="${!jailgateway}" vnet="on" allow_raw_sockets="1" boot="on" ${setextra} -b
	then
		echo "Failed to create jail"
		exit 1
	fi
fi

rm /tmp/pkg.json
echo "creating jail config directory"
createmount "${1}" "${global_dataset_config}" || exit 1
createmount "${1}" "${global_dataset_config}"/"${1}" /config || exit 1


# Create and Mount portsnap
createmount "${1}" "${global_dataset_config}"/portsnap || exit 1
createmount "${1}" "${global_dataset_config}"/portsnap/db /var/db/portsnap || exit 1
createmount "${1}" "${global_dataset_config}"/portsnap/ports /usr/ports || exit 1
if [ "${!blueprintports}" == "true" ]
then
	echo "Mounting and fetching ports"
	iocage exec "${1}" "if [ -z /usr/ports ]; then portsnap fetch extract; else portsnap auto; fi"
else
	echo "Ports not enabled for blueprint, skipping"
fi

echo "Jail creation completed for ${1}"

}

initblueprint() {
	blueprint=jail_${1}_blueprint
	varlist=blueprint_${!blueprint}_vars

	for var in ${!varlist:-} ${global_jails_vars}
	do
		value="jail_${1}_$var"
		val=${!value:-}
		declare -g "${var}=${val}"

		if [[ "${var}" =~ ^link_.* ]]; 
		then
			linkblueprint=jail_${val}_blueprint
			linkvarlist=blueprint_${!linkblueprint}_vars
			for linkvar in ${!linkvarlist} ${global_jails_vars}
			do
				linkvalue="jail_${val}_${linkvar}"
				linkval=${!linkvalue:-}
				declare -g "${var}_${linkvar}=${linkval}"
			done
		fi
	done

	declare -g "jail_root=/mnt/${global_dataset_iocage}/jails/$1/root"
	declare -g "blueprint_dir=${SCRIPT_DIR}/blueprints/${!blueprint}"
	declare -g "includes_dir=${SCRIPT_DIR}/blueprints/${!blueprint}/includes"

	if [ -f "/mnt/${global_dataset_config}/${1}/INSTALLED" ]; then
	    echo "Reinstall detected..."
		declare -g reinstall="true"
	elif [ "$(ls -A "/mnt/${global_dataset_config}/${1}/")" ]; then
	    echo "ERROR, No valid install detected in config directory but files present"
		exit 1
	else
		echo "No reinstall flag detected, continuing normal install"
	fi

	if [ -z "${ip4_addr}" ]; then
		DEFAULT_IF=$(iocage exec "$1" route get default | awk '/interface/ {print $2}')
		declare -g "jail_ip=$(iocage exec "$1" ifconfig "$DEFAULT_IF" | awk '/inet/ { print $2 }')"
	else
		declare -g "jail_ip=${ip4_addr%/*}"
	fi
}
export -f initblueprint


exitblueprint() {
blueprint="jail_${1}_blueprint" 
traefik_service_port="blueprint_${!blueprint}_traefik_service_port"
traefik_service_port="${!traefik_service_port}"
traefikincludes="${SCRIPT_DIR}/blueprints/traefik/includes"
traefikstatus=""

# Check if the jail is compatible with Traefik and copy the right default-config for the job.
if [ -z "${link_traefik}" ] || [ -z "${ip4_addr}" ]; then
	echo "Traefik-connection not enabled... Skipping connecting this jail to traefik"
else
	echo "removing old traefik config..."
	rm -f /mnt/"${global_dataset_config}"/"${link_traefik}"/dynamic/"${1}".toml
	rm -f /mnt/"${global_dataset_config}"/"${link_traefik}"/dynamic/"${1}"_auth_basic.toml
	rm -f /mnt/"${global_dataset_config}"/"${link_traefik}"/dynamic/"${1}"_auth_forward.toml
	if [ -z "${domain_name}" ]; then
		echo "domain_name required for connecting to traefik... please add domain_name to config.yml"
	elif [ -f "/mnt/${global_dataset_config}/${1}/traefik_custom.toml" ]; then
		echo "Found custom traefik configuration... Copying to traefik..."
		cp "${includes_dir}"/traefik_custom.toml /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}".toml
		traefikstatus="success"
	elif [ -f "${includes_dir}/traefik_custom.toml" ]; then
		echo "Found default traefik configuration for this blueprint... Copying to traefik..."
		cp "${includes_dir}"/traefik_custom.toml /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}".toml
		traefikstatus="preinstalled"
	elif [ -z "${traefik_service_port}" ]; then 
		echo "Can't connect this jail to traefik... Please add a traefik_service_port to this jail in config.yml..."
	else
		echo "No custom traefik configuration found, using default..."
		cp "${traefikincludes}"/default.toml /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}".toml
		traefikstatus="preinstalled"
	fi
fi

# If the default config requires post-processing (it always does except for user-custom config in /config), do the post processing.
if [ "${traefikstatus}" = "preinstalled" ]; then
	# replace placeholder values.
	sed -i '' "s|placeholderdashboardhost|${domain_name//&/\\&}|" /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}".toml
	sed -i '' "s|placeholdername|${1//&/\\&}|" /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}".toml
	sed -i '' "s|placeholderurl|${jail_ip}:${traefik_service_port}|" /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}".toml
	# also replace auth related placeholders, because they can be part of custom config files
	sed -i '' "s|placeholderusers|${traefik_auth_basic//&/\\&}|" /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}".toml
	sed -i '' "s|placeholderauthforward|${traefik_auth_forward//&/\\&}|" /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}".toml
	if [ -n "${traefik_auth_forward}" ] && [ -n "${traefik_auth_basic}" ]; then 
		echo "cant setup traefik with both basic AND forward auth. Please pick one only."
	elif [ -n "${traefik_auth_basic}" ]; then 
		echo "Adding basic auth to Traefik for jail ${1}"
		users="$(sed 's/[^[:space:]]\{1,\}/"&"/g;s/ /,/g' <<<"${traefik_auth_basic}")"
		cp "${traefikincludes}"/default_auth_basic.toml /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}"_auth_basic.toml
		sed -i '' "s|placeholdername|${1//&/\\&}|" /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}"_auth_basic.toml
		sed -i '' "s|placeholderusers|${users//&/\\&}|" /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}"_auth_basic.toml
		mv /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}"_auth_basic.toml /mnt/"${global_dataset_config}"/"${link_traefik}"/dynamic/"${1}"_auth_basic.toml
		sed -i '' "s|\"retry\"|\"retry\",\"${1//&/\\&}-basic-auth\"|" /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}".toml
		traefikstatus="success"
	elif [ -n "${traefik_auth_forward}" ]; then 
		echo "Adding forward auth to Traefik for jail ${1}"
		cp "${traefikincludes}"/default_auth_forward.toml /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}"_auth_forward.toml
		sed -i '' "s|placeholdername|${1//&/\\&}|" /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}"_auth_forward.toml
		sed -i '' "s|placeholderauthforward|${traefik_auth_forward//&/\\&}|" /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}"_auth_forward.toml
		mv /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}"_auth_forward.toml /mnt/"${global_dataset_config}"/"${link_traefik}"/dynamic/"${1}"_auth_forward.toml
		sed -i '' "s|\"retry\"|\"retry\",\"${1//&/\\&}-forward-auth\"|" /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}".toml
		traefikstatus="success"
	else
		echo "No auth specified, setting up traefik without auth..."
		traefikstatus="success"
	fi
	mv /mnt/"${global_dataset_config}"/"${link_traefik}"/temp/"${1}".toml /mnt/"${global_dataset_config}"/"${link_traefik}"/dynamic/"${1}".toml
fi

# Add a file to flag the jail is INSTALLED and thus trigger reinstall on next install
echo "DO NOT DELETE THIS FILE" >> "/mnt/${global_dataset_config}/${1}/INSTALLED"
echo "Jail $1 using blueprint ${!blueprint}, installed successfully."

# Pick the right success message to hint to user how to connect to the jail
if [ "${traefikstatus}" = "success" ]; then
	echo "Your jail ${1} running ${!blueprint} is now accessible via Traefik at https://${domain_name}"
elif [[ -n "${2}" ]]; then
	echo " ${2}"
elif [ -n "${traefik_service_port}" ]; then
	echo "Your jail ${1} running ${!blueprint} is now accessible at http://${jail_ip}:${traefik_service_port}"
else
	echo "Please consult the wiki for instructions connecting to your newly installed jail"
fi
}
export -f exitblueprint


createmount() {
	jail=${1:-}
	dataset=${2:-}
	mountpoint=${3:-}
	fstab=${4:-}

	if [ -z "${dataset}" ] ; then
		echo "ERROR: No Dataset specified to create and/or mount"
		exit 1
	else
		if [ ! -d "/mnt/${dataset}" ]; then
			echo "Dataset does not exist... Creating... ${dataset}"
			zfs create "${dataset}" || exit 1
		else
			echo "Dataset already exists, skipping creation of ${dataset}"
		fi

		if [ -n "${jail}" ] && [ -n "${mountpoint}" ]; then
			iocage exec "${jail}" mkdir -p "${mountpoint}"
			if [ -n "${fstab}" ]; then
				iocage fstab -a "${jail}" /mnt/"${dataset}" "${mountpoint}" "${fstab}" || exit 1
			else
				iocage fstab -a "${jail}" /mnt/"${dataset}" "${mountpoint}" nullfs rw 0 0 || exit 1
			fi
		else
			echo "No Jail Name or Mount target specified, not mounting dataset"
		fi

	fi
}
export -f createmount

