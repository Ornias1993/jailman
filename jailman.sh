#!/usr/local/bin/bash

# Important defines:
SCRIPT_NAME="$(basename "$(test -L "${BASH_SOURCE[0]}" && readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")");"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd);
export SCRIPT_NAME
export SCRIPT_DIR

# shellcheck source=includes/libstrict.sh
source "${SCRIPT_DIR}/includes/libstrict.sh"

strict::mode

echo "Working directory for jailman.sh is: ${SCRIPT_DIR}"

#Includes
# shellcheck source=includes/init_functions.sh
source "${SCRIPT_DIR}/includes/init_functions.sh"

# shellcheck source=includes/global_functions.sh
source "${SCRIPT_DIR}/includes/global_functions.sh"

# shellcheck source=includes/blueprint_functions.sh
source "${SCRIPT_DIR}/includes/blueprint_functions.sh"

usage() {
	echo "Usage:"
	echo "$0"
	echo "-h"
	echo "   Help (this output)"
	echo "-i [_jailname] [_jailname1] ... [_jailnameN]"
	echo "   Install jails"
	echo "-r [_jailname] [_jailname1] ... [_jailnameN]"
	echo "   Reinstall jails (destroy then create)"
	echo "-u [_jailname] [_jailname1] ... [_jailnameN]"
	echo "   Run jail upgrade script"
	echo "-d [_jailname] [_jailname1] ... [_jailnameN]"
	echo "   Destroy jails"
	echo "-g [_jailname] [_jailname1] ... [_jailnameN]"
	echo "    Update the jail and any packages inside"
	echo ""
	echo " Examples:"
	echo ""
	echo "    # $0 -i plex"
	echo "      Install plex"
	echo ""
	echo "    # $0 -d plex transmission"
	echo "      Uninstall (DESTROY) plex and transmission"
}

# Check for root privileges
if ! [ "$(id -u)" = 0 ]; then
	echo "This script must be run with root privileges"
	exit 1
fi

# Auto Update
gitupdate

# If no option is given, point to the help menu
if [ $# -eq 0 ]
then
	echo "Missing options!"
	echo "(run $0 -h for help)"
	echo ""
	exit 0
fi

# Go through the options and put the jails requested in an array
unset -v sub
args=("$@")
arglen=${#args[@]}

installjails=()
redojails=()
updatejails=()
destroyjails=()
upgradejails=()
while getopts ":i:r:u:d:g:h" opt
do
	#Shellcheck on wordsplitting will be disabled. Wordsplitting can't happen, because it's already split using OPTIND.
	case $opt in
		i ) installjails=("$OPTARG")
			until (( OPTIND > arglen )) || [[ ${args[$OPTIND-1]} =~ ^-.* ]]; do
				installjails+=("${args[$OPTIND-1]}")
				OPTIND=$((OPTIND + 1))
			done
			;;
		r ) redojails=("$OPTARG")
			until (( OPTIND > arglen )) || [[ ${args[$OPTIND-1]} =~ ^-.* ]]; do
				redojails+=("${args[$OPTIND-1]}")
				OPTIND=$((OPTIND + 1))
			done
			;;
		u ) updatejails=("$OPTARG")
			until (( OPTIND > arglen )) || [[ ${args[$OPTIND-1]} =~ ^-.* ]]; do
				updatejails+=("${args[$OPTIND-1]}")
				OPTIND=$((OPTIND + 1))
			done
			;;
		d ) destroyjails=("$OPTARG")
			until (( OPTIND > arglen )) || [[ ${args[$OPTIND-1]} =~ ^-.* ]]; do
				destroyjails+=("${args[$OPTIND-1]}")
				OPTIND=$((OPTIND + 1))
			done
			;;
		g ) upgradejails=("$OPTARG")
			until (( OPTIND > arglen )) || [[ ${args[$OPTIND-1]} =~ ^-.* ]]; do
				upgradejails+=("${args[$OPTIND-1]}")
				OPTIND=$((OPTIND + 1))
			done
			;;
		h ) 
			usage
			exit 3
			;;
		* ) echo "Error: Invalid option was specified -$OPTARG"
			usage
			exit 3
			;;
	esac
done

