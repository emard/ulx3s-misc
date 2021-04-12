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

#include <string.h>
#include "RDS.h"

/* constructor takes RDS memory address */
RDS::RDS()
{
}

void RDS::setmemptr(uint8_t *set_rdsmem)
{
  rdsmem = set_rdsmem;
}

/* Classical CRC computation */
uint16_t RDS::crc(uint16_t block) {
    uint16_t crc = 0;
    
    for(int j=0; j<RDS_BLOCK_SIZE; j++) {
        int bit = (block & RDS_MSB_BIT) != 0;
        block <<= 1;

        int msb = (crc >> (RDS_POLY_DEG-1)) & 1;
        crc <<= 1;
        if((msb ^ bit) != 0) {
            crc = crc ^ RDS_POLY;
        }
    }
    
    return crc;
}


// write block to the buffer and append the CRC
void RDS::binary_buf_crc(uint8_t buffer[], uint16_t blocks[])
{
    int bitptr = 0; // pointer to a bit in the buffer

    /* erase buffer */
    for(int i = 0; i < RDS_BITS_PER_GROUP/8; i++)
      buffer[i] = 0;

    // Calculate the checkword for each block and emit the bits
    for(int i=0; i<RDS_GROUP_LENGTH; i++) {
        uint16_t block = blocks[i];
        uint16_t check = crc(block) ^ this->offset_words[i];
        for(int j=0; j<RDS_BLOCK_SIZE; j++) {
            buffer[bitptr/8] |= ((block & (1<<(RDS_BLOCK_SIZE-1))) != 0) << (7 - bitptr % 8);
            bitptr++;
            block <<= 1;
        }
        for(int j=0; j<RDS_POLY_DEG; j++) {
            buffer[bitptr/8] |= ((check & (1<<(RDS_POLY_DEG-1))) != 0) << (7 - bitptr % 8);
            bitptr++;
            check <<= 1;
        }
    }
}

// write buffer with n-th group of PS
// PS consists of 4 groups of 13 bytes each numbered 0..3 
// lower 2 bits of n define the group number
void RDS::binary_ps_group(uint8_t *buffer, uint8_t group_number)
{
  uint16_t blocks[RDS_GROUP_LENGTH] = {this->value_pi, 0, 0, 0};
  uint8_t gn = group_number & 3; // group number

  blocks[1] = 0x0400 | gn;
  if(this->signal_stereo != 0 && gn == 3)
    blocks[1] |= 0x0004;
  if(this->signal_ta)
    blocks[1] |= 0x0010;
  blocks[2] = 0xCDCD;     // no AF
  if(gn == 0)
    // 224..249 -> 0..25 AFs but we support max 7
    blocks[2] = (blocks[2] & 0x00FF) | ((this->afs+224)<<8);
  else
  {
    if(this->af[2*gn-1] > 875)
     blocks[2] = (blocks[2] & 0x00FF) | ((this->af[2*gn-1]-875)<<8);    
  }
  if(this->af[2*gn] > 875)
    blocks[2] = (blocks[2] & 0xFF00) | (this->af[2*gn]-875);
  blocks[3] = this->string_ps[gn*2]<<8 | this->string_ps[gn*2+1];
  binary_buf_crc(buffer, blocks);
}

// write buffer with n-th group of RT
// RT consists of 16 groups of 13 bytes each numbered 0..15 
// lower 4 bits of n define the group number
void RDS::binary_rt_group(uint8_t *buffer, uint8_t group_number)
{
  uint16_t blocks[RDS_GROUP_LENGTH] = {this->value_pi, 0, 0, 0};
  uint8_t gn = group_number & 15; // group number

  blocks[1] = 0x2400 | gn;
  blocks[2] = this->string_rt[gn*4+0]<<8 | this->string_rt[gn*4+1];
  blocks[3] = this->string_rt[gn*4+2]<<8 | this->string_rt[gn*4+3];

  binary_buf_crc(buffer, blocks);
}

