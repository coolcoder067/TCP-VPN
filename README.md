# Wireguard VPN over TCP

Bypasses the restrictions of hostile wifi networks by encapsulating VPN UDP traffic as fake TCP traffic.

Under the hood, uses [wireguard](https://git.zx2c4.com/wireguard-tools) for the VPN connection and [udp2raw](https://github.com/wangyu-/udp2raw) for UDP→TCP. 

Tested on Mac, may or may not work on Linux. A windows version is coming soon.

## Dependencies

- `wireguard-tools`: `brew install wireguard-tools`
- `udp2raw`: Automatically installed by installation script

## Client Installation

```
curl -fsSL https://raw.githubusercontent.com/coolcoder067/TCP-VPN/refs/heads/main/install/install_client_macos.sh | sudo bash
```

Install pre-release versions:

```
curl -fsSL https://raw.githubusercontent.com/coolcoder067/TCP-VPN/refs/heads/dev/install/install_client_macos.sh | sudo bash -s -- -v <prerelease_version>
```

Alternatively, install from source:

```
git clone https://github.com/coolcoder067/TCP-VPN
cd TCP-VPN
chmod +x install/install_client_macos.sh
sudo install/install_client_macos.sh -f client/macos
```

## Server Installation

Coming Soon! See [v1.1.0](https://github.com/coolcoder067/TCP-VPN/tree/v1.1.0) for manual installation on the server side.

## Quick Start

On Server:

```
Coming Soon!
```

On Client:

```
sudo tcpvpn create
# Follow the on-screen prompts
sudo tcpvpn up <name>
```

## Usage (Client)

```
Usage: tcpvpn create [-f <filepath>]  Create a new VPN configuration
       tcpvpn up <name>               Activate the VPN
       tcpvpn down                    Deactivate the VPN
       tcpvpn uninstall               Permanently uninstall tcpvpn
       tcpvpn export <name>           Use `tcpvpn export <name> > output.cfg` to save configurtation to a file for use with `tcpvpn create`
       tcpvpn delete <name>           Delete a configuration
       tcpvpn list                    List all configurations
```

## Troubleshooting
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

The other cause of this problem is a misconfigured firewall, especially if this is hosted in the public cloud. I recommend allowing everything in and out in this case.

## Contribution

Contribution is welcome! I currently need help porting this to Windows. Next on my list is ubuntu server.

Found a bug, or need help? Open an issue.
