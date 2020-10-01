# ETH RMII LAN8720

Simple ethernet packet sniffer and sender.
Packet content will be shown in HEX on DVI and LCD display.
By pressing BTN1 a fixed ARP reply will be sent.

# Usage

Plug LAN8720 module to GP-GN 9-13, align GND=GND and VCC=3.3V.
Plug DVI digital montior to GPDI port and/or
plug ST7789 7-pin LCD display to 7-pin header, align GND and VCC too.

LAN8720 has green &#x1f7e9; and yellow &#x1f7e7; LED at its RJ45 connector.
At power-on default (when only VCC and GND connected),
it should starts with 100 Mbps half-duplex with LEDs
described here.

|     GREEN       |    YELLOW     |                                |
|-----------------|---------------|--------------------------------|
| &#x1f7e9; ON    | &#x2b1b;  OFF | no cable or link DOWN          |
| &#x2b1b;  OFF   | &#x1f7e7; ON  | connected, link UP, no traffic |
| &#x1f7e9; BLINK | &#x1f7e7; ON  | connected and TX or RX traffic | 

If descibed LED behaviour can't be obtained, try disconnecting
pins MDC and MDIO, or disconnect all pins. Connect GND first,
then VCC, and other pins after module boots.

Connect LAN8720 with ethernet cable to PC. 

Give PC ethernet some IP address

    ifconfig eth0 192.168.18.254
    ifconfig eth0
    eth0:   flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
            inet 192.168.18.254  netmask 255.255.255.0  broadcast 192.168.18.255
            ether 00:11:22:33:44:55  txqueuelen 1000  (Ethernet)
            ...

Start pinging any non-existing address on the same LAN as configured PC IP.
Ping will generate ARP requests at each attempt and you should see green
&#x1f7e9; LED blinking each second while yellow &#x1f7e7; LED constantly ON:

    ping 192.168.18.128
    PING 192.168.18.128 (192.168.18.128) 56(84) bytes of data.
    From 192.168.18.254 icmp_seq=1 Destination Host Unreachable
    From 192.168.18.254 icmp_seq=2 Destination Host Unreachable

Start tcpdump to see the requests in HEX:

    tcpdump -XX -n -i eth0
    01:59:02.140687 ARP, Request who-has 192.168.18.128 tell 192.168.18.254, length 28
            0x0000:  ffff ffff ffff 0011 2233 4455 0806 0001  ........"3DU....
            0x0010:  0800 0604 0001 0011 2233 4455 c0a8 12fe  ........"3DU....
            0x0020:  0000 0000 0000 c0a8 1280                 ..........

Take a look at DVI monitor or LCD ST7789 display, you should see same HEX content
but bytes from right to left.

                  <-- vv first byte
    ....1100FFFFFFFFFFFF
    ....0100060855443322
    ....1100010004060008
    ....FE12A8C055443322
    ....A8C0000000000000
    ....0000000000008012

"...." is HEX content repeated by display HEX decoder,
not printed here for clarity.

Press BTN1 to send a fixed ARP reply. Green &#x1f7e9; LED should blink
each time BTN1 is pressed.

    01:56:24.564032 ARP, Reply 192.168.18.128 is-at 00:40:00:01:02:03, length 52
            0x0000:  ffff ffff ffff 0040 0001 0203 0806 0001  .......@........
            0x0010:  0800 0604 0002 0040 0001 0203 c0a8 1280  .......@........
            0x0020:  ffff ffff ffff c0a8 1280 0000 0000 0000  ................
            0x0030:  0000 0000 0000 0000 0000 0000 0000 6d2a  ..............m*
            0x0040:  fed9                                     ..

This data should enter kernel ARP table and stay there for few seconds,
so quickly after BTN1, issue this command:

    arp -an
    ? (192.168.18.128) at 00:40:00:01:02:03 [ether] on eth0

Receiving LAN8720 TX ARP traffic should be possible when LAN8720 is directly
connected with a cable to PC ETH port which captures packets.
If ETH switch is between LAN8720 and PC, ARP packets probably won't
be captured by PC.

# Packet generator

Use "ethpack.py" to generate your own packets like "arp_reply.mem".
To given packet payload it will prepend preamble and append calculated CRC.
In toplevel, edit reply_len = N to match with generated packet len,
reported in comment at the first line of *.mem file.

# Special capture

This is not necessarey for the example here, but it is
the method how content of "arp_reply.mem" including CRC
is captured.
linux with some ethernet cards can use special ethernet option
to show CRC and to capture even those packets which have bad CRC:

    ethtool -K eth0 rx-fcs on rx-all on

# Compiling

cleanup:

    make -f makefile.trellis clean

compile:

    make -f makefile.trellis

program (upload to SRAM, temporary):

    make -f makefile.trellis program

or

    make -f makefile.trellis program_ocd

