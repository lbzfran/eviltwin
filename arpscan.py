#!/usr/bin/env python

from scapy.all import ARP, Ether, sniff

# Callback function to process each packet
def process_packet(packet):
    if packet.haslayer(ARP):
        arp_layer = packet[ARP]
        ether_layer = packet[Ether]

        print("ARP Packet:")
        print(f" - Source MAC: {ether_layer.src}")
        print(f" - Source IP: {arp_layer.psrc}")
        print(f" - Destination MAC: {ether_layer.dst}")
        print(f" - Destination IP: {arp_layer.pdst}")
        print(f" - Opcode: {arp_layer.op}")
        print("-" * 30)

# Start sniffing ARP packets
def main():
    print("Listening for ARP packets...")
    sniff(prn=process_packet, filter="arp", store=0)

if __name__ == "__main__":
    main()
