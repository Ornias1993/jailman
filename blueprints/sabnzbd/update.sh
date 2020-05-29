#!/usr/local/bin/bash

initblueprint "$1"

iocage exec "$1" service sabnzbd stop
iocage exec "$1" chown -R _sabnzbd:_sabnzbd /config

iocage exec "$1" service sabnzbd restart
