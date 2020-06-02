#!/usr/local/bin/bash

# Adapted from https://github.com/bpm-rocks/strict/blob/master/libstrict
strict::failure() (
	set +x
	local argsList argsLeft i nextArg err code

	err=$?
	code="${1:-1}"

	echo "ERR - status code $code" >&2
	echo "Command:  ${BASH_COMMAND:-unknown}" >&2
	echo "Location:  ${BASH_SOURCE[1]:-unknown}, line ${BASH_LINENO[0]:-unknown}" >&2
	echo "Status: ${err}" >& 2

	if [[ ${#PIPESTATUS[@]} -gt 1 ]]; then
		echo "Pipe status: " "${PIPESTATUS[@]}" >&2
	fi

	i=$#
	nextArg=$#

	if [[ $i -lt ${#BASH_LINENO[@]} ]]; then
		echo "Stack trace:" >&2
	else
		echo "Stack trace unavailable" >&2
	fi

	while [[ $i -lt ${#BASH_LINENO[@]} ]]; do
		argsList=()

		if [[ ${#BASH_ARGC[@]} -gt $i && ${#BASH_ARGV[@]} -ge $(( nextArg + BASH_ARGC[i] )) ]]; then
			for (( argsLeft = BASH_ARGC[i]; argsLeft; --argsLeft )); do
				# Note: this reverses the order on purpose
				argsList[$argsLeft]=${BASH_ARGV[nextArg]}
				(( nextArg ++ ))
			done

			if [[ ${#argsList[@]} -gt 0 ]]; then
				printf -v argsList " %q" "${argsList[@]}"
			else
				argsList=""
			fi

			if [[ ${#argsList} -gt 255 ]]; then
				argsList=${argsList:0:250}...
			fi
		else
			argsList=""
		fi

		echo "    [$i] ${FUNCNAME[i]:+${FUNCNAME[i]}(): }${BASH_SOURCE[i]}, line ${BASH_LINENO[i - 1]} -> ${FUNCNAME[i]:-${BASH_SOURCE[i]##*/}}$argsList" >&2
		(( i ++ ))
	done
)
export -f strict::failure

warn() {
	echo "$0:" "$@" >&2
}
export -f warn

strict::mode() {
	set -o errexit   # =set -e: Exit on most errors
	set -o errtrace  # =set -E: Make sure any error trap is inherited
	set -o nounset   # =set -u: Disallow expansion of unset variables
	set -o pipefail  #          Use last non-zero exit code in a pipeline
	# set -o functrace # =set -T: inherit DEBUG and RETURN traps

	# shopt -s extdebug
	trap 'strict::failure $?' ERR
	export SHELLOPTS # run blueprint scripts with same options
}
export -f strict::mode

