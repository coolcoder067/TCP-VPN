#!/bin/bash

# Most of this script is the exact same as macos client.
# How is installation different from client?
# 1. Automatically installs necessary tools (wg-quick, udp2raw)
# 2. Supports only one configuration, and `tcpvpn configure` is automatically ran

# Directory structure

# /usr/local/bin/
# 	tcpvpn
# 	udp2raw

# ~/.config/tcpvpn/
# 	compatible_versions
# 	version
# 	users/
# 		user1
# 		user2
# 	wg.conf
# 	script_env.cfg
# 	wg.log
# 	udp2raw.log



CLR_WHITE="\033[1;37m"
CLR_YELLOW="\033[1;33m"
CLR_RED="\033[1;31m"
CLR_RESET="\033[0m"

BIN_DIRECTORY="/usr/local/bin"
if [[ -n "$SUDO_USER" ]]; then
  USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
  USER_HOME="$HOME"
fi
CONF_DIRECTORY="$USER_HOME/.config/tcpvpn"


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
v_flag=''
while getopts ':f:v:' flag; do
	case "$flag" in
		f) f_flag="$OPTARG" ;;
		v) v_flag="$OPTARG" ;;
		:) echo_error "-$OPTARG requires an argument"; echo_info "Usage: ./install_server_linux_debian.sh [-f <source_directory>] [-v <version>]"; exit 1;;
		\?) echo_error "Invalid option -$OPTARG"; echo_info "Usage: ./install_server_linux_debian.sh [-f <source_directory>] [-v <version>]"; exit 1;;
	esac
done

if [[ $(whoami) != "root" ]]; then
  echo_error "This script must be run as root."
  exit 1
fi

# Make sure debian
if ! grep -iq '^ID_LIKE=.*debian' /etc/os-release; then
	echo_error "This install script is intended for debian-like systems only (ubuntu, rasp. pi, etc). Please choose the correct installer."
	exit 1
fi


rm -rf /tmp/tcpvpn
mkdir -p /tmp/tcpvpn

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
	if [[ -n "$v_flag" ]]; then
		echo_warn "Version flag -v was ignored because -f was defined."
	fi
	NEW_VERSION=$(cat configuration/version)
	echo_info "Version $NEW_VERSION loaded from source."
else
	cd /tmp/tcpvpn
	if [[ -n "$v_flag" ]]; then
		url="https://github.com/coolcoder067/TCP-VPN/releases/download/v${v_flag}/server-linux-debian.tar.gz"
	else
		url="https://github.com/coolcoder067/TCP-VPN/releases/latest/download/server-linux-debian.tar.gz"
	fi
	if ! curl -fsL "$url" -o tcpvpn.tar.gz; then
		if [[ -n "$v_flag" ]]; then
			echo_error "Fetch of version $v_flag failed."
		else
			echo_error "Fetch of latest version failed."
		fi
		exit 1
	fi
	tar xzf tcpvpn.tar.gz
	if [[ ! -f configuration/version ]]; then
		echo_error "No version found (this should never happen)"
		exit 1;
	fi
	NEW_VERSION=$(cat configuration/version)
	echo_info "Version $NEW_VERSION downloaded."
fi



# Check for existing installation
overwrite_conf=1
if [[ -d "$CONF_DIRECTORY" ]]; then
	# Check for version information
	if [[ -f "$CONF_DIRECTORY/version" ]]; then
		OLD_VERSION=$(cat "$CONF_DIRECTORY/version")
		if [[ -z "$f_flag" && "$NEW_VERSION" == "$OLD_VERSION" ]]; then # Installing from github and versions are the same
			echo_info "Version $OLD_VERSION of the tool is already installed and up to date."
			echo_info "Done!"
			exit 0
		fi
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


