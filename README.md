
# Steps

1. Setup Wi-Fi Hotspot
- hostapd for creating hotspot
- dnsmasq for DHCP and DNS services

2. Intercept Web Traffic
- use Squid or mitmproxy (python pkg) to intercept and modify web traffic
- configure the proxy to listen on specific port
- modify the content

3. redirect users
- setup dnsmasq to route all DNS requests to your proxy server
