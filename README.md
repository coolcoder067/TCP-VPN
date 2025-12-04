# VPN over TCP on Mac
Bypasses the restrictions of hostile wifi networks by encapsulating VPN UDP traffic as fake TCP traffic. 

Tested on Mac, may or may not work on Linux. A windows version is coming soon.
### Install Prerequisites
Install required tools (requires homebrew):
```
brew install coreutils wireguard-tools
```
Install udp2raw (not available via homebrew):
```
curl -L https://github.com/wangyu-/udp2raw-multiplatform/releases/download/20230206.0/udp2raw_mp_binaries.tar.gz -o ~/Downloads/udp2raw.tar.gz
mkdir ~/Downloads/udp2raw
tar -xzf ~/Downloads/udp2raw.tar.gz -C ~/Downloads/udp2raw
sudo cp ~/Downloads/udp2raw/udp2raw_mp_mac_m1 /usr/local/bin/udp2raw
chmod +x /usr/local/bin/udp2raw
rm -r ~/Downloads/udp2raw
rm ~/Downloads/udp2raw.tar.gz
```
### Installation
Make a directory for the installation (e.g. `~/vpn`).
```
mkdir ~/vpn
cd ~/vpn
```
Clone the repository and set up the utility:
```
git clone https://github.com/coolcoder067/TCP-VPN_Mac
cd wrapper-utility
# Make it executable
chmod +x tcpvpn
# Add it to your path
echo "export PATH=\"$(pwd):\$PATH\"" >> ~/.zshrc
# Generate wireguard keys
wg genkey | tee privatekey | wg pubkey > publickey
# See the public key for use in server setup
cat publickey
# See the private key for use in local setup
cat privatekey
```
### Server side installation (tested on Ubuntu)
**A note on firewall rules:** It's usually best practice for security to have a firewall that only allows what you need it to through. But for a VPN server, you sort of need to allow everything so that applications can use any port for connections. 

Installation steps
```
sudo apt update
sudo apt upgrade -y
sudo apt install wireguard -y
mkdir ~/vpn
cd ~/vpn
wg genkey | tee privatekey | wg pubkey > publickey
# See the private key so you can paste it into wg0.conf
cat privatekey
# See the public key for use in client setup
cat publickey
sudo nano /etc/wireguard/wg0.conf
# Add configuration here (see below)

# Flush iptables to allow everything
sudo iptables -F INPUT
sudo iptables -F FORWARD
sudo iptables -F OUTPUT
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
# Make outbound packets masquerade as the public ip address of the endpoint (see explanation in 'troubleshooting' below)
DEFAULT_INTERFACE=$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')
sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o "$DEFAULT_INTERFACE" -j MASQUERADE
sudo ip6tables -t nat -A POSTROUTING -s fd42:42:42::/64 -o "$DEFAULT_INTERFACE" -j MASQUERADE
# Allow packet forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1

# Start the interface
sudo wg-quick up wg0
```
TODO: Find a way to make it start automatically on reboot.

**A note on the udp2raw password:** It doesn't matter, so you can pick something easy. For maximum performance, if you know what you're doing, you can even turn encryption off. This is because the security is handled by wireguard.

wg0.conf
```
[Interface]
PrivateKey = <server_private_key>
Address = 10.0.0.1/24, fd42:42:42::1/64
ListenPort = 50001
MTU = 1342
PreUp = udp2raw -s -l $(ip route get 1.1.1.1 | grep -oP 'src \K[0-9.]+'):443 -r 127.0.0.1:50001 -k <udp2raw_password> -a --dev enp0s6 > <vpn_directory>/udp2raw.log 2>&1 &
PostDown = killall udp2raw || true

[Peer]
PublicKey = <client_public_key>
AllowedIPs = 10.0.0.2/32, fd42:42:42::2/128
```
### Usage
```
tcpvpn create              # Create a new VPN configuration
sudo tcpvpn up <name>      # Start the VPN
sudo tcpvpn down <name>    # Stop the VPN
```
### Troubleshooting
To attempt to troubleshoot, it helps to first visualize the flow of packets as they travel through the network.
```
1. Local Source
   |       ˄
   |       |
   ˅       |
2. Wireguard (local)
   |       ˄
   |       |  Through the loopback interface...
   ˅       |
3. udp2raw (local)
   |       ˄
   |       |  Over the public internet...
   ˅       |
4. udp2raw (endpoint)
   |       ˄
   |       |  Through the loopback interface...
   ˅       |
5. Wireguard (endpoint)
   |       ˄
   |       |
   ˅       |
6. Kernel routing tables (endpoint)
   |       ˄
   |       |  Over the public internet...
   ˅       |
7. End Destination
```
Try `ping <wireguard_endpoint_ip>`. `<wireguard_endpoint_ip` is 10.0.0.1 in the example. If this does work, it's likely a problem with step 6. If it doesn't, there's likely a problem with steps 2, 3, 4, or 5.

To troubleshoot steps 2, 3, 4, and 5: 
- Use wireshark (not to be confused with wireshark) to inspect interfaces locally and see where things are going wrong.
- Use `tshark` to inspect interfaces on the server side. Example: `sudo tshark -i lo -o "gui.column.format:Packet Number,%m,Source,%s,Destination,%d,Src Port,%S,Dst Port,%D,Info,%i"` will display information about packets on the loopback interface. 
- If you see wireguard packets on the loopback interface, you can rule out 2 because wireguard is working locally.
- If you see ICMP packets responding to the wireguard packets with "destination port unreachable", it's likely 3 (udp2raw isn't working locally). 
- If there's no ICMP response, that means the packets are getting through to udp2raw. Check the udp2raw logs on both ends and see if a handshake has occured. If it has, you can rule out 3 and 4. Otherwise, there's a problem with udp2raw on either client or server. Sometimes the logs will tell you what's wrong. Try getting udp2raw to work without the VPN.
- If there's a udp2raw handshake and UDP packets are being forwarded to the wireguard port on the server side, it's likely a problem with wireguard.
- It's worth double-checking if keys match, if ports match, and if the udp2raw password matches.

If it's step 6, there's a problem with forwarding the wireguard packets out to the broader internet. The following commands aim to solve this issue:
```
sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o <interface> -j MASQUERADE
sudo ip6tables -t nat -A POSTROUTING -s fd42:42:42::/64 -o <interface> -j MASQUERADE
```
This will make all packets coming from 10.0.0.x to have their source IP rewritten to the endpoint's public IP when leaving the interface, so the wider internet will see them as coming from the endpoint’s IP.