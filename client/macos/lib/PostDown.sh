#!/bin/bash
cd $1
#source script_env.cfg # Not used here
resolved_addr=$(cat resolved_addr)
killall udp2raw || true
echo "Deleting default ipv4 route"
route -n delete default
echo "Adding default ipv4 route"
route -n add default $(cat ipv4_gw)
echo "Deleting default ipv6 route"
route -n delete -inet6 default
if [[ -e ipv6_gw ]]; then
	echo "Adding default ipv6 route"
	route -n add -inet6 default $(cat ipv6_gw)
fi
echo "Deleting route to remote endpoint"
route -n delete "$resolved_addr"
pfctl -d