/* generates a CT (clock time) group */
void RDS::binary_ct_group(uint8_t *buffer)
{
  uint16_t blocks[RDS_GROUP_LENGTH] = {this->value_pi, 0, 0, 0};
  int latest_minutes = -1;

  // Generate CT group
  latest_minutes = this->tm_min;

  int l = this->tm_mon <= 1 ? 1 : 0;
  int mjd = 14956 + this->tm_mday +
             (int)((this->tm_year - l) * 365.25) +
             (int)((this->tm_mon + 2 + l*12) * 30.6001);

  blocks[1] = 0x4400 | (mjd>>15);
  blocks[2] = (mjd<<1) | (this->tm_hour>>4);
  blocks[3] = (this->tm_hour & 0xF)<<12 | this->tm_min<<6;

  int offset = this->tm_gmtoff / (30 * 60);
  blocks[3] |= offset < 0 ? -offset : offset;
  if(offset < 0) blocks[3] |= 0x20;

  binary_buf_crc(buffer, blocks);
}

void RDS::send_ps(void)
{
  int rds_mem_offset = 0;
  uint8_t bit_buffer[RDS_BITS_PER_GROUP/8];
  for(int i = 0; i < 4; i++)
  {
    #if 0
    rds_mem_offset = (RDS_BITS_PER_GROUP/8) * (i*5);
    #endif
    rds_mem_offset = (RDS_BITS_PER_GROUP/8) * i;
    binary_ps_group(bit_buffer, i);
    for(int j = 0; j < RDS_BITS_PER_GROUP/8; j++)
    {
      // this->rdsmem[rds_mem_offset++] = bit_buffer[j];
      msgbyte(rds_mem_offset++, bit_buffer[j]);
    }
  }
}

void RDS::send_rt(void)
{
  int rds_mem_offset = 0;
  uint8_t bit_buffer[RDS_BITS_PER_GROUP/8];
 
  for(int i = 0; i < 16; i++)
  {
    #if 0
    if( (i & 3) == 0) // skip locations of PS packets
      rds_mem_offset += (RDS_BITS_PER_GROUP/8);
    #endif
    binary_rt_group(bit_buffer, i);
    for(int j = 0; j < RDS_BITS_PER_GROUP/8; j++)
    {
      // this->rdsmem[rds_mem_offset++] = bit_buffer[j];
      msgbyte(rds_mem_offset++, bit_buffer[j]);
    }
  }
}

void RDS::pi(uint16_t pi_code) // public
{
    this->value_pi = pi_code;
    // PI changed - immediately recalculate checksums for all binaries
    send_ps();
    send_rt();
}

void RDS::new_rt(char *rt)
{
  size_t str_size = strlen(rt);
  if(str_size > RDS_RT_LENGTH)
    str_size = RDS_RT_LENGTH;
  memset(this->string_rt, ' ', RDS_RT_LENGTH); // fill with spaces
  memcpy(this->string_rt, rt, str_size);
}

void RDS::rt(char *rt) // public
{
  new_rt(rt);
  send_rt();
}

void RDS::new_ps(char *ps)
{
  size_t str_size = strlen(ps);
  if(str_size > RDS_PS_LENGTH)
    str_size = RDS_PS_LENGTH;
  memset(this->string_ps, ' ', RDS_PS_LENGTH); // fill with spaces
  memcpy(this->string_ps, ps, str_size);
}

void RDS::ps(char *ps) // public
{
  new_ps(ps);
  send_ps();
}

void RDS::ta(uint8_t ta) // public
{
  this->signal_ta = ta;
  send_ps(); // PS block sends TA
}

void RDS::stereo(uint8_t stereo) // public
{
  this->signal_stereo = stereo;
  send_ps(); // PS block sends TA
}

// CT group will be written at 5th postion after PS group
// rdsmem should be 65 bytes long
void RDS::send_ct(void)
{
  int rds_mem_offset = (RDS_BITS_PER_GROUP/8) * 4; // after PS group
  uint8_t bit_buffer[RDS_BITS_PER_GROUP/8];

  binary_ct_group(bit_buffer);
  for(int j = 0; j < RDS_BITS_PER_GROUP/8; j++)
  {
    // this->rdsmem[rds_mem_offset++] = bit_buffer[j];
    msgbyte(rds_mem_offset++, bit_buffer[j]);
  }
}

// public
void RDS::ct(int16_t year, uint8_t mon, uint8_t mday, uint8_t hour, uint8_t min, int16_t gmtoff)
{
  this->tm_year = year-1900;
  this->tm_mon = mon;
  this->tm_mday = mday;
  this->tm_hour = hour;
  this->tm_min = min;
  this->tm_gmtoff = gmtoff; // local time to gmt offset in seconds
  send_ct();
}