# Replace /usr/local/bin/tcpvpn
mkdir -p "$BIN_DIRECTORY" >/dev/null 2>&1 || true
cp -R bin/* "$BIN_DIRECTORY"

# ~/.config/tcpvpn
if [[ "$overwrite_conf" -eq 1 ]]; then
	# Replace ~/.config/tcpvpn
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

if [[ ! -f "$CONF_DIRECTORY"/state ]]; then
	echo 0 > "$CONF_DIRECTORY"/state
fi

# Systemd service
cp tcpvpn.service /etc/systemd/system/
systemctl daemon-reload > /dev/null
systemctl enable tcpvpn > /dev/null


# CD'ing to root home because we're about to remove the directory we're currently in
cd
rm -rf /tmp/tcpvpn


# Install udp2raw
if which udp2raw >/dev/null 2>&1; then
	echo_info "udp2raw already installed."
else
	rm -rf /tmp/udp2raw
	mkdir -p /tmp/udp2raw
	cd /tmp/udp2raw
	curl -fsSL https://github.com/wangyu-/udp2raw/releases/download/20230206.0/udp2raw_binaries.tar.gz -o udp2raw.tar.gz
	tar xzf udp2raw.tar.gz

	# Detect architecture and copy appropriate binary
	case $(uname -m) in
		aarch64) cp udp2raw_arm "$BIN_DIRECTORY/udp2raw" ;;
		arm64) cp udp2raw_arm "$BIN_DIRECTORY/udp2raw" ;;
		x86_64) cp udp2raw_amd64 "$BIN_DIRECTORY/udp2raw" ;;
		i386) cp udp2raw_x86 "$BIN_DIRECTORY/udp2raw" ;;
		i486) cp udp2raw_x86 "$BIN_DIRECTORY/udp2raw" ;;
		i586) cp udp2raw_x86 "$BIN_DIRECTORY/udp2raw" ;;
		i686) cp udp2raw_x86 "$BIN_DIRECTORY/udp2raw" ;;
		*) echo_error "Arch could not be detected"; exit 1
	esac
	rm -rf /tmp/udp2raw
	echo_info "Installed udp2raw."
fi


# Install wireguard-tools
if which wg-quick >/dev/null 2>&1; then
	echo_info "wg-quick already installed."
else
	if ! apt-get update > /dev/null 2>&1; then
		echo_error "Could not update apt."
		exit 1
	fi
	if ! apt-get install -y wireguard-tools > /dev/null 2>&1; then
		echo_error "Could not install wireguard-tools."
		exit 1
	fi
	if ! which wg-quick >/dev/null 2>&1; then
		echo_error "Installation of wireguard-tools was not successful."
		exit 1
	fi
	echo_info "Installed wireguard-tools."
fi

chmod -R 755 "$BIN_DIRECTORY"/tcpvpn
chmod -R 755 "$BIN_DIRECTORY"/udp2raw >/dev/null 2>&1 || true

# Allow packet forwarding
sysctl -w net.ipv4.ip_forward=1 >/dev/null
sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null
echo_info "Allowed packet forwarding via sysctl."

if which iptables >/dev/null 2>&1; then
	sudo iptables -F INPUT
	sudo iptables -F FORWARD
	sudo iptables -F OUTPUT
	sudo iptables -P INPUT ACCEPT
	sudo iptables -P FORWARD ACCEPT
	sudo iptables -P OUTPUT ACCEPT
	DEFAULT_INTERFACE=$(ip route | grep '^default' | grep -oP 'dev \K\S+')
	sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o "$DEFAULT_INTERFACE" -j MASQUERADE
	sudo ip6tables -t nat -A POSTROUTING -s fd42:42:42::/64 -o "$DEFAULT_INTERFACE" -j MASQUERADE
	echo_info "Flushed iptables and added masquerade rules."
else
	echo_warn "iptables not found. The VPN probably won't work unless you modify your firewall/routing tables to accept and forward packets in the correct way."
fi


echo_info "Installation was successful!"
if [[ ! -f "$CONF_DIRECTORY"/script_env.cfg ]]; then
	echo_info "To finish configurtaion of the server, run \`tcpvpn configure\`."
fi
tcpvpn _resolve_state_or_restart
exit 0

