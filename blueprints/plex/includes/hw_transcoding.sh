#!/usr/local/bin/bash
# This file contains the devfs setup for plex hardware transcoding

# ${1} = devfs ruleset number
# ${2} = script location
# Creates script for devfs ruleset and i915kms, causes it to execute on boot, and loads it
createrulesetscript() {
	
# Some input checks
  if [ -z "${1}" ] ; then
    echo "ERROR: No plex devfs ruleset number specified. This is an internal script error."
    return 1
  fi
  if [ -z "${2}" ] ; then
	  echo "ERROR: No plex ruleset script location specified."
    return 1
  fi
  IGPU_MODEL=$(lspci | grep Intel | grep Graphics) 
  if [ -n "${IGPU_MODEL}" ] ; then
    echo "Found Intel GPU model ${IGPU_MODEL}, this bodes well."
    if ! kldstat | grep -q i915kms.ko; then
      kldload /boot/modules/i915kms.ko
      if ! kldstat | grep -q i915kms.ko; then
        echo "Unable to load driver for Intel iGPU, please verify it is supported in this version of FreeNAS/TrueNAS"
        return 1
      fi
    fi
  else
    echo "The naive Intel iGPU check didn't find one."
    echo "If you know you have supported hardware, please send the authors of this script"
    echo "the output of \"lspci\" on your system, and we'll improve the detection logic."
    return 1
  fi 
  
# Create actual script if not already existing
  if [ ! -f "${2}" ] ; then
    echo "Creating script file ${2}"
    cat > "${2}" <<EOF
#!/bin/sh
echo '[devfsrules_bpfjail=101]
add path 'bpf*' unhide
[plex_drm=${1}]
add include \$devfsrules_hide_all
add include \$devfsrules_unhide_basic
add include \$devfsrules_unhide_login
add include \$devfsrules_jail
add include \$devfsrules_bpfjail
add path 'dri*' unhide
add path 'dri/*' unhide
add path 'drm*' unhide
add path 'drm/*' unhide' >> /etc/devfs.rules
service devfs restart
kldload /boot/modules/i915kms.ko
EOF
  chmod +x "${2}"
  else
    if ! grep -q "plex_drm=${1}" "${2}"; then
     echo "Script file ${2} exists, but does not configure devfs ruleset ${1} for Plex as expected."
     return 1
    fi
  fi
  if [ -z "$(devfs rule -s "${1}" show)" ]; then
    echo "Executing script file ${2}"
    ${2}
  fi

# Add the script to load on boot
  if ! midclt call initshutdownscript.query | grep -q "${2}"; then
    echo "Setting script ${2} to execute on boot"
    midclt call initshutdownscript.create "{\"type\": \"SCRIPT\", \"script\": \"${2}\", \"when\": \"POSTINIT\", \"enabled\": true, \"timeout\": 10}"
  fi
  return 0
}
export createrulesetscript