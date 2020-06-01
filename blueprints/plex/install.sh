#!/usr/local/bin/bash
# This file contains the install script for plex

#init jail
initblueprint "$1"

# Initialise defaults
hw_transcode_ruleset="${hw_transcode_ruleset:-10}"
script_default_path="/root/plex-ruleset.sh"
ruleset_script="${ruleset_script:-$script_default_path}"

# Source additional files with functions
# shellcheck source=blueprints/plex/includes/hw_transcoding.sh
source "${includes_dir}/hw_transcoding.sh"

# Change to to more frequent FreeBSD repo to stay up-to-date with plex more.
iocage exec plex mkdir -p /usr/local/etc/pkg/repos
cp "${includes_dir}"/FreeBSD.conf /mnt/"${global_dataset_iocage}"/jails/"$1"/root/usr/local/etc/pkg/repos/FreeBSD.conf


# Check if datasets for media librarys exist, create them if they do not.
createmount "$1" "${global_dataset_media}" /mnt/media
createmount "$1" "${global_dataset_media}"/movies /mnt/media/movies
createmount "$1" "${global_dataset_media}"/music /mnt/media/music
createmount "$1" "${global_dataset_media}"/shows /mnt/media/shows

# Create plex ramdisk if specified
if [ -z "${ramdisk}" ]; then
	echo "no ramdisk specified for plex, continuing without ramdisk"
else
	iocage fstab -a "$1" tmpfs /tmp_transcode tmpfs rw,size="${plex_ramdisk}",mode=1777 0 0
fi

# Create and install hardware transcoding ruleset script
if [ -z "${hw_transcode}" ] || [ "${hw_transcode}" = "false" ]; then
  echo "Not configuring hardware transcode"
else
  if createrulesetscript "${hw_transcode_ruleset}" "${ruleset_script}"; then
    echo "Configuring hardware transcode with ruleset ${hw_transcode_ruleset}."
	iocage set devfs_ruleset="${hw_transcode_ruleset}" "${1}"
  else
    echo "Not configuring hardware transcode automatically, please do it manually."
  fi
fi

iocage exec "$1" chown -R plex:plex /config

# Force update pkg to get latest plex version
iocage exec "$1" pkg update
iocage exec "$1" pkg upgrade -y

# Add plex user to video group for future hw-encoding support
iocage exec "$1" pw groupmod -n video -m plex

# Add plex user to media group for media accessible
iocage exec "$1" pw groupmod -n media -m plex

# Run different install procedures depending on Plex vs Plex Beta
if [ "$beta" == "true" ]; then
	echo "beta enabled in config.yml... using plex beta for install"
	iocage exec "$1" sysrc "plexmediaserver_plexpass_enable=YES"
	iocage exec "$1" sysrc plexmediaserver_plexpass_support_path="/config"
	iocage exec "$1" chown -R plex:plex /usr/local/share/plexmediaserver-plexpass/
	iocage exec "$1" service plexmediaserver_plexpass restart
else
	echo "beta disabled in config.yml... NOT using plex beta for install"
	iocage exec "$1" sysrc "plexmediaserver_enable=YES"
	iocage exec "$1" sysrc plexmediaserver_support_path="/config"
	iocage exec "$1" chown -R plex:plex /usr/local/share/plexmediaserver/
	iocage exec "$1" service plexmediaserver restart
fi

# Work around a FreeBSD 11.3 devfs issue
if [ -z "${hw_transcode}" ] || [ "${hw_transcode}" = "false" ]; then
  iocage stop "${1}"
  service devfs restart
  iocage start "${1}"
else
  iocage restart "${1}"
fi

exitblueprint "${1}" "Plex is now accessible at http://${jail_ip}:32400/web/"

