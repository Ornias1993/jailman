#!/usr/bin/env bash

set -o errexit   # Exit on most errors
set -o errtrace  # Make sure any error trap is inherited
set -o nounset   # Disallow expansion of unset variables
set -o pipefail  # Use last non-zero exit code in a pipeline

trap "ERR during sabnzbd3 build" ERR

target=${1:-/usr/local/share/sabnzbd3}

cd "$target"
python3 -m venv venv
# shellcheck disable=SC1091
source venv/bin/activate
python3 -m pip install -r requirements.txt -U
python3 tools/make_mo.py
