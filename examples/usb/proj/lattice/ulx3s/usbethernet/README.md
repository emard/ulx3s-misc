# USB-CDC Ethernet core

Plug US2 to linux host, usb-ethernet device should be detected:

    cdc_ether 1-6.1:1.0 enx00aabbccddee: unregister 'cdc_ether' usb-0000:00:15.0-6.1, CDC Ethernet Device
    usb 1-6.1: new full-speed USB device number 116 using xhci_hcd
    usb 1-6.1: New USB device found, idVendor=fb9a, idProduct=fb9a, bcdDevice= 0.31
    usb 1-6.1: New USB device strings: Mfr=1, Product=2, SerialNumber=3
    usb 1-6.1: Product: Product
    usb 1-6.1: Manufacturer: Vendor
    usb 1-6.1: SerialNumber: 00AABBCCDDEE
    cdc_ether 1-6.1:1.0 eth1: register 'cdc_ether' at usb-0000:00:15.0-6.1, CDC Ethernet Device, 00:aa:bb:cc:dd:ee
    cdc_ether 1-6.1:1.0 enx00aabbccddee: renamed from eth1

It has simple low-level icmp echo responder that is
not compatible with "ping" but
works with "nping" from the "nmap" package:

    apt-get install nmap

Assign some IP address to host-side of USB-ethernet device:

    ifconfig enx00aabbccddee 192.168.99.1    

Run the test - with 1ms delay between packets, it should loose 0% packets:

    nping -c 1000 --privileged -delay 1ms -q1 --send-eth -e enx00aabbccddee --dest-mac 00:11:22:33:44:AA --data 0011223344556677  192.168.99.2

    Starting Nping 0.7.80 ( https://nmap.org/nping ) at 2019-11-23 00:37 CET
    Max rtt: 0.204ms | Min rtt: 0.105ms | Avg rtt: 0.112ms
    Raw packets sent: 1000 (50.000KB) | Rcvd: 1000 (36.000KB) | Lost: 0 (0.00%)
    Nping done: 1 IP address pinged in 1.94 seconds

Without delay (flood ping) - it should loose around 2% packets.

    nping -c 10000 --privileged -delay 0ms -q1 --send-eth -e enx00aabbccddee --dest-mac 00:11:22:33:44:AA --data 0011223344556677  192.168.99.2

    Starting Nping 0.7.80 ( https://nmap.org/nping ) at 2019-11-23 00:39 CET
    Max rtt: 0.691ms | Min rtt: 0.019ms | Avg rtt: 0.019ms
    Raw packets sent: 10000 (500.000KB) | Rcvd: 9818 (353.648KB) | Lost: 182 (1.82%)
    Nping done: 1 IP address pinged in 1.82 seconds

Watch the traffic:

    tcpdump -i enx00aabbccddee -e -XX -n icmp

