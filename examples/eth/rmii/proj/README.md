# ETH RMII LAN8720

Plug LAN8720 module to GP-GN 9-13, align GND=GND and VCC=3.3V.
Plug ST7789 7-pin LCD display to 7-pin header, align GND and VCC too.

LAN8720 has green and yellow LED at its RJ45 connector.
Connect LAN8720 with ethernet cable to PC. 
If cable is not connected or connected but PC ethernet is not UP,
green LED should be ON, yellow LED OFF.

Give PC ethernet some IP address

    ifconfig eth0 192.168.18.254
    ifconfig eth0
    eth0:   flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
            inet 192.168.18.254  netmask 255.255.255.0  broadcast 192.168.18.255
            ether 00:11:22:33:44:55  txqueuelen 1000  (Ethernet)
            ...

If no traffic, green LED should be OFF and yellow LED ON.

Start pinging any non-existing address on the same LAN as configured PC IP.
Ping will generate ARP requests at each attempt and you should see green
LED blinking each second:

    ping 192.168.18.1
    PING 192.168.18.1 (192.168.18.1) 56(84) bytes of data.
    From 192.168.18.254 icmp_seq=1 Destination Host Unreachable
    From 192.168.18.254 icmp_seq=2 Destination Host Unreachable

Start tcpdump to see the requests in HEX:

    tcpdump -XX -n -i eth0
    17:37:54.528117 ARP, Request who-has 192.168.18.1 tell 192.168.18.254, length 28
            0x0000:  ffff ffff ffff 0011 2233 4455 0806 0001  ........"3DU....
            0x0010:  0800 0604 0001 0011 2233 4455 c0a8 12fe  ........"3DU....
            0x0020:  0000 0000 0000 c0a8 1201                 ..........

Take a look at LCD ST7789 display, you should see same HEX content after ffff,
but bytes from right to left.

    ....0608554433221100
    ....0100040600080100
    ....A8C0554433221100
    ....000000000000FE12
    ....................

"..." is HEX content repeated by
display HEX decoder, not printed here for clarity,

# compiling

cleanup:

    make -f makefile.trellis clean

compile:

    make -f makefile.trellis

program (upload to SRAM, temporary):

    make -f makefile.trellis program

or

    make -f makefile.trellis program_ocd

