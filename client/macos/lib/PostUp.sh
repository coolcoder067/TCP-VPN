#!/bin/bash
cd "$1"
source script_env.cfg
resolved_addr=$(cat resolved_addr)
wg_iface=$(wg show | awk '/interface:/{print $2}')
if [[ -z wg_iface ]]; then
	cat "Error: \`wg_iface\` empty (this should never happen)"
	exit 1
fi
default_iface=$(route -n get default | awk '/interface:/{print $2}')
if [[ -z default_iface ]]; then
	cat "Error: \`default_iface\` empty (this should never happen)"
	exit 1
fi
echo "Deleting default ipv4 route"
route -n delete default
echo "Adding default ipv4 route"
route -n add default -interface "$wg_iface"
echo "Deleting default ipv6 route"
route -n delete -inet6 default
echo "Adding default ipv6 route"
route -n add -inet6 default -interface "$wg_iface"
echo "Adding route to remote endpoint"
route -n add -host "$resolved_addr" $(cat ipv4_gw)
echo "Starting udp2raw"
udp2raw -c -l "127.0.0.1:$WIREGUARD_PORT" -r "$resolved_addr:$ENDPOINT_PORT" -k "$UDP2RAW_PWD" --dev "$default_iface" --source-port "$UDP2RAW_PORT" --cipher-mode xor --auth-mode simple > udp2raw.log 2>&1 &
{ cat /etc/pf.conf; echo "block drop in proto tcp from any to any port $UDP2RAW_PORT";} | pfctl -e -f -