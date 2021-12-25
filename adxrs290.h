/*
 * ADXRS290Reg.h
 *
 * Created: 05/06/2016 14:17:29
 *  Author: searobin
 */

#ifndef ADXRS290_REG_H_
#define ADXRS290_REG_H_

/* Gyroscope */
#define ADXRS290_ANALOG_ID         0x00
#define ADXRS290_ANALOG_ID_DEFAULT 0xAD

#define ADXRS290_MEMS_ID           0x01
#define ADXRS290_MEMS_ID_DEFAULT   0x1D

#define ADXRS290_DEV_ID            0x02
#define ADXRS290_DEV_ID_DEFAULT    0x92

#define ADXRS290_REV_NUM           0x03
#define ADXRS290_REV_NUM_DEFAULT   0x1D

#define ADXRS290_SERIALNUM_L       0x04
#define ADXRS290_SERIALNUM_H       0x07

// 16 2-complement's bits
#define ADXRS290_GYRO_XL           0x08
#define ADXRS290_GYRO_XH           0x09

// 16 2-complement's bits
#define ADXRS290_GYRO_YL           0x0A
#define ADXRS290_GYRO_YH           0x0B

// 12 2-complement's bits
#define ADXRS290_TEMP_L            0x0C  //  7..0 bits
#define ADXRS290_TEMP_H            0x0D  // 11..8 bits
#define ADXRS290_TEMP_SCALE         0.1  // deg C / LSB, 0 means 0 deg C.

#define ADXRS290_POWER_CTL         0x10
// Thermometer bit : 1 enable, 0 disable
#define ADXRS290_POWER_TEMP        0x01
// Gyroscope   bit : 2 enable, 0 disable
#define ADXRS290_POWER_GYRO        0x02

#define ADXRS290_FILTER   0x11
#define ADXRS290_FILTER_LPF_MASK     0x07
#define ADXRS290_FILTER_HPF_MASK     0xF0
#define ADXRS290_FILTER_HPF_OFFSET   0x4

#define ADXRS290_DATA_READY        0x12

/* Set this bit to get triggered on data ready via interrupt
 * Set bit to 01 to gen rata ready interrupt
 * at the sync/asel pin when data becomes avail
 * Sync bits meaning:
 * X0 = Read for analog enable
 * 01 Data ready, high until read
 */
#define ADXRS290_DATA_READY_INT_MASK 0x03

/*Sensors Sensitivity */

/*
 * Low-Pass Filter Pole Locations
 *  The data is the Frequency in Hz
 */
#define ADXRS_LPF_480_HZ          0x00   //  480_Hz is Default
#define ADXRS_LPF_320_HZ          0x01   //  320_Hz
#define ADXRS_LPF_160_HZ          0x02   //  160_Hz
#define ADXRS_LPF_80_HZ           0x03   //   80_Hz
#define ADXRS_LPF_56_6_HZ         0x04   //   56.6_Hz
#define ADXRS_LPF_40_HZ           0x05   //   40 Hz
#define ADXRS_LPF_28_3_HZ         0x06   //   28.3_Hz
#define ADXRS_LPF_20_HZ           0x07   //   20_Hz

/*
 * High-Pass Filter Pole Locations
 *  The data is the Frequency in Hz
 */
#define ADXRS_HPF_ALL_HZ          0x00   // All Pass Default
#define ADXRS_HPF_0_011_HZ        0x01   //  0.011_Hz
#define ADXRS_HPF_0_022_HZ        0x02   //  0.022_Hz
#define ADXRS_HPF_0_044_HZ        0x03   //  0.044_Hz  
#define ADXRS_HPF_0_087_HZ        0x04   //  0.087_Hz  
#define ADXRS_HPF_0_175_HZ        0x05   //  0.187_Hz   
#define ADXRS_HPF_0_350_HZ        0x06   //  0.350_Hz
#define ADXRS_HPF_0_700_HZ        0x07   //  0.700_Hz
#define ADXRS_HPF_1_400_HZ        0x08   //  1.400_Hz 
#define ADXRS_HPF_2_800_HZ        0x09   //  2.800_Hz 
#define ADXRS_HPF_11_30_HZ        0x0A   // 11.300_Hz 

#endif /* ADXRS290_H_ */
