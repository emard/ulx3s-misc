# SDRAM test

writing and reading N bytes to/from SPI bus works.

test it with spiram.py 

    >>> import spiram
    >>> spiram.poke(0,"abcdABCD12345678") # write 16 bytes from address 0
    >>> spiram.peek(0,16)                 # read  16 bytes from address 0 should be same as above
    bytearray(b'abcdABCD12345678')
