include <center.scad>

module connector14p()
{
  dim_conn_base=[22.5,6,10.5];
  dim_conn_notch=[3.9,0.9,6.9];
  hole_depth=8;
  difference()
  {
    box(dim_conn_base);
    // pin holes
    translate([0,0,-dim_conn_base[2]/2])
    for(i=[-3,-2,-1,0,1,2,3])
     for(j=[-0.5,0.5])
       translate([i*2.54,j*2.54,0])
         box([0.5,0.5,2*hole_depth]);
    // flatcable opening
    translate([0,0,dim_conn_base[2]/2-3])
      box([14*1.27,20,1.27]);
  }
  // alignment notch
  translate([0,dim_conn_base[1]/2+dim_conn_notch[1]/2,-dim_conn_base[2]/2+dim_conn_notch[2]/2])
    box(dim_conn_notch);
  // cable holder
  translate([0,0,7])
  {
    translate([0,0,1.5])
      box([18,3,4]);
    // side blocks
    for(i=[-1,1])
      translate([i*10.25,0,0])
        box([2,6,4]);
  }
}