# auto detect iocage install location
global_dataset_iocage=$(zfs get -H -o value mountpoint "$(iocage get -p)"/iocage)
global_dataset_iocage=${global_dataset_iocage#/mnt/}
export global_dataset_iocage

# load all config
load_config

if [ "${global_version:-}" != "1.3" ]; then
	echo "You are using old config.yml syntax."
	echo "Please check the wiki for required changes"
	exit 1
fi

# Check and Execute requested jail destructions
if [ ${#destroyjails[@]} -gt 0 ]; then
	echo "jails to destroy" "${destroyjails[@]}"
	for jail in "${destroyjails[@]}"
	do
		iocage destroy -fR "${jail}" || warn "destroy failed for ${jail}"
		cleanupblueprint "${jail}"
	done
fi

# Check and Execute requested jail Installs
if [ ${#installjails[@]} -gt 0 ]; then
	echo "jails to install" "${installjails[@]}"
	for jail in "${installjails[@]}"
	do
		blueprint=jail_${jail}_blueprint
		if [ -z "${!blueprint:-}" ]
		then
			echo "Config for ${jail} in config.yml incorrect. Please check your config."
			exit 1
		elif [ -f "${SCRIPT_DIR}/blueprints/${!blueprint}/install.sh" ]
		then
			echo "Installing $jail"
			jailcreate "${jail}" "${!blueprint}" && "${SCRIPT_DIR}"/blueprints/"${!blueprint}"/install.sh "${jail}"
		else
			echo "Missing blueprint ${!blueprint} for $jail in ${SCRIPT_DIR}/blueprints/${!blueprint}/install.sh"
			exit 1
		fi
	done
fi

# Check and Execute requested jail Reinstalls
if [ ${#redojails[@]} -gt 0 ]; then
	echo "jails to reinstall" "${redojails[@]}"
	for jail in "${redojails[@]}"
	do
		blueprint=jail_${jail}_blueprint
		if [ -z "${!blueprint:-}" ]
		then
			echo "Config for ${jail} in config.yml incorrect. Please check your config."
			exit 1
		elif [ -f "${SCRIPT_DIR}/blueprints/${!blueprint}/install.sh" ]
		then
			echo "Reinstalling $jail"
			iocage destroy -fR "${jail}" && cleanupblueprint "${jail}" && jailcreate "${jail}" "${!blueprint}" && "${SCRIPT_DIR}"/blueprints/"${!blueprint}"/install.sh "${jail}"
		else
			echo "Missing blueprint ${!blueprint} for $jail in ${SCRIPT_DIR}/blueprints/${!blueprint}/install.sh"
			exit 1
		fi
	done
fi

# Check and Execute requested jail Updates
if [ ${#updatejails[@]} -gt 0 ]; then
	echo "jails to update" "${updatejails[@]}"
	for jail in "${updatejails[@]}"
	do
		blueprint=jail_${jail}_blueprint
		if [ -z "${!blueprint:-}" ]
		then
			echo "Config for ${jail} in config.yml incorrect. Please check your config."
			exit 1
		elif [ -f "${SCRIPT_DIR}/blueprints/${!blueprint}/update.sh" ]
		then
			echo "Updating $jail"
			iocage update "${jail}"
			iocage exec "${jail}" "pkg update && pkg upgrade -y" && "${SCRIPT_DIR}"/blueprints/"${!blueprint}"/update.sh "${jail}"
			iocage restart "${jail}"
		else
			echo "Missing blueprint ${!blueprint} for $jail in ${SCRIPT_DIR}/blueprints/${!blueprint}/install.sh"
			exit 1
		fi
	done
fi

# Check and Execute requested jail Upgrades
if [ ${#upgradejails[@]} -gt 0 ]; then
	echo "jails to update" "${upgradejails[@]}"
	for jail in "${upgradejails[@]}"
	do
		blueprint=jail_${jail}_blueprint
		if [ -z "${!blueprint:-}" ]
			then
			echo "Config for ${jail} in config.yml incorrect. Please check your config."
			exit 1
		elif [ -f "${SCRIPT_DIR}/blueprints/${!blueprint}/update.sh" ]
		then
			echo "Currently Upgrading is not yet included in this script."
		else
			echo "Currently Upgrading is not yet included in this script."
			exit 1
		fi
	done
fi
