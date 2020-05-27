#!/usr/local/bin/bash
# This file contains the update script for Plex

#init jail
initblueprint "$1"

# Initialise defaults

# Run different update procedures depending on Plex vs Plex Beta
	if [ "$beta" == "true" ]; then
	echo "beta enabled in config.yml... using plex beta for update..."
	iocage exec "$1" service plexmediaserver_plexpass stop
	# Plex is updated using PKG already, this is mostly a placeholder
	iocage exec "$1" chown -R plex:plex /usr/local/share/plexmediaserver-plexpass/
	iocage exec "$1" service plexmediaserver_plexpass restart
else
	echo "beta disabled in config.yml... NOT using plex beta for update..."
	iocage exec "$1" service plexmediaserver stop
	# Plex is updated using PKG already, this is mostly a placeholder
	iocage exec "$1" chown -R plex:plex /usr/local/share/plexmediaserver/
	iocage exec "$1" service plexmediaserver restart
fi





