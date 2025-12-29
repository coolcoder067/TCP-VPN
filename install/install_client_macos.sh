#!/bin/bash

# Installs udp2raw at /usr/local/bin, this tool at /usr/local/bin/tcpvpn, 
# and supporting programs at /usr/local/lib/tcpvpn
# Configurations will be saved at ~/Library/Application\ Support/tcpvpn/endpoints

# ~/Library/Application\ Support/tcpvpn/endpoints/levi example endpoint location

# 1. Check for version incompatibility
# 2. Get from github
# 3. Install udp2raw
# 4. Copy to /usr/local/bin
# 5. Copy to /usr/local/lib



CLR_WHITE="\033[1;37m"
CLR_YELLOW="\033[1;33m"
CLR_RED="\033[1;31m"
CLR_RESET="\033[0m"

BIN_DIRECTORY="/usr/local/bin"
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

f_flag='' # Argument to read from file
v_flag=''
while getopts 'f:v:' flag; do
	case "${flag}" in
		f) f_flag="${OPTARG}" ;;
		v) v_flag="${OPTARG}" ;;
	esac
done

if [[ $(whoami) != "root" ]]; then
  echo_error "This script must be run as root."
  exit 1
fi

rm -rf /tmp/tcpvpn
mkdir /tmp/tcpvpn

if [[ -n "$f_flag" ]]; then
	cp -R "$f_flag"/* /tmp/tcpvpn
	cp -R "$f_flag"/../../configuration /tmp/tcpvpn
	cd /tmp/tcpvpn
	NEW_VERSION=$(cat /tmp/tcpvpn/configuration/version)
	echo_info "Version $NEW_VERSION loaded from source."
else
	cd /tmp/tcpvpn
	if [[ -n "v_flag" ]]; then
		url="https://github.com/coolcoder067/TCP-VPN/releases/download/v${v_flag}/client-macos.tar.gz"
	else
		url="https://github.com/coolcoder067/TCP-VPN/releases/latest/download/client-macos.tar.gz"
	fi
	if ! curl -fsL "$url" -o tcpvpn.tar.gz; then
		echo_error "Fetch of version $v_flag failed."
		exit 1
	fi
	tar xzf tcpvpn.tar.gz
	NEW_VERSION=$(cat /tmp/tcpvpn/configuration/version)
	echo_info "Version $NEW_VERSION downloaded."
fi


# Check for existing installation
overwrite_conf=1
if [[ -d "$CONF_DIRECTORY" ]]; then
	# Check for version information
	if [[ -f "$CONF_DIRECTORY/version" ]]; then
		OLD_VERSION=$(cat "$CONF_DIRECTORY/version")
		if grep -Fxq "$OLD_VERSION" "/tmp/tcpvpn/configuration/compatible_versions"; then
			echo_info "Version $OLD_VERSION of the tool is already installed, and the configuration files are backwards-compatible with this version. Proceeding will not overwrite the current configuration."
			overwrite_conf=0
		else
			echo_warn "Version $OLD_VERSION of the tool is already installed, and the configuration files are not backwards-compatible. Proceeding will overwrite this installation."
		fi
	else
		echo_warn "A possible installation of the tool was found, but no version information was detected. Proceeding will overwrite this installation."
	fi
	read -p "Do you want to proceed? Press Enter to continue, or Ctrl+C to quit." </dev/tty
else 
	echo_info "No existing installation of the tool was found."
fi

# Replace /usr/local/bin/tcpvpn, /usr/local/lib/tcpvpn
mkdir "$BIN_DIRECTORY" >/dev/null 2>&1 || true
cp -R bin/* "$BIN_DIRECTORY"
rm -rf "$LIB_DIRECTORY"
mkdir "$LIB_DIRECTORY"
cp -R lib/* "$LIB_DIRECTORY"

# Replace ~/Library/Application\ Support/tcpvpn
if [[ "$overwrite_conf" -eq 1 ]]; then
	if [[ -d $CONF_DIRECTORY ]]; then
		echo_info "Overwriting configuration directory."
		rm -rf "$CONF_DIRECTORY"
	fi
	mkdir "$CONF_DIRECTORY"
	cp -R configuration/* "$CONF_DIRECTORY"
else
	echo_info "Skip overwrite of configuration directory."
	cp configuration/version "$CONF_DIRECTORY/version"
	cp configuration/compatible_versions "$CONF_DIRECTORY/compatible_versions"
fi

rm -rf /tmp/tcpvpn

# Install udp2raw
if which udp2raw >/dev/null 2>&1; then
    echo_info "udp2raw already installed."
else
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
    echo_info "Installed udp2raw."
fi

# Prompt user to install wireguard-tools
if which wg-quick >/dev/null 2>&1; then
	echo_info "wg-quick already installed."
else
	echo_warn "Dependency \`wg-quick\` not found. Install with \`brew install wireguard-tools\`."
fi

chmod -R 755 "$LIB_DIRECTORY"/*
chmod -R 755 "$BIN_DIRECTORY"/*

echo_info "Successfully installed the tool."
exit 0

