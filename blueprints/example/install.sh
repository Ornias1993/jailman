#!/usr/local/bin/bash
# This file contains an example install script to base your own jails on

initblueprint "$1"

# Example jail content
echo "Testvar = ${testvar}"
echo "required testvar2 = ${testvar2}"