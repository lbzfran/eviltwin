#!/bin/bash

# must run as root
DEBUG=${1:-0}

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi


pidof -q dnsmasq hostapd
if [ "$?" = "0" ]; then
    echo "[*] found running processes for dnsmasq and hostapd."
    if [ ! -f ./__intproc ]; then
        # set interface arbitrarily if the __intproc file dne
        echo "[*] '__intproc' file not found at current directory."
        echo "[*] defaulting to target 'wlp4s0'."
        interface=wlp4s0
    else
        echo "[*] loading and deleting '__intproc' file."
        interface=$(cat ./__intproc)
        rm -f ./__intproc
    fi
    echo "[+] ending related processes."
    pkill dnsmasq
    pkill hostapd

    echo "[+] removing iptable configs and restarting wifi services."
    iptables -t nat -D PREROUTING -i $interface -p tcp --dport 80 -j REDIRECT --to-port 8080
    iptables -t nat -D PREROUTING -i $interface -p tcp --dport 443 -j REDIRECT --to-port 8080
    systemctl restart NetworkManager

    echo "[+] clean exit."
    exit
fi

interface=$(ip a | grep -o '\<\S*w\S*\>' | sort -u | fzf)
if [ "$interface" = "" ]; then
    exit
fi
echo $interface > ./__intproc
chmod 444 ./__intproc

if [ "$DEBUG" = "0" ]; then
    ip a | grep -q "$interface"
else
    ip a | grep -q "$interface"
fi

if [ ! "$?" = "0" ]; then
    echo "[-] interface error: invalid interface '$interface'";
    exit
fi
echo "[+] interface '$interface' validated.";

sed -i "s/\(interface=\)\(.*\)/\1${interface}/" ./dnsmasq.conf ./hostapd.conf

echo "[+] setting up related services."
if [ $(cat /proc/sys/net/ipv4/ip_forward) -eq 0 ]; then
    echo 1 | sudo tee > /proc/sys/net/ipv4/ip_forward
    sysctl -p
fi
iptables -t nat -A PREROUTING -i $interface -p tcp --dport 80 -j REDIRECT --to-port 8080
iptables -t nat -A PREROUTING -i $interface -p tcp --dport 443 -j REDIRECT --to-port 8080


echo "[+] temporarily killing related wifi services."
pidof dnsmasq && pkill dnsmasq
pidof hostapd && pkill hostapd
airmon-ng check kill

echo "[+] setting ifconfig and route."
ifconfig $interface 10.0.0.1/24
ifconfig $interface 10.0.0.1 netmask 255.255.255.0
route add default gw 10.0.0.1
[ "$DEBUG" = "0" ] && route -n


echo "[+] starting dnsmasq."
dnsmasq -C dnsmasq.conf
echo "[+] starting hostapd."
exec hostapd -dt ./hostapd.conf >> ./hostapd.log &

# will hang here until user exits
echo "[*] execute 'run.sh' again as root to stop."
