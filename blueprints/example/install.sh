#!/usr/local/bin/bash
# This file contains an example install script to base your own jails on

initblueprint "$1"

# Initialise defaults
# You can add default values for the variables already loaded here.

# Example jail content
echo "Testvar = ${testvar}"
echo "required testvar2 = ${testvar2}"


exitblueprint "$1" "Exampleblueprint installation finished."
# you can add additional echo output (but only echo output) after the exitblueprint