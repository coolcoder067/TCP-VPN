#!/bin/bash

# Directory structure

# /usr/local/bin/
# 	tcpvpn
# 	udp2raw

# /usr/local/lib/
# 	tcpvpn/
# 		PostUp.sh

# ~/Library/Application\ Support/tcpvpn/
# 	compatible_versions
# 	version
# 	endpoints/
# 		endpoint1/
# 			wg.conf
# 			script_env.cfg
# 			wg.log
# 			udp2raw.log
# 			ipv4_gw
# 			ipv6_gw


# 1. Check for version incompatibility
# 2. Get from github
# 3. Install udp2raw
# 4. Copy to /usr/local/bin
# 5. Copy to /usr/local/lib


VERSION="dev-20260107-4"
URL="https://github.com/coolcoder067/TCP-VPN/releases/download/v${VERSION}/client-macos.tar.gz"


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
	echo -e "${CLR_RED}[Error] $*${CLR_RESET}" >&2
}

set -e # Fail on error, just in case


# Read arguments
f_flag='' # Argument to read from file
while getopts ':f:' flag; do
	case "$flag" in
		f) f_flag="$OPTARG" ;;
		:) echo_error "-$OPTARG requires an argument"; echo_info "Usage: ./install_client_macos.sh [-f <source_directory>]"; exit 1;;
		\?) echo_error "Invalid option -$OPTARG"; echo_info "Usage: ./install_client_macos.sh [-f <source_directory>]"; exit 1;;
	esac
done

if [[ $(whoami) != "root" ]]; then
  echo_error "This script must be run as root."
  exit 1
fi

# Make sure macOS
if [[ "$(uname)" != "Darwin" ]]; then
	echo_error "This install script is intended for MacOS only. Please choose the correct installer."
	exit 1
fi

rm -rf /tmp/tcpvpn
mkdir -p /tmp/tcpvpn

# Copy files to /tmp/tcpvpn
if [[ -n "$f_flag" ]]; then
	if [[ ! -d "$f_flag" ]]; then
		echo_error "Directory \"$f_flag\" does not exist."
		exit 1
	fi
	if [[ ! -d "$f_flag/../../configuration" ]]; then
		echo_error "Could not find configuration directory (should be in root of git repo)"
		exit 1
	fi
	cp -R "$f_flag"/* /tmp/tcpvpn
	cp -R "$f_flag"/../../configuration /tmp/tcpvpn
	cd /tmp/tcpvpn
	if [[ ! -f configuration/version ]]; then
		echo_error "No version found (this should never happen)"
		exit 1;
	fi
	if [[ $(cat configuration/version) != "$VERSION" ]]; then
		echo_error "Versions do not match"
		exit 1
	fi
	echo_info "Version $VERSION loaded from source."
else
	cd /tmp/tcpvpn
	if ! curl -fsL "$URL" -o tcpvpn.tar.gz; then
		echo_error "Fetch of version $VERSION failed."
		exit 1
	fi
	tar xzf tcpvpn.tar.gz
	if [[ ! -f configuration/version ]]; then
		echo_error "No version found (this should never happen)"
		exit 1;
	fi
	if [[ $(cat configuration/version) != "$VERSION" ]]; then
		echo_error "Versions do not match"
		exit 1
	fi
	echo_info "Version $VERSION downloaded."
fi


# Check for existing installation
overwrite_conf=1
if [[ -d "$CONF_DIRECTORY" ]]; then
	# Check for version information
	if [[ -f "$CONF_DIRECTORY/version" ]]; then
		OLD_VERSION=$(cat "$CONF_DIRECTORY/version")
		# if [[ -z "$f_flag" && "$VERSION" == "$OLD_VERSION" ]]; then # Installing from github and versions are the same
		# 	echo_info "Version $OLD_VERSION of the tool is already installed and up to date."
		# 	echo_info "Done!"
		# 	exit 0
		# fi
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
mkdir -p "$BIN_DIRECTORY" >/dev/null 2>&1 || true
cp -R bin/* "$BIN_DIRECTORY"
rm -rf "$LIB_DIRECTORY"
mkdir -p "$LIB_DIRECTORY"
cp -R lib/* "$LIB_DIRECTORY"

# Replace ~/Library/Application\ Support/tcpvpn
if [[ "$overwrite_conf" -eq 1 ]]; then
	if [[ -d $CONF_DIRECTORY ]]; then
		echo_info "Overwriting configuration directory."
		rm -rf "$CONF_DIRECTORY"
	fi
	mkdir -p "$CONF_DIRECTORY"
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
	mkdir -p /tmp/udp2raw
	cd /tmp/udp2raw
	curl -fsSL https://github.com/wangyu-/udp2raw-multiplatform/releases/download/20230206.0/udp2raw_mp_binaries.tar.gz -o udp2raw.tar.gz
	tar xzf udp2raw.tar.gz
	# Detect architecture and copy appropriate binary
	case $(uname -m) in
		arm64) cp udp2raw_mp_mac_m1 "$BIN_DIRECTORY/udp2raw" ;;
		x86_64) cp udp2raw_mp_mac "$BIN_DIRECTORY/udp2raw" ;;
		*) echo_error "Arch could not be detected (this should never happen)"; exit 1
	esac
	cd
	rm -rf /tmp/udp2raw
	echo_info "Installed udp2raw."
fi

# Prompt user to install wireguard-tools
if which wg-quick >/dev/null 2>&1; then
	echo_info "wg-quick already installed."
else
	echo_warn "Dependency \`wg-quick\` not found. Install with \`brew install wireguard-tools\`."
fi

cd

chmod -R 755 "$LIB_DIRECTORY"/*
chmod -R 755 "$BIN_DIRECTORY"/*


echo_info "Installation was successful."
if [[ $(cat "$CONF_DIRECTORY"/was_up_before_update 2>/dev/null) == 1 && -f "$CONF_DIRECTORY"/active ]]; then
	tcpvpn up $(cat "$CONF_DIRECTORY"/active)
fi
exit 0

