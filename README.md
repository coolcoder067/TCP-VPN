# Wireguard VPN over TCP

Bypasses the restrictions of hostile wifi networks by encapsulating VPN UDP traffic as fake TCP traffic.

Under the hood, uses [wireguard](https://git.zx2c4.com/wireguard-tools) for the VPN connection and [udp2raw](https://github.com/wangyu-/udp2raw) for UDP→TCP. 

Client only available for MacOS as of now. A windows version is coming soon.

## Dependencies

- `wireguard-tools`
- `udp2raw`: Automatically installed by installation script

## Installation

### MacOS Client

```
curl -fsSL https://github.com/coolcoder067/TCP-VPN/releases/latest/download/install_client_macos.sh | sudo bash
```

Install pre-release versions:

```
curl -fsSL https://github.com/coolcoder067/TCP-VPN/releases/download/v<version>/install_client_macos.sh | sudo bash
```

Alternatively, install from source:

```
git clone https://github.com/coolcoder067/TCP-VPN
cd TCP-VPN
chmod +x install/install_client_macos.sh
sudo install/install_client_macos.sh -f client/macos
```

### Linux Debian Server

Tested on Ubuntu Server 24.04 LTS

```
curl -fsSL https://github.com/coolcoder067/TCP-VPN/releases/latest/download/install_server_linux_debian.sh | sudo bash
```

Install pre-release versions:

```
curl -fsSL https://github.com/coolcoder067/TCP-VPN/releases/download/v<version>/install_server_linux_debian.sh | sudo bash
```

Alternatively, install from source:

```
git clone https://github.com/coolcoder067/TCP-VPN
cd TCP-VPN
chmod +x install/install_server_linux_debian.sh
sudo install/install_server_linux_debian.sh -f server/linux_debian
```

## VM Setup for server in Oracle Cloud

1. [Create an account](https://signup.cloud.oracle.com). 

2. Navigate to **Networking** > **Virtual Cloud Networks** and make a new VCN. Use `10.0.0.0/16` for the IPv4 CIDR block, and turn on the option to assign an Oracle-allocated IPv6 prefix. Click **Create VCN**.

	*If on the free plan, you may have to delete the existing VCN in order to create the new one. The following steps won't work with the default VCN. If you have trouble deleting it, try deleting all the route rules in its default route table first.*

3. Under the new VCN, click on **Security** **Create security list**. Add the following rules for both **Ingress** AND **Egress**:

	- Stateless = **ON**, Source CIDR = `0.0.0.0/0`, IP Protocol = **All Protocols**
	- Stateless = **ON**, Source CIDR = `::/0`, IP Protocol = **All Protocols**

	This will allow all traffic (not usually security best practice, but I can't think of a better alternative for this kind of VPN server).

4. Go to the **Subnets** section and click **Create Subnet**. Use `10.0.0.0/24` for the IPv4 CIDR block, and be sure to assign an Oracle-allocated IPv6 prefix. Enter `00` for the two hex characters. Select your new security list from the dropdown to associate it with the subnet. Once the subnet is created, examine its **Security** section to make sure that your custom list has been applied rather than the default one.

5. Go to the **Gateways** section and click **Create Internet Gateway**. Name it and click **Create Internet Gateway**. *That should be the only gateway.*

6. Go to the **Routing** section and click **Default Route Table for (VCN name)**. Under the **Route Rules** section, add the following rules:

	- Protocol Version = **IPv4**, Target Type = **Internet Gateway**, Destination CIDR Block = `0.0.0.0/0`, Target Internet Gateway = **(Your gateway name)**
	- Protocol Version = **IPv6**, Target Type = **Internet Gateway**, Destination CIDR Block = `::/0`, Target Internet Gateway = **(Your gateway name)**

	This will give your VCN access to the Internet.

7. Navigate to **Compute** > **Instances** and click **Create instance**. Click **Change Image** and under **Ubuntu** select **Canonical Ubuntu 24.04 Minimal aarch64**. Make sure the shape is set to **VM.Standard.A1.Flex** with 1 core OCPU and 6GB memory. Click **Next** to navigate to the **Networking** section. Make sure your VCN and subnet are selected and download the private SSH key. Create the instance.

	*If the free tier won't let you create a VM because of error 'Out of capacity for shape', you will need to upgrade to paid tier. This won't charge you anything as long as you are careful to stay within the limits of their generous [free tier](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm).*

7. Navigate back to **Compute** > **Instances** and after a little while you should see the public IP address of your new VM. You will need that for SSH.

8. Click on your new instance and navigate to **Networking**. Under **Attached VNICs** click on the only VNIC in the list. Click on **IP Administration** > **Assign IPv6 address**. Don't change anything and click **Assign**.

8. Move the SSH key you downloaded somewhere safe. Edit `~/.ssh/config` to add the following entry:

	```
	Host vpn
	HostName <public_ip_address_of_your_vm>
	User ubuntu
	IdentityFile <location_to_key_file>
	```

9. SSH into your VM:

	```
	chmod 400 <location_to_key_file>
	ssh vpn
	```

## Quick Start

### Server Setup (Linux Debian)

Do this first.

1. First, install (see above).

2. Run `sudo tcpvpn configure`. Follow the on-screen prompts.

3. Run `sudo tcpvpn adduser <your_name>`. You will need the output of `tcpvpn print` for later.

4. Run `sudo tcpvpn up`

### Client Setup (MacOS)

1. First, install (see above).

2. Install [Homebrew](https://brew.sh) if needed. Run `brew install wireguard-tools`. 

2. Make a file containing the output of `tcpvpn print` from the server.

3. Run `sudo tcpvpn create -f <text_file>`. Follow the on-screen prompts.

4. Run `sudo tcpvpn up <name>` to activate the VPN. Run `sudo tcpvpn down` to deactivate it.


## Usage

### MacOS Client

```
Usage:
Manage configurations
	tcpvpn create [-f <filepath>]
	tcpvpn delete <name>
	tcpvpn export <name>
	tcpvpn list
Activate/deactivate the VPN
	tcpvpn up <name>
	tcpvpn down <name>
Manage the installation
	tcpvpn version
	tcpvpn update [-f <source_directory>] [-v <version>]
	tcpvpn uninstall
```

### Linux Debian Server

```
Usage:
Manage configuration
	tcpvpn adduser <name>
	tcpvpn revoke <name>
	tcpvpn print <name>
	tcpvpn list
	tcpvpn configure
VPN up/down
	tcpvpn up
	tcpvpn down
Manage the installation
	tcpvpn version
	tcpvpn update [-f <source_directory>] [-v <version>]
	tcpvpn uninstall
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

If it's step 6, there's a problem with forwarding the wireguard packets out to the broader internet. The following commands which are run by the install script aim to solve this issue:
```
sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o <interface> -j MASQUERADE
sudo ip6tables -t nat -A POSTROUTING -s fd42:42:42::/64 -o <interface> -j MASQUERADE
```
This will make all packets coming from 10.0.0.x to have their source IP rewritten to the endpoint's public IP when leaving the interface, so the wider internet will see them as coming from the endpoint’s IP.

The other cause of this problem is a misconfigured firewall, especially if this is hosted in the public cloud. I recommend allowing everything in and out in this case.

### Log locations

**Linux Debian Server**:

- Most logs are in `~/.config/tcpvpn`
- `systemd` log: `journalctl -u tcpvpn.service`

**MacOS Client**

- Logs are in `~/Library/Application Support/tcpvpn/endpoints/<endpoint_name>`

## Contribution

Contribution is welcome! I currently need help porting this to Windows. Next on my list is ubuntu server.

Found a bug, or need help? Open an issue.
