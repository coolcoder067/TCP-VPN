#!/bin/bash
if [[ -z "$1" ]]; then
	echo "Usage: tcpvpn down <name>"
	exit 1
fi
if [[ $(whoami) != "root" ]]; then
	echo "Error: This script must be run as root."
	exit 1
fi
FILEPATH="endpoints/$1/wg.conf"
if [[ ! -f $FILEPATH ]]; then
	echo -e "Error: No file was found at $(pwd)/$FILEPATH."
	exit 1
fi
echo "Deactivating configuration '$1'..."
wg-quick down "$FILEPATH"