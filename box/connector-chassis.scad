// rupa u limu četvrtasta 15.5x15.5 - 16x16 mm
// debljina lima oko 1 mm
// neka konektor prođe 15x10 mm i raširi se na 16.5x10 mm
// neka širina za lim bude 2 mm

conus_d1=7; // small diameter of the conus
conus_d2=10; // large diameter of the conus
conus_h=7; // height of the conus


screw_hole=3.5;
screw_head_d1=6; // closer to top
screw_head_d2=0; // closer to screw
screw_head_h=3;
nut_d=5.65 * (2/sqrt(3));
nut_h=2.5;
nut_depth=1; // sunken depth
nut_d2=nut_d+0.4; // sunken enlarged space

slider_cut_clearance=1.1; // hex cut clearance
slider_y=conus_d1-2;
slider_x=16.0+2*slider_cut_clearance;
slider_z=conus_h;
slider_z2=2; // extra height
slider_y2=slider_y+slider_z2; // slider extra thick
slider_clearance=0.5;
slider_notch_x=0.7; // notch depth
slider_notch_z=1.5; // same as x
slider_notch_zoffset=-0.3;
slider_top_z=3;
slider_top_y=slider_y+slider_notch_z;

carrier_cube=[22,12,6];

connector_bottom_x=20; // 20 or 17
connector_bottom_y=12;
connector_bottom_z=12; // 9 or 12
connector_screw_x=25.4; // screw distance
connector_screw_d=2.4; // 1.8 for plastic 2.2 screw, 2.4 for DB9 spacer
connector_screw_depth=10;
connector_shell_thick=4;
connector_shell_x=31;
connector_shell_clearance=0.5;
connector_shell_clearance_slider_x=1.0;


cover_thick=2; // cover thickness
cover_clearance=0.7;
cover_cable_width=16;
cover_cable_z=15;

cover_inside_cut=[connector_shell_x,carrier_cube[1],carrier_cube[2]]+[0,0,connector_bottom_z+connector_shell_thick+9]+[1,1,1]*cover_clearance;

cover_box=cover_inside_cut+[1,1,0.5]*2*cover_thick;


module kajla_main(add_d=0)
{
        cylinder(d1=conus_d1+add_d, d2=conus_d2+add_d, h=conus_h, $fn=6, center=true);

}

module kajla(add_d=0)
{
  translate([0,0,conus_h/2])
  difference()
  {
    kajla_main(add_d=add_d);
    // hole
    cylinder(d=screw_hole,h=conus_h+0.001, $fn=16, center=true);
    // sunken depth for nut
    translate([0,0,conus_h/2-nut_depth/2])
      cylinder(d=nut_d2,h=nut_depth+0.01, $fn=6,center=true);
    // tight place for nut
    translate([0,0,conus_h/2-nut_depth/2-nut_h/2+0.01])
      cylinder(d=nut_d,h=nut_h, $fn=6,center=true);
  }
}

module slider_main(add_x=0, add=0)
{
  union()
  {
    cube([slider_x+add_x,slider_y+add,slider_z],center=true);
    // add enlarged part bottom
    translate([0,0,-slider_z/2+(slider_z2+add)/2])
      cube([slider_x+add_x,slider_y2+add,(slider_z2+add)],center=true);
    // add enlarged part on top
    // NEED print friendly cut 45 deg
    top_z=slider_top_z-0.001;
    if(1)
    translate([0,0,slider_z/2-(top_z)/2])
      cube([slider_x+add_x,slider_top_y,(top_z)],center=true);

  }
}

module slider()
{
  difference()
  {
    slider_main();
    kajla_main(add_d=slider_cut_clearance);
    // the notches (both sides in for loop)
    for(i=[-1:2:1])
      translate([(-slider_x/2+slider_notch_x/2)*i,0,-slider_z/2+2*slider_z2+slider_notch_z/2+slider_notch_zoffset])
        cube([slider_notch_x,slider_y2+0.01,slider_notch_z],center=true);
  }
}

module base()
{
  translate([0,0,-carrier_cube[2]/2+2*slider_z2-slider_clearance/2])
  difference()
  {
    cube(carrier_cube,center=true);
    // cut for slider
    translate([0,0,carrier_cube[2]/2+slider_z/2-2*slider_z2])
      slider_main(add_x=carrier_cube[0],add=slider_clearance);
    // cut for kajla
    translate([0,0,carrier_cube[2]/2+conus_h/2-2*slider_z2])
      kajla_main(add_d=slider_clearance);
    // cut for screw hole
    cylinder(d=screw_hole,h=carrier_cube[2]+0.01,$fn=16,center=true);
    // cut for screw head
    if(0)
    translate([0,0,-carrier_cube[2]/2+screw_head_h/2])
      cylinder(d1=screw_head_d1,d2=screw_head_d2,h=screw_head_h,$fn=16,center=true);
  }
}

module connector_shell()
{
 translate([0,0,slider_z/2-connector_shell_clearance/2-(connector_bottom_z+connector_shell_thick+carrier_cube[2])/2])
    difference()
    {
      shell_z=connector_bottom_z+connector_shell_thick+carrier_cube[2];
      cube([connector_shell_x,connector_bottom_y,shell_z],center=true);
      // cut for connector bottom
      translate([0,0,-shell_z/2+connector_bottom_z/2])
        cube([connector_bottom_x+connector_shell_clearance,connector_bottom_y,connector_bottom_z],center=true);
      // cut for slider holder
      translate([0,0,shell_z/2-carrier_cube[2]/2])
        cube(carrier_cube+[connector_shell_clearance_slider_x,0,connector_shell_clearance],center=true);
      // cut for screw hole
      cylinder(d=screw_hole,h=shell_z,$fn=16,center=true);
      // cuts for side screw
      for(i=[-1:2:1])
        translate([i*connector_screw_x/2,0,-shell_z/2+connector_screw_depth/2])
          cylinder(d=connector_screw_d,h=connector_screw_depth,$fn=16,center=true);
      // cut for screw head
      if(1)
      translate([0,0,-shell_z/2+connector_bottom_z+screw_head_h/2])
        cylinder(d1=screw_head_d1,d2=screw_head_d2,h=screw_head_h,$fn=16,center=true);
    }
}


module cover()
{
  translate([0,0,-12])
  difference()
  {
    cube(cover_box,center=true);
    // inside cut
    translate([0,0,cover_thick/2+0.01])
      cube(cover_inside_cut,center=true);
    // cable out cut
    translate([0,cover_box[1]/2-cover_thick/2,cover_box[2]/2-cover_cable_z/2])
      cube([cover_cable_width,cover_thick+0.02,cover_cable_z],center=true);
    if(0) // cross-section
    translate([0,50,0])
      cube([100,100,100],center=true);
  }
}


// connector-conus (hold)
if(1)
  kajla();
// connector-slider (hold)
if(1)
translate([0,0,slider_z/2])
  slider();

// conncetor-base
if(1)
  base();

// connector-shell
if(1)
  connector_shell();

if(0)
  cover();

