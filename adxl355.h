#ifndef ADXL355_H_
#define ADXL355_H_

/* ADXL355 registers addresses */

#define ADXL355_DEVID_AD         0x00
#define ADXL355_DEVID_MST        0x01
#define ADXL355_PARTID           0x02
#define ADXL355_REVID            0x03
#define ADXL355_STATUS           0x04
#define ADXL355_FIFO_ENTRIES     0x05
#define ADXL355_TEMP2            0x06
#define ADXL355_TEMP1            0x07
#define ADXL355_XDATA3           0x08
#define ADXL355_XDATA2           0x09
#define ADXL355_XDATA1           0x0A
#define ADXL355_YDATA3           0x0B
#define ADXL355_YDATA2           0x0C
#define ADXL355_YDATA1           0x0D
#define ADXL355_ZDATA3           0x0E
#define ADXL355_ZDATA2           0x0F
#define ADXL355_ZDATA1           0x10
#define ADXL355_FIFO_DATA        0x11
#define ADXL355_OFFSET_X_H       0x1E
#define ADXL355_OFFSET_X_L       0x1F
#define ADXL355_OFFSET_Y_H       0x20
#define ADXL355_OFFSET_Y_L       0x21
#define ADXL355_OFFSET_Z_H       0x22
#define ADXL355_OFFSET_Z_L       0x23
#define ADXL355_ACT_EN           0x24
#define ADXL355_ACT_THRESH_H     0x25
#define ADXL355_ACT_THRESH_L     0x26
#define ADXL355_ACT_COUNT        0x27
#define ADXL355_FILTER           0x28
#define ADXL355_FIFO_SAMPLES     0x29
#define ADXL355_INT_MAP          0x2A
#define ADXL355_SYNC             0x2B
#define ADXL355_RANGE            0x2C
#define ADXL355_POWER_CTL        0x2D
#define ADXL355_SELF_TEST        0x2E
#define ADXL355_RESET            0x2F

// integer intercept at 25 deg C
#define ADXL355_TEMP_AT_25C      1885
// scale factor Celsius per LSB
#define ADXL355_TEMP_SCALE       (-1/9.05)

#endif /* ADXL355_H_ */
