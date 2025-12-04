#!/bin/bash
if [[ -z "$1" ]]; then
	echo "Usage: tcpvpn up <name>"
	exit 1
fi
if [[ $(whoami) != "root" ]]; then
	echo "Error: This script must be run as root."
	exit 1
fi
FILEPATH="endpoints/$1/wg.conf"
if [[ ! -f $FILEPATH ]]; then
	echo -e "Error: No file was found at $(pwd)/$FILEPATH. Use \`tcpvpn create\` to create a configuration."
	exit 1
fi
echo "Activating configuration '$1'..."
wg-quick up "$FILEPATH"