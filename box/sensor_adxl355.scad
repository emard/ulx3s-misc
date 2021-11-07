module sensor_adxl355()
{
  sensor_pcb  = [20.4,20.4,1.6]; // xyz pcb size ADXL355
  pins_plastic = [15.2,2,5.3]; // plastic pins holder
  raster = 2.54; // standard raster, don't touch this
  pins_h = 1.6/2+2.7; // pins center height above pcb plane center
  pins_l = 8.5; // pins active length total
  pins_depth = 0; // pins depth inside of sensor (pins plastic bar front pos)
  pins_t = 0.5; // pin thickness of square side
  // PCB
  cube(sensor_pcb, center=true);
  // pins holder
  translate([0,-sensor_pcb[1]/2+pins_depth+pins_plastic[1]/2,pins_plastic[2]/2+sensor_pcb[2]/2])
    cube(pins_plastic, center=true);
  // pins array
  for(i = [-0.5,0.5])
    for(j = [-2.5,-1.5,-0.5, 0.5, 1.5, 2.5])
      translate([j*raster,-sensor_pcb[1]/2-pins_l/2+pins_depth,pins_h+i*raster])
        cube([pins_t,pins_l,pins_t],center=true);    
}
