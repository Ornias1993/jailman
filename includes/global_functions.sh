#!/usr/local/bin/bash
# shellcheck disable=SC1003

jailcreate() {
	local jail  blueprint

	jail=${1:?}
	blueprint=${2:?}

	if [ -z "$jail" ] || [ -z "$blueprint" ]; then
		echo "jail and blueprint are required"
		exit 1
	fi

	echo "Checking config..."
	local blueprintpkgs blueprintports jailinterfaces jailip4 jailgateway jaildhcp setdhcp blueprintextraconf jailextraconf setextra reqvars reqvars

	blueprintpkgs="blueprint_${blueprint}_pkgs"
	blueprintports="blueprint_${blueprint}_ports"
	jailinterfaces="jail_${jail}_interfaces"
	jailip4="jail_${jail}_ip4_addr"
	jailgateway="jail_${jail}_gateway"
	jaildhcp="jail_${jail}_dhcp"
	setdhcp=${!jaildhcp}
	blueprintextraconf="blueprint_${blueprint}_custom_iocage"
	jailextraconf="jail_${jail}_custom_iocage"
	setextra="${!blueprintextraconf:-}${!jailextraconf:+ ${!jailextraconf}}"
	reqvars=blueprint_${blueprint}_reqvars
	reqvars="${!reqvars:-}${global_jails_reqvars:+ ${!global_vars_reqvars}}"

	for reqvar in $reqvars
	do
		varname=jail_${jail}_${reqvar}
		if [ -z "${!varname}" ]; then
			echo "$varname can't be empty"
			exit 1
		fi
	done

	if [ -z "${!jailinterfaces:-}" ]; then
		jailinterfaces="vnet0:bridge0"
	else
		jailinterfaces=${!jailinterfaces}
	fi
if [ -z "${setdhcp}" ] && [ -z "${!jailip4}" ] && [ -z "${!jailgateway}" ]; then
		echo 'no network settings specified in config.yml, defaulting to dhcp="on"'
		setdhcp="on"
	fi

	echo "Creating jail for $jail"
	pkgs="$(sed 's/[^[:space:]]\{1,\}/"&"/g;s/ /,/g' <<<"${global_jails_pkgs:?} ${!blueprintpkgs}")"
	echo '{"pkgs":['"${pkgs}"']}' > /tmp/pkg.json
	if [ "${setdhcp}" == "on" ] || [ "${setdhcp}" == "override" ]
	then
		if ! iocage create -n "${jail}" -p /tmp/pkg.json -r "${global_jails_version:?}" interfaces="${jailinterfaces}" dhcp="on" vnet="on" allow_raw_sockets="1" boot="on" ${setextra:+"$setextra"} -b
		then
			echo "Failed to create jail"
			exit 1
		fi
	else
		if ! iocage create -n "${jail}" -p /tmp/pkg.json -r "${global_jails_version}" interfaces="${jailinterfaces}" ip4_addr="vnet0|${!jailip4}" defaultrouter="${!jailgateway}" vnet="on" allow_raw_sockets="1" boot="on" ${setextra:+"$setextra"} -b
		then
			echo "Failed to create jail"
			exit 1
		fi
	fi

	rm /tmp/pkg.json
	echo "creating jail config directory"
	createmount "${jail}" "${global_dataset_config}" || exit 1
	createmount "${jail}" "${global_dataset_config}"/"${jail}" /config || exit 1

	# Create and Mount portsnap
	createmount "${jail}" "${global_dataset_config}"/portsnap || exit 1
	createmount "${jail}" "${global_dataset_config}"/portsnap/db /var/db/portsnap || exit 1
	createmount "${jail}" "${global_dataset_config}"/portsnap/ports /usr/ports || exit 1
	if [ "${!blueprintports:-}" == "true" ]
	then
		echo "Mounting and fetching ports"
		iocage exec "${jail}" "if [ -z /usr/ports ]; then portsnap fetch extract; else portsnap auto; fi"
	else
		echo "Ports not enabled for blueprint, skipping"
	fi

	echo "Jail creation completed for ${jail}"
}

createmount() {
	local jail dataset mountpoint fstab

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
				if ! iocage fstab -a "${jail}" /mnt/"${dataset}" "${mountpoint}" "${fstab}"; then
					echo "ERR creating mount. jail=${jail} dataset=${dataset} mountpoint=${mountpoint} fstab=${fstab}"
					exit 1
				fi
			else
				if ! iocage fstab -a "${jail}" /mnt/"${dataset}" "${mountpoint}" nullfs rw 0 0; then
					echo "ERR creating mount. jail=${jail} dataset=${dataset} mountpoint=${mountpoint}"
					exit 1
				fi
			fi
		else
			echo "No Jail Name or Mount target specified, not mounting dataset"
		fi

	fi
}
export -f createmount

