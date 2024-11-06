#!/bin/bash

# must run as root
DEBUG=${1:-0}

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit
fi

set_iptables() {
    # $1: A, I, or D
    # $2: wifi interface
    iptables -t nat -$1 POSTROUTING -o $2 -j MASQUERADE

    iptables -$1 FORWARD -i ${2}_ap -o $2 -j ACCEPT
    iptables -$1 FORWARD -i $2 -o ${2}_ap -m state --state RELATED,ESTABLISHED -j ACCEPT
    #iptables -t nat -$1 PREROUTING -i ${2}_ap -p tcp --dport 80 -j REDIRECT --to-port 8080
    #iptables -t nat -$1 PREROUTING -i ${2}_ap -p tcp --dport 443 -j REDIRECT --to-port 8080
}

#TEMP_INTERFACE=wl
WIFI_INTERFACE=wlp4s0
INTERNET_INTERFACE=wlp0s20f0u6
GATEWAY=10.0.0.1

# if __intproc exists, script was still ongoing in bg.
# the only time this could fail is if the host restarts the system
# without running script again.
if [ -f ./__intproc ]; then
    echo "[*] loading '__intproc' file."
    WIFI_INTERFACE=$(head -n1 ./__intproc)
    #INTERNET_INTERFACE=$(tail -n1 ./__intproc)

    pidof -q dnsmasq hostapd
    if [ ! "$?" = "0" ]; then
        echo "[-] potential PROCESS error? dnsmasq and hostapd not running, but __intproc file exists."

        ip a | grep -q "${WIFI_INTERFACE}_ap"
        if [ ! "$?" = "0" ]; then
            echo "[-] INTERFACE error: '${WIFI_INTERFACE}_ap' not found.";
            echo "[*] RESOLVE: delete existing ap interface: 'sudo iw dev ${WIFI_INTERFACE}_ap del'";
        else
            echo "[*] INTERFACE exists: '${WIFI_INTERFACE}_ap'.";
        fi
        echo "[*] RESOLVE: check iptables: 'sudo iptables -t nat -L -n -v'."
        echo "[*] RESOLVE: if no issues are found, delete '__intproc' file and re-run script."
        exit
    fi
    echo "[*] found running processes for dnsmasq and hostapd."

    echo "[*] deleting '__intproc' file."
    rm -f ./__intproc

    echo "[+] ending related processes."
    pkill dnsmasq
    pkill hostapd

    echo "[+] removing ip forwarding and iptable configs."
    echo 0 > /proc/sys/net/ipv4/ip_forward

    systemctl stop NetworkManager

    set_iptables D ${WIFI_INTERFACE}

    iw dev ${WIFI_INTERFACE}_ap del
    iw dev ${WIFI_INTERFACE}_nm del

    systemctl start NetworkManager
    #
    # iptables -t nat -D POSTROUTING -o $INTERNET_INTERFACE -j MASQUERADE > /dev/null 2>&1
    # iptables -D FORWARD -i $WIFI_INTERFACE -s ${GATEWAY%.*}.0/24 -j ACCEPT > /dev/null 2>&1
    # iptables -D FORWARD -i $WIFI_INTERFACE -d ${GATEWAY%.*}.0/24 -j ACCEPT > /dev/null 2>&1

    echo "[+] restarting NetworkManager."
    #systemctl restart NetworkManager

    echo "[+] clean exit."
    exit
fi

echo "[*] select wifi interface" && sleep 1
WIFI_INTERFACE=$(ip a | grep -o '\<\S*w\S*\>' | sort -u | fzf --height=50% --layout=reverse)
if [ "$WIFI_INTERFACE" = "" ]; then
    exit
fi
ip a | grep -q "$WIFI_INTERFACE"
if [ ! "$?" = "0" ]; then
    echo "[-] INTERFACE error: invalid wifi INTERFACE '$WIFI_INTERFACE'";
    exit
fi
echo "[+] INTERFACE '$WIFI_INTERFACE' validated.";

# echo "[*] select internet interface (ensure it is not the same as wifi)" && sleep 1
# INTERNET_INTERFACE=$(ip a | grep -o '\<\S*w\S*\>' | sort -u | fzf --height=50% --layout=reverse)
#
# ip a | grep -q "$INTERNET_INTERFACE"
# if [ ! "$?" = "0" ]; then
#     echo "[-] INTERFACE error: invalid internet INTERFACE '$INTERNET_INTERFACE'";
#     exit
# fi
# echo "[+] INTERFACE '$INTERNET_INTERFACE' validated.";

printf "$WIFI_INTERFACE\n$INTERNET_INTERFACE" > ./__intproc
chmod 444 ./__intproc

sed -i "s/\(interface=\)\(.*\)/\1${WIFI_INTERFACE}_ap/" ./dnsmasq.conf ./hostapd.conf

echo "[+] temporarily killing related wifi services."
pidof dnsmasq && pkill dnsmasq
pidof hostapd && pkill hostapd

airmon-ng check kill

echo "[+] setting up iptables and ip forwarding."

#systemctl restart NetworkManager

ifconfig wlp4s0 down

iw phy phy0 interface add ${WIFI_INTERFACE}_ap type __ap

set_iptables A ${WIFI_INTERFACE}

# iptables -t nat -I POSTROUTING -o ${INTERNET_INTERFACE} -j MASQUERADE || quit
# iptables -I FORWARD -i ${WIFI_INTERFACE} -s ${GATEWAY%.*}.0/24 -j ACCEPT || quit
# iptables -I FORWARD -i ${INTERNET_INTERFACE} -d ${GATEWAY%.*}.0/24 -j ACCEPT || quit
#

if [ $(cat /proc/sys/net/ipv4/ip_forward) -eq 0 ]; then
    echo 1 > /proc/sys/net/ipv4/ip_forward || quit
    sysctl -p
fi

#ip link set $WIFI_INTERFACE up
#iw ${WIFI_INTERFACE} connect eduroam

echo "[+] setting ifconfig and route."
ifconfig ${WIFI_INTERFACE}_ap 10.0.0.1/24
ifconfig ${WIFI_INTERFACE}_ap 10.0.0.1 netmask 255.255.255.0
#ifconfig ${WIFI_INTERFACE}_ap hw ether 00:11:22:33:44:55
route add default gw 10.0.0.1
[ "$DEBUG" = "0" ] && route -n

iw phy phy0 interface add ${WIFI_INTERFACE}_nm type station
#ifconfig ${WIFI_INTERFACE}_nm hw ether 00:11:22:33:44:66
#iw ${WIFI_INTERFACE}_nm connect eduroam
#dhclient ${WIFI_INTERFACE}_nm

echo "[+] starting dnsmasq."
dnsmasq -C dnsmasq.conf
echo "[+] starting hostapd."
exec hostapd -dt ./hostapd.conf >> ./hostapd.log &

# will hang here until user exits
echo "[*] execute 'run.sh' again as root to stop."
