# Project config
all: multi

FLASH_SIZE_MBIT := 128

# files and addresses in FLASH where to write bitstreams
BITSTREAM0_FILE := bitstream0/ulx3s_12f_bitstream0.bit
BITSTREAM0_ADDR := 0x000000 # always 0

BITSTREAM1_FILE := bitstream1/ulx3s_12f_bitstream1.bit
BITSTREAM1_ADDR := 0x200000

BITSTREAM2_FILE := bitstream2/ulx3s_12f_bitstream2.bit
BITSTREAM2_ADDR := 0x400000

BUILD_TMP := /tmp/

$(BITSTREAM0_FILE):
	cd bitstream0; make

$(BITSTREAM1_FILE):
	cd bitstream1; make

$(BITSTREAM2_FILE):
	cd bitstream2; make

$(BUILD_TMP)/multiboot.img: $(BITSTREAM0_FILE) $(BITSTREAM1_FILE) $(BITSTREAM2_FILE) 
	ecpmulti                       --input $(BITSTREAM0_FILE) \
	  --address $(BITSTREAM1_ADDR) --input $(BITSTREAM1_FILE) \
	  --address $(BITSTREAM2_ADDR) --input $(BITSTREAM2_FILE) \
	  --flashsize $(FLASH_SIZE_MBIT) \
	  --output $@

# model=ulx4m DEVICE=um-85k:
# this must be used for bootloader to jump to user bitstream
# without this, even normal programming will fail if bootloader is loaded.
# this can also be used to apply non-serdes bootloader bitstream to serdes 85F chip
#	  --input-idcode  0x01113043 \
#	  --output-idcode 0x01113043 \

$(BUILD_TMP)/multiboot.img.gz: $(BUILD_TMP)/multiboot.img
	./gzip4k.py $< $@

# make multiboot image
multi: $(BUILD_TMP)/multiboot.img.gz

# flash multiboot image with fujprog
flash: $(BUILD_TMP)/multiboot.img
	fujprog -j flash $<

# flash multiboot image with openFPGALoader
flash_ofl: $(BUILD_TMP)/multiboot.img
	openFPGALoader -b ulx3s --file-type bin -f $<

clean:
	rm -f *~ $(BUILD_TMP)/multiboot.img.gz $(BUILD_TMP)/multiboot.img
	cd bitstream0; make clean
	cd bitstream1; make clean
	cd bitstream2; make clean

