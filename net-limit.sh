#!/bin/bash
# Apply IP limit & bandwidth

USER="$1"
IP="$2"
BW="$3"

IFACE=$(ip route | grep default | awk '{print $5}')

# IP LIMIT (1 IP)
iptables -A INPUT -s "$IP" -p udp --dport 5667 -j ACCEPT
iptables -A INPUT -p udp --dport 5667 -j DROP

# BANDWIDTH
if [[ "$BW" != "∞" ]]; then
  tc qdisc add dev $IFACE root handle 1: htb default 30 2>/dev/null
  tc class add dev $IFACE parent 1: classid 1:1 htb rate $BW
  tc filter add dev $IFACE protocol ip parent 1: prio 1 u32 match ip src $IP flowid 1:1
fi
