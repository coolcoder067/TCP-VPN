# VPN over TCP on Mac
Bypasses the restrictions of hostile wifi networks by masking the UDP traffic of a VPN as fake TCP traffic. Only tested on Mac, may or may not work on Linux. Windows version coming out soon.
### Install Prerequisites
```
brew install coreutils wireguard-tools
curl -L https://github.com/wangyu-/udp2raw-multiplatform/releases/download/20230206.0/udp2raw_mp_binaries.tar.gz -o ~/Downloads/udp2raw.tar.gz
mkdir ~/Downloads/udp2raw
tar -xzf ~/Downloads/udp2raw.tar.gz -C ~/Downloads/udp2raw
sudo cp ~/Downloads/udp2raw/udp2raw_mp_mac_m1 /usr/local/bin/udp2raw
chmod +x /usr/local/bin/udp2raw
rm -r ~/Downloads/udp2raw
rm ~/Downloads/udp2raw.tar.gz
```
### Installation
```
1. Git clone it
2. Add wrapper-utility directory to your path
```
### Troubleshooting
To attempt to troubleshoot, it helps to first visualize the flow of packets as they travel through the network.
```
1. Local Source
   |       ˄
   ˅       |
2. Wireguard (local)
   |       ˄
   ˅       |
3. udp2raw (local)
   |       ˄
   |       |  Over the public internet...
   |       |
   ˅       |
4. udp2raw (endpoint)
   |       ˄
   ˅       |
5. Wireguard (endpoint)
   |       ˄
   ˅       |
6. Kernel routing tables (endpoint)
   |       ˄
   |       |  Over the public internet...
   |       |
   ˅       |
7. End Destination
```
Try `ping <wireguard_endpoint_ip>`. This is usually 10.0.0.1. If this doesn't work, it's a problem with step 6. If it does, there's a problem with 2, 3, 4, 5.
To troubleshoot steps 2, 3, 4, 5, use wireshark (not to be confused with wireguard) and look at where the packets are failing. If you see ICMP packets on the loopback interface with "destination port unreachable", you can rule out 2, and it's likely 3 (udp2raw isn't working locally). If udp2raw is sending out TCP packets over en0, it's either 4 or 5, so use `tshark` on the server side to do a little digging.
If it's step 6, try something similar to:
```
sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o enp0s6 -j MASQUERADE
sudo ip6tables -t nat -A POSTROUTING -s fd42:42:42::/64 -o enp0s6 -j MASQUERADE
```
Don't just copy and paste without understanding it, and make sure to change `enp0s6`.
This will make all packets coming from 10.0.0.x to have their source IP rewritten to the endpoint's public IP when leaving the interface, so the wider internet will see them as coming from the endpoint’s IP.