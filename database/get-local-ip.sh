#!/bin/bash
default_iface=$(awk '$2 == 00000000 { print $1 }' /proc/net/route) 
default_ip=$(ip addr show dev "$default_iface" | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')

echo $default_ip
