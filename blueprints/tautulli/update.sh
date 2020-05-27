#!/usr/local/bin/bash
# This file contains the update script for Tautulli

#init jail
initblueprint "$1"

# Initialise defaults

iocage exec "$1" service tautulli stop
# Tautulli is updated through pkg, this is mostly just a placeholder
iocage exec "$1" chown -R tautulli:tautulli /usr/local/share/Tautulli /config
iocage exec "$1" cp /usr/local/share/Tautulli/init-scripts/init.freenas /usr/local/etc/rc.d/tautulli
iocage exec "$1" chmod u+x /usr/local/etc/rc.d/tautulli
iocage exec "$1" service tautulli restart