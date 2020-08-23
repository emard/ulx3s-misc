class MCP7940:
    """
        Example usage:

            # Read time
            mcp = MCP7940(i2c)
            time = mcp.time # Read time from MCP7940
            is_leap_year = mcp.is_leap_year() # Is the year in the MCP7940 a leap year?

            # Set time
            ntptime.settime() # Set system time from NTP
            mcp.time = utime.localtime() # Set the MCP7940 with the system time
    """

    ADDRESS = const(0x6F)
    RTCSEC = const(0)  # RTC seconds register
    ST = const(7)  # Status bit
    RTCWKDAY = const(3)  # RTC Weekday register
    CONTROL = const(7) # alarms, output, and trim fine/coarse (write 0 for default)
    OSCTRIM = const(8) # one's complement
    VBATEN = const(3)  # External battery backup supply enable bit

    def __init__(self, i2c, status=True, battery_enabled=True):
        self._i2c = i2c

    def init0(self):
        self._i2c.writeto_mem(MCP7940.ADDRESS, 0x07, bytes([0x10])) # CONTROL
        self._i2c.writeto_mem(MCP7940.ADDRESS, 0x08, bytes([0x25])) # OSCTRIM more -> slower
        self._i2c.writeto_mem(MCP7940.ADDRESS, 0x06, bytes([0x17])) # year
        self._i2c.writeto_mem(MCP7940.ADDRESS, 0x05, bytes([0x12])) # month
        self._i2c.writeto_mem(MCP7940.ADDRESS, 0x04, bytes([0x31])) # day
        self._i2c.writeto_mem(MCP7940.ADDRESS, 0x03, bytes([0x07 | 8])) # weekday | battery_backup
        self._i2c.writeto_mem(MCP7940.ADDRESS, 0x02, bytes([0x23])) # hour
        self._i2c.writeto_mem(MCP7940.ADDRESS, 0x01, bytes([0x59])) # minute
        self._i2c.writeto_mem(MCP7940.ADDRESS, 0x00, bytes([0x00| 0x80])) # second | start_oscillator

    def start(self):
        self._set_bit(MCP7940.RTCSEC, MCP7940.ST, 1)

    def stop(self):
        self._set_bit(MCP7940.RTCSEC, MCP7940.ST, 0)

    def is_started(self):
        return self._read_bit(MCP7940.RTCSEC, MCP7940.ST)

    @property
    def battery(self)->int:
        return self._read_bit(MCP7940.RTCWKDAY, MCP7940.VBATEN)

    @battery.setter
    def battery(self, enable:int):
        self._set_bit(MCP7940.RTCWKDAY, MCP7940.VBATEN, enable)

    @property
    def control(self)->int:
        val = self._i2c.readfrom_mem(MCP7940.ADDRESS, CONTROL, 1)
        return val[0]

    @control.setter
    def control(self, c:int):
        self._i2c.writeto_mem(MCP7940.ADDRESS, CONTROL, bytes([c]))

    @property
    def trim(self)->int:
        val = self._i2c.readfrom_mem(MCP7940.ADDRESS, OSCTRIM, 1)
        return val[0] & 0x7F if val[0] & 0x80 else -val[0]

    @trim.setter
    def trim(self, t:int):
        val = ((t & 0x7F) | 0x80) if t > 0 else ((-t) & 0x7F)
        self._i2c.writeto_mem(MCP7940.ADDRESS, OSCTRIM, bytes([val]))

    def alarm0_every_minute(self):
        # 0x07<=0x10 set control register, enable only alarm0
        # 0x08<=0x45 set oscillator digital trim
        self._i2c.writeto_mem(MCP7940.ADDRESS, 0x07, bytes([0x10, 0x45]))
        self._i2c.writeto_mem(MCP7940.ADDRESS, 0x0A, bytes([0x30])) # BCD seconds each minute
        self._i2c.writeto_mem(MCP7940.ADDRESS, 0x0D, bytes([0x01 | 0x00])) # weekday | match_condition seconds

    def _set_bit(self, register, bit, value):
        """ Set only a single bit in a register. To do so, need to read
            the current state of the register and modify just the one bit.
        """
        mask = 1 << bit
        current = self._i2c.readfrom_mem(MCP7940.ADDRESS, register, 1)
        updated = (current[0] & ~mask) | ((value << bit) & mask)
        self._i2c.writeto_mem(MCP7940.ADDRESS, register, bytes([updated]))

    def _read_bit(self, register, bit):
        register_val = self._i2c.readfrom_mem(MCP7940.ADDRESS, register, 1)
        return (register_val[0] & (1 << bit)) >> bit

    @property
    def time(self):
        return self._get_time()

    @time.setter
    def time(self, t):
        """
            >>> import time
            >>> time.localtime()
            (2019, 6, 3, 13, 12, 44, 0, 154)
            # 1:12:44pm on Monday (0) the 3 Jun 2019 (154th day of the year)
        """
        year, month, date, hours, minutes, seconds, weekday, yearday = t
        # Reorder
        time_reg = [seconds, minutes, hours, weekday + 1, date, month, year % 100]
        # Add ST (status) bit
        mask_and = (0x7F, 0x7F, 0x3F, 0x07, 0x3F, 0x1F, 0xFF)
        mask_or  = (0x80, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00) # set ST and VBATEN
        t = [((MCP7940.int_to_bcd(reg) & m_and) | m_or) for reg, m_and, m_or in zip(time_reg, mask_and, mask_or)]
        self._i2c.writeto_mem(MCP7940.ADDRESS, 0x00, bytes(t))

    @property
    def alarm0(self):
        return self._get_time(start_reg=0x0A)

    @alarm0.setter
    def alarm0(self, t):
        _, month, date, hours, minutes, seconds, weekday, _ = t  # Don't need year or yearday
        # Reorder
        time_reg = [seconds, minutes, hours, weekday + 1, date, month]
        reg_filter = (0x7F, 0x7F, 0x3F, 0x07, 0x1F, 0x3F)  # No year field for alarms
        t = [(MCP7940.int_to_bcd(reg) & filt) for reg, filt in zip(time_reg, reg_filter)]
        self._i2c.writeto_mem(MCP7940.ADDRESS, 0x0A, bytes(t))

    @property
    def alarm1(self):
        return self._get_time(start_reg=0x11)

    @alarm1.setter
    def alarm1(self, t):
        _, month, date, hours, minutes, seconds, weekday, _ = t  # Don't need year or yearday
        # Reorder
        time_reg = [seconds, minutes, hours, weekday + 1, date, month]
        reg_filter = (0x7F, 0x7F, 0x3F, 0x07, 0x1F, 0x3F)  # No year field for alarms
        t = [(MCP7940.int_to_bcd(reg) & filt) for reg, filt in zip(time_reg, reg_filter)]
        self._i2c.writeto_mem(MCP7940.ADDRESS, 0x11, bytes(t))

    def bcd_to_int(bcd):
        """ Expects a byte encoded wtih 2x 4bit BCD values. """
        # Alternative using conversions: int(str(hex(bcd))[2:])
        return (bcd & 0xF) + (bcd >> 4) * 10

    def int_to_bcd(i):
        return (i // 10 << 4) + (i % 10)

    def is_leap_year(year):
        """ https://stackoverflow.com/questions/725098/leap-year-calculation """
        if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0:
            return True
        return False

    def _get_time(self, start_reg = 0x00):
        num_registers = 7 if start_reg == 0x00 else 6
        time_reg = self._i2c.readfrom_mem(MCP7940.ADDRESS, start_reg, num_registers)  # Reading too much here for alarms
        reg_filter = (0x7F, 0x7F, 0x3F, 0x07, 0x3F, 0x1F, 0xFF)[:num_registers]
        #print(time_reg)
        #print(reg_filter)
        t = [MCP7940.bcd_to_int(reg & filt) for reg, filt in zip(time_reg, reg_filter)]
        # Reorder
        t2 = (t[5], t[4], t[2], t[1], t[0], t[3] - 1)
        t = (t[6] + 2000,) + t2 + (0,) if num_registers == 7 else t2
        # now = (2019, 7, 16, 15, 29, 14, 6, 167)  # Sunday 2019/7/16 3:29:14pm (yearday=167)
        # year, month, date, hours, minutes, seconds, weekday, yearday = t
        # time_reg = [seconds, minutes, hours, weekday, date, month, year % 100]

        #print(t)
        return t

    class Data:
        def __init__(self, i2c, address):
            self._i2c = i2c
            self._address = address
            self._memory_start = 0x20
            #self._memory_start = const(0x20)

        def __getitem__(self, key):
            get_byte = lambda x: self._i2c.readfrom_mem(self._address, x + self._memory_start, 1)(x)
            if type(key) is int:
                print('key: {}'.format(key))
                return get_byte(key)
            elif type(key) is slice:
                print('start: {} stop: {} step: {}'.format(key.start, key.stop, key.step))
                # fixme: Could be more efficient if we check for a contiguous block
                # Loop over range(64)[slice]
                return [get_byte(i) for i in range(64)[key]]

        def __setitem__(self, key, value):
            if type(key) is int:
                print('key: {}'.format(key))
            elif type(key) is slice:
                print('start: {} stop: {} step: {}'.format(key.start, key.stop, key.step))
            print(value)
