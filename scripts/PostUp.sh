#!/bin/bash
cd $1
source script_env.cfg
resolved_addr=$(cat resolved_addr)
wg_iface=$(wg show | awk '/interface:/{print $2}')
default_iface=$(route -n get default | awk '/interface:/{print $2}')
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
udp2raw -c -l "127.0.0.1:$LOCAL_PORT" -r "$resolved_addr:$ENDPOINT_PORT" -k "$UDP2RAW_PWD" --dev "$default_iface" > udp2raw.log 2>&1 &