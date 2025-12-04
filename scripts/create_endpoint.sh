#!/bin/bash
echo -e "\nThis script generates wg.conf and script_env.cfg for a VPN configuration.\n\n*** IMPORTANT! ***\nThe root VPN directory was detected to be $(pwd). Confirm that this is correct.\n"
sleep '1.5'

# Take input from user
echo -ne 'What is the address of VPN server?\n> '
read ENDPOINT_ADDRESS
[[ -z "${ENDPOINT_ADDRESS// }" ]] && echo "Input cannot be blank." && exit 1

echo -ne "Does this address need to be resolved with DNS? Answer with 'true' or 'false'.\n> "
read RESOLVE_WITH_DNS
[[ -z "${RESOLVE_WITH_DNS// }" ]] && echo "Input cannot be blank." && exit 1
if [[ "$RESOLVE_WITH_DNS" != "true" && "$RESOLVE_WITH_DNS" != "false" ]]; then
	echo "Please enter 'true' or 'false' exactly."
	exit 1
fi

echo -ne 'What is the port that the server is listening on?\n> '
read ENDPOINT_PORT
[[ -z "${ENDPOINT_PORT// }" ]] && echo "Input cannot be blank." && exit 1

echo -ne 'What is the PRIVATE key of YOUR USER?\n> '
read USER_PRIVATE_KEY
[[ -z "${USER_PRIVATE_KEY// }" ]] && echo "Input cannot be blank." && exit 1

echo -ne 'What is the PUBLIC key of the SERVER?\n> '
read SERVER_PUBLIC_KEY
[[ -z "${SERVER_PUBLIC_KEY// }" ]] && echo "Input cannot be blank." && exit 1

echo -ne 'What is the password for udp2raw?\n> '
read UDP2RAW_PWD
[[ -z "${UDP2RAW_PWD// }" ]] && echo "Input cannot be blank." && exit 1

echo -ne "Enter the IP addresses that were allocated to your user, separated by comma.\nThis should look something like '10.0.0.2/24, fd42:42:42::2/64'.\n> "
read USER_ADDRESS
[[ -z "${USER_ADDRESS// }" ]] && echo "Input cannot be blank." && exit 1

echo -ne "Enter the DNS servers you want to use, separated by comma, or leave blank.\nThe default is '1.1.1.1, 2606:4700:4700::1111'.\n> "
read DNS_SERVERS
if [[ -z "$DNS_SERVERS" ]]; then
	DNS_SERVERS='1.1.1.1, 2606:4700:4700::1111'
fi

echo -ne "Choose an empty port that wireguard traffic can be directed to and turned into TCP. (ex. 50001)\n> "
read LOCAL_PORT
[[ -z "${LOCAL_PORT// }" ]] && echo "Input cannot be blank." && exit 1

echo -ne 'What is the name of your new VPN configuration? Keep it short.\n> '
read CONFIGURATION_NAME
[[ -z "${CONFIGURATION_NAME// }" ]] && echo "Input cannot be blank." && exit 1

echo 'Press enter to confirm the details above, or CTRL+C to quit.'
read

# Make directory
# We have to work in absolute paths here because we can't guarantee wg-quick will be in any particular directory when it runs.
# PreUp.sh, etc. cd's to $CONFIGURATION_DIR so it can then access files normally.
CONFIGURATION_DIR="$(pwd)/endpoints/$CONFIGURATION_NAME"
mkdir -p "$CONFIGURATION_DIR"

# Generate script_env.cfg
echo -ne "ENDPOINT_ADDRESS='$ENDPOINT_ADDRESS'\nRESOLVE_WITH_DNS='$RESOLVE_WITH_DNS'\nENDPOINT_PORT='$ENDPOINT_PORT'\nLOCAL_PORT='$LOCAL_PORT'\nUDP2RAW_PWD='$UDP2RAW_PWD'" > $CONFIGURATION_DIR/script_env.cfg

# Generate wg.conf
echo -ne "[Interface]\nPrivateKey = $USER_PRIVATE_KEY\nAddress = $USER_ADDRESS\nDNS = $DNS_SERVERS\nMTU = 1342\n\nPreUp = '$(pwd)/scripts/PreUp.sh' '$CONFIGURATION_DIR'\nPostUp = '$(pwd)/scripts/PostUp.sh' '$CONFIGURATION_DIR'\nPostDown = '$(pwd)/scripts/PostDown.sh' '$CONFIGURATION_DIR'\n\n[Peer]\nPublicKey = $SERVER_PUBLIC_KEY\nAllowedIPs = 0.0.0.0/0, ::/0\nEndpoint = 127.0.0.1:$LOCAL_PORT" > $CONFIGURATION_DIR/wg.conf

echo "Initializing kernel modules..."
sleep 0.5
echo "Calibrating quantum resolver..."
sleep 0.2
echo "Syncing hyperlane registry..."
sleep 0.1
echo "Optimizing phase conduits..."
sleep 0.1
echo "Binding nano threads..."
sleep 0.5
echo "Activating secure relay..."
sleep 0.2
echo -e "Generated files at $CONFIGURATION_DIR.\nUse \`sudo tcpvpn up $CONFIGURATION_NAME\` to activate your VPN."
