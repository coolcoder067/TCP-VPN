#!/bin/bash

# Installs udp2raw at /usr/local/bin, this tool at /usr/local/bin/tcpvpn, 
# and supporting programs at /usr/local/lib/tcpvpn
# Configurations will be saved at ~/Library/Application\ Support/tcpvpn

# ~/Library/Application\ Support/tcpvpn/endpoints/levi example endpoint location

# Previous method: Everything is in one directory, a sub-directory is added to the path
# This is not the way to go

# 1. Check for version incompatibility
# 2. Get from github
# 3. Install udp2raw
# 4. Copy to /usr/local/bin
# 5. Copy to /usr/local/lib


MACOS_RELEASE_URL="https://github.com/coolcoder067/TCP-VPN_Mac/releases/latest/download/client-macos.tar.gz"

CLR_WHITE="\033[1;37m"
CLR_YELLOW="\033[1;33m"
CLR_RED="\033[1;31m"
CLR_RESET="\033[0m"

BIN_DIRECTORY="/usr/local/bin/tcpvpn"
LIB_DIRECTORY="/usr/local/lib/tcpvpn"
CONF_DIRECTORY="$HOME/Library/Application Support/tcpvpn"

echo_info() {
  echo -e "${CLR_WHITE}[Info] $*${CLR_RESET}"
}

echo_warn() {
  echo -e "${CLR_YELLOW}[Warn] $*${CLR_RESET}"
}

echo_error() {
  echo -e "${CLR_RED}[Error] $*${CLR_RESET}"
}

set -e # Fail on error, just in case

if [[ $(whoami) != "root" ]]; then
  echo_error "This script must be run as root."
  exit 1
fi

rm -rf /tmp/tcpvpn
mkdir /tmp/tcpvpn
cd /tmp/tcpvpn
curl -fsSL "$MACOS_RELEASE_URL" -o tcpvpn.tar.gz
tar xzf tcpvpn.tar.gz
NEW_VERSION=$(cat /tmp/tcpvpn/configuration/version)
echo_info "Version $NEW_VERSION downloaded."

# Check for existing installation
overwrite_conf=1
if [[ -d "$CONF_DIRECTORY" ]]; then
	# Check for version information
	if [[ -f "$CONF_DIRECTORY/version" ]]; then
		OLD_VERSION=$(cat "$CONF_DIRECTORY/version")
		if grep -Fxq "$NEW_VERSION" "$CONF_DIRECTORY/compatible_versions"; then
			echo_info "Version $OLD_VERSION of the tool is already installed, and the configuration files are backwards-compatible with this version."
			overwrite_conf=0
		else
			echo_warn "Version $OLD_VERSION of the tool is already installed, and the configuration files are not backwards-compatible. Proceeding will overwrite this installation."
		fi
	else
		echo_warn "A possible installation of the tool was found, but no version information was detected. Proceeding will overwrite this installation."
	fi
	read -p "Do you want to proceed? Press Enter to continue, or Ctrl+C to quit."
else 
	echo_info "No existing installation of the tool was found."
fi

# Replace /usr/local/bin/tcpvpn, /usr/local/lib/tcpvpn
mkdir "$BIN_DIRECTORY" || true
cp bin/* "$BIN_DIRECTORY"
rm -rf "$LIB_DIRECTORY"
mkdir "$LIB_DIRECTORY"
cp lib/* "$LIB_DIRECTORY"

# Replace ~/Library/Application\ Support/tcpvpn
if [[ "$overwrite_conf" -eq 1 ]]; then
	if [[ -d $CONF_DIRECTORY ]]; then
		echo_info "Overwriting configuration directory."
		rm -rf "$CONF_DIRECTORY"
	fi
	mkdir "$CONF_DIRECTORY"
	cp configuration/* "$CONF_DIRECTORY"
else
	echo_info "Skip overwrite of configuration directory."
	cp configuration/version "$CONF_DIRECTORY/configuration/version"
	cp configuration/compatible_versions "$CONF_DIRECTORY/configuration/compatible_versions"
fi

rm -rf /tmp/tcpvpn

# Install udp2raw
if which udp2raw >/dev/null 2>&1; then
    echo_info "udp2raw already installed."
else
    echo_info "Installing udp2raw..."
	rm -rf /tmp/udp2raw
	mkdir /tmp/udp2raw
	cd /tmp/udp2raw
    curl -fsSL https://github.com/wangyu-/udp2raw-multiplatform/releases/download/20230206.0/udp2raw_mp_binaries.tar.gz -o udp2raw.tar.gz
    tar xzf udp2raw.tar.gz
    ARCH=$(uname -m)
    if [[ "$ARCH" = "arm64" ]]; then # Apple M1, etc
    	cp udp2raw_mp_mac_m1 "$BIN_DIRECTORY/udp2raw"
    else
    	if [[ "$ARCH" = "x86_64" ]]; then
    		cp udp2raw_mp_mac "$BIN_DIRECTORY/udp2raw"
    	else
    		echo_error "Something went wrong."
    		exit 1
    	fi
    fi
    rm -rf /tmp/udp2raw
fi

# Prompt user to install wireguard-tools
if which wg-quick >/dev/null 2>&1; then
	echo_info "wg-quick already installed."
else
	echo_warn "Dependency not found: wg-quick\nInstall wg-quick with \`brew install wireguard-tools\`."
fi

chmod -R 755 "$LIB_DIRECTORY/*"
chmod -R 755 "$BIN_DIRECTORY/*"

echo_info "Successfully installed the tool."
exit 0

