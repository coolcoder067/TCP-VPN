#!/bin/bash
cd $1
source script_env.cfg
while true; do
	ipv4_gw=$(route -n get default | grep gateway | awk "{print \$2}")
	if [[ -n "$ipv4_gw" ]]; then
		echo "Found IPv4 Gateway: $ipv4_gw"
		echo $ipv4_gw > ipv4_gw
		break
	fi
	echo "waiting one second to try again..."
	sleep 1
done
ipv6_gw=$(route -n get -inet6 default | grep gateway | awk "{print \$2}")
if [[ -n "$ipv6_gw" ]]; then
	echo "$ipv6_gw" > ipv6_gw
else
	rm -f ipv6_gw
fi
if [[ "$RESOLVE_WITH_DNS" == true ]]; then
	echo "resolving endpoint address..."
	resolved=$(timeout 1s dig +short "$ENDPOINT_ADDRESS" | head -n 1)
	if [[ -n "$resolved" ]]; then
		echo "$resolved" > resolved_addr
	else
		if [[ -f "resolved_addr" ]]; then
			echo "resolution failed, using cached"
		else
			echo "Error: Was not able to resolve '$ENDPOINT_ADDRESS'"
			exit 1
		fi
	fi
else
	echo "$ENDPOINT_ADDRESS" > resolved_addr
fi