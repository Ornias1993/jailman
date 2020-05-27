#!/usr/local/bin/bash
# This file contains the update script for transmission

#init jail
initblueprint "$1"

# Initialise defaults

iocage exec "$1" service transmission stop

# Transmision is updated during PKG update, this file is mostly just a placeholder
iocage exec "$1" chown -R transmission:transmission /config
iocage exec "$1" service transmission restart