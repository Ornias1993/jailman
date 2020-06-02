#!/usr/local/bin/bash 

# shellcheck source=libstrict.sh
source "${SCRIPT_DIR}/includes/libstrict.sh"
strict::mode

# yml Parser function
# Based on https://gist.github.com/pkuczynski/8665367
#
# This function is very picky and complex. Ignore with shellcheck for now.
# shellcheck disable=SC2086,SC2155
parse_yaml() {
	local prefix=${2:-}
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

# $1: config file
# $2: parsed config string to validate
validate_config() {
	file=${1:?}
	config=${2:?}
	if ! { sed -e s'/export //' | awk -F= '
		BEGIN {
			err = 0
		}
		$2 ~ /.*[[:space:]]"$/ {
			print "Value of key " $1 " has trailing whitespace: " $2; err = 1
		}
		$2 ~ /^"[[:space:]].*/ {
			print "Value of key " $1 " has leading whitespace: " $2; err = 1
		}
		$2 ~/\|/ {
			print "Value of Key " $1 " contains pipe symbol: " $2; err = 1
		}
		END {
			exit err
		}'; } <<< "${config}"
	then
		echo "Error parsing ${file}. Please review the warnings above."
		exit 1;
	fi
}

load_config() {
	# Parse the Config YAML
	for configpath in "${SCRIPT_DIR}"/blueprints/*/config.yml; do
		cfg=$(parse_yaml "${configpath}")
		validate_config "${configpath}" "$cfg"
		# shellcheck disable=SC2251
		! eval "$cfg"
	done

	cfg=$(parse_yaml "${SCRIPT_DIR}/includes/global.yml")
	validate_config "${SCRIPT_DIR}/includes/global.yml" "$cfg"
	eval "$cfg"

	cfg=$(parse_yaml "${SCRIPT_DIR}/config.yml")
	validate_config "${SCRIPT_DIR}/config.yml" "$cfg"
	eval "$cfg"
}

# automatic update function
gitupdate() {
	local gitbranch  branch

	gitbranch=$(git for-each-ref --format='%(upstream:short)' "$(git symbolic-ref -q HEAD)")
	branch=${gitbranch:-}

	if [ "$(git config --get remote.origin.url)" = "https://github.com/Ornias1993/jailman" ]
	then
		git remote set-url origin https://github.com/jailmanager/jailman
		echo "The repository has moved recently, we have pointed it to the right location."
		echo "Please invoke the script again."
		exit 1
	fi
	if [ -z "$branch" ] || [ "$branch" = "HEAD" ];
	then
		echo "Detatched or invalid GIT HEAD detected, please reinstall"
	else
		echo "checking for updates using Branch: $branch"
		git fetch > /dev/null 2>&1
		git update-index -q --refresh > /dev/null 2>&1
		CHANGED=$(git diff --name-only "$branch")
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

