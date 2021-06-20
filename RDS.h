/*  Original code from:
    
    PiFmRds - FM/RDS transmitter for the Raspberry Pi
    Copyright (C) 2014 Christophe Jacquet, F8FTK
    
    See https://github.com/ChristopheJacquet/PiFmRds

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
    Modification: by EMARD
    deleted everything except RDS bit generator
    converted to c++ for arduino, renamed functions
    
*/

#ifndef _RDS_h
#define _RDS_h

#include <stdint.h>

// hardware address of 260-byte RDS buffer
// 260 32-bit words contain each a 8-bit byte (LSB)
#define RDS_ADDRESS 0xFFFFF000

#define RDS_GROUP_LENGTH 4
#define RDS_BITS_PER_GROUP (RDS_GROUP_LENGTH * (RDS_BLOCK_SIZE+RDS_POLY_DEG))

/* The RDS error-detection code generator polynomial is
   x^10 + x^8 + x^7 + x^5 + x^4 + x^3 + x^0
*/
#define RDS_POLY 0x1B9
#define RDS_POLY_DEG 10
#define RDS_MSB_BIT 0x8000
#define RDS_BLOCK_SIZE 16

#define RDS_RT_LENGTH 64
#define RDS_PS_LENGTH 8

class RDS {
  public:
    RDS();

    void setmemptr(uint8_t *set_rdsmem);
    // those function have immediate effect
    // pass them value and transmitter starts
    // sending it
    void ps(char *ps);
    void rt(char *rt);
    void ct(int16_t year, uint8_t mon, uint8_t mday, uint8_t hour, uint8_t min, int16_t gmtoff);
    void pi(uint16_t pi_code);
    void ta(uint8_t ta);
    void stereo(uint8_t stereo);

    inline void Hz(uint32_t f)
    {
      //volatile uint32_t *fmrds_hz = (volatile uint32_t *) 0xFFFFFC00;
      //*fmrds_hz = f;
    }

    inline void msgbyte(uint16_t a, uint8_t b)
    {
      //volatile uint8_t *fmrds_msg_data = (volatile uint8_t *) 0xFFFFFC04;
      //volatile uint16_t *fmrds_msg_addr = (volatile uint16_t *) 0xFFFFFC06;
      //volatile uint32_t *fmrds_msg_data_addr = (volatile uint32_t *) 0xFFFFFC04;
      //*fmrds_msg_data_addr = (a << 16) | b;
      rdsmem[a] = b;
      //*fmrds_msg_addr = a;
      //*fmrds_msg_data = b;
    }

    inline void length(uint16_t len)
    {
      volatile uint32_t *fmrds_msg_len = (volatile uint32_t *) 0xFFFFFC08;
      *fmrds_msg_len = len-1;
    }

  private:

    // those functions take value to class but
    // doesn't change transmitted data
    void new_pi(uint16_t pi_code);
    void new_rt(char *rt);
    void new_ps(char *ps);
    void new_ta(uint8_t ta);

    // those functions convert values of this class to output binary
    void binary_buf_crc(uint8_t *buffer, uint16_t *blocks);
    void binary_ps_group(uint8_t *buffer, uint8_t group_number);
    void binary_rt_group(uint8_t *buffer, uint8_t group_number);
    void binary_ct_group(uint8_t *buffer);

    // copies output binary to hardware transmission buffer
    void send_ps();
    void send_rt();
    void send_ct();

    // calculates checksums for binary format  
    uint16_t crc(uint16_t block);

    // internal RDS message in cleartext
    uint16_t value_pi   = 0xCAFE; // program ID
    uint8_t signal_tp   = 1; // traffic program
    uint8_t signal_ta   = 0; // traffic announcement
    uint8_t signal_ms   = 0; // 1=music, 0=speech
    uint8_t signal_mono = 1; // 1=mono,  0=stereo
    uint8_t signal_pty  = 8; // program type (0=undefined, 3=information, 8=science, see RDS wiki)
    uint8_t afs = 1;
    uint16_t af[7] = {1079, 0, 0, 0, 0, 0, 0}; // x0.1 MHz
    char string_ps[RDS_PS_LENGTH]; // short 8-char text shown as station name
    char string_rt[RDS_RT_LENGTH]; // long 64-char text

    /* time stuff */
    uint8_t tm_hour, tm_min;
    uint8_t tm_mon, tm_mday;
    int16_t tm_year; // year-1900
    int16_t tm_gmtoff; // local time to gmt offset in seconds

    uint8_t *rdsmem = (uint8_t *)NULL;
    // some constants required to compose binary format
    const uint16_t offset_words[4] = {0x0FC, 0x198, 0x168, 0x1B4};
    // We don't handle offset word C' here for the sake of simplicity
};
#endif
