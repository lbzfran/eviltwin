#!/bin/sh

upstream=wlp4s0
ap=wlp0s20f0u2

apnet=192.168.11

if [ "$1" = "1" ]; then
    pkill hostapd
    pkill dnsmasq
    echo 0 > /proc/sys/net/ipv4/ip_forward
    iptables -t nat -D POSTROUTING -s $apnet.0/24 ! -d $apnet.0/24 -j MASQUERADE
    exit
fi

ip addr add $apnet.1/24 dev $ap
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -s $apnet.0/24 ! -d $apnet.0/24 -j MASQUERADE

hostapd -B ./hostapd.conf


dnsmasq --interface=$ap --dhcp-range=$apnet.100,$apnet.199

