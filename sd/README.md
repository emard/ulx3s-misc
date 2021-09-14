# SD card content

Copy content of this "/sd" directory to SD card.
Partiton scheme should be MSDOS, first primary
partition should be formatted as FAT32.

If new SD card is factory formatted as EXFAT,
it has to be reformatted to FAT32 before first use.
Tested and works for 64GB SDXC Sandisk card.

    mkfs.vaf -F32 -n PROFILOG /dev/sda1

Generate audio .WAV files:

    cd sd/profilog/speak
    make

Mount SD card

    mount /dev/sda1 /mnt

Copy recursive "/sd/*" content to SD card

    cd sd
    cp -r * /mnt

Unmount SD card

    umount /mnt

Remove SD from PC and insert it into ULX3S.

    fujprog -t
    SD_MMC Card Type: SDHC
    SD_MMC Card Size: 60906MB
    Total space: 60875MB
    Used space: 1MB
    Free space: 60873MB
    *** open /profilog/config/profilog.cfg

