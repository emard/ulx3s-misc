include <center.scad>
include <sensor_adxl355.scad>
include <connector14p.scad>

// main outer dimensions
// clearance: 0.5: normal, 1.0: outside epoxy coating
clearance=1.0;
width=47.1-clearance;
height=55.0-clearance;
depth=39;
curvature_r=15;
thick=2; // wall thickness
over=3; // dihtung
diht_h=7; // dubinska veličima vijenca dihtunga
stop_over=thick;
stop_h=2*thick;

// PCB mount pads
mount_width=27; // hole center distance
mount_height=37; // hole center distance
mount_pad_h=4;
mount_pad_d=8;
mount_pad_hole=1.8;

// PCB mount rails
sensor_pcb  = [20.4,20.4,1.6]; // xyz pcb size ADXL355
sensor_rail_clr = [0.4,0,0.2];
sensor_rail_dim = [6,20]; // sensor rail d,h

// cover mount pads
cover_mtpad_width=width-(curvature_r+2*thick)/sqrt(2);
cover_mtpad_height=height-(curvature_r+2*thick)/sqrt(2);
cover_mtpad_h=12;
cover_mtpad_d=6;
cover_mtpad_hole=1.8;
cover_mtpad_hole_depth=5;
cover_hole=2.5;
cover_side_clearance=0.5; // from sides
cover_depth_clearance=0.4; // from top
cover_thick=4;

cable_width=12*1.27; // na poklopcu, širina kabla
cable_pass=9; // na poklopcu
cable_thick=1;

magnet_d=10;
magnet_d_clearance=0.5;
magnet_gore=2; // pomak od sredine prema gore

slider_y=8;
slider_z=4;
slider_depth=1.5; // how much deep under
slider_over=2; // enlarge slider's x-width
slider_cutover=1; // linear rail y-size for opening on top of slider

slider_clearance=0.6;

kajla_d1=slider_y*sqrt(2);
kajla_d2=kajla_d1+2;
kajla_h=slider_z+slider_depth;
kajla_hole=3.5; // 3.0 for 2.2 mm plastic screw, 3.5 for M3 screw

chep_d=12;
chep_screw_depth=chep_d-1;
chep_screw_hole=3.5; // 1.8 for 2.2mm plastic screw, 3.5 for M3 screw
chep_nut_d=5.65 * (2/sqrt(3)); // nut tight hex
chep_nut_depth=3.5; // total depth
chep_nut_ins_d=chep_nut_d+0.4; // enlarged insertion hex
chep_nut_ins_depth=1; // insertion depth
chep_nut_transition_depth=3; // easier 3D print, conical transition

module rounded_cube(v,r)
{
  minkowski()
  {
    h_minkowski=0.01;
    cube(v-[2*r,2*r,h_minkowski],center=true);
    cylinder(h=h_minkowski,r=r,$fn=90,center=true);
  };
}


// kutija sa zaobljenim kutevima
module kutija(strana=1,d=12)
{
      union()
      {
        if(1)
        difference()
        { // zaobljena kvadratična cijev
          union()
          {
            rounded_cube([width,height,depth],curvature_r);
            // the stopper not to enter too deep
            side=strana; // 1:left -1:right
            if(1)
            difference()
            {
              translate([side*(width/2-curvature_r),-height/2+curvature_r,depth/2-stop_h/2-0.001])
                cylinder(r2=curvature_r+over,r1=curvature_r,h=stop_h,center=true);
              // outer width cut
              if(1)
              translate([side*1.5*width,0,0])
                cube([2*width-0.001,2*height,2*depth],center=true);
            }
          }
          // izdubljena unutrašnjost
          rounded_cube([width-2*thick,height-2*thick,depth+0.01],curvature_r-thick);
          // cable, rez za izlaz kabla van
          translate([0,height/2-thick+thick/2-0.02,depth/2-thick/2])
            cube([cable_width,thick+0.2,thick+0.001],center=true);

        }
        // dno, stražnja strana
        if(1)
        translate([0,0,-depth/2-thick/2+0.01])
          rounded_cube([width+0*over,height+0*over,thick],curvature_r);
        // nogice za šarafe PCB-a
        if(0)
        for(i = [-1:2:1])
        for(j = [-1:2:1])
        translate([i*mount_width/2,j*mount_height/2,-depth/2-0.01])
          difference()
          {
            cylinder(d=mount_pad_d,h=mount_pad_h,center=false);
            cylinder(d=mount_pad_hole,h=mount_pad_h+0.01,center=false);
          }
        // PCB holder rails
        if(1)
        {
          //color([0.8,0.2,0.2]) // red
          for(i=[-1,1])
          translate([-i*(sensor_pcb[0]-sensor_rail_clr[0])/2,0,-depth/2+sensor_pcb[1]/2])
          {
            difference()
            {
              union()
              {
                cylinder(d=sensor_rail_dim[0],h=sensor_rail_dim[1],$fn=4,center=true);
                // up-down reinforcement
                cube([thick,height-thick,sensor_rail_dim[1]],center=true);
                // side reinforcement
                translate([-i*(width-thick-sensor_pcb[0])/4,0,0])
                cube([(width-thick-sensor_pcb[0])/2,thick,sensor_rail_dim[1]],center=true);
              }
              translate([i*(sensor_pcb[0]-sensor_rail_clr[0])/2,0,0])
                rotate([90,0,0])
                  cube(sensor_pcb+sensor_rail_clr, center=true);
            }
            //cube([thick,height,10],center=true);
          }
        }
        // vijenac za dihtung poklopca
        // problem fixme: incomplete manifold
        if(1)
        translate([0,0,depth/2-thick-diht_h/2])
          difference()
          {
            rounded_cube([width,height,diht_h],curvature_r);
            rounded_cube([width-4*over,height-4*over,diht_h+0.01],curvature_r-2*over);
            // screw holes
            for(i = [-1:2:1])
            for(j = [-1:2:1])
            {
              // screw hole (must be done again to the pads at the same position)
              translate([i*cover_mtpad_width/2,j*cover_mtpad_height/2,0])
                cylinder(d=cover_mtpad_hole,h=diht_h+0.02,center=true);
            }
            for(i = [-1:2:1])
            {
              // dihtung: print-friendly angular cuts
              translate([i*(width-thick-5*over)/2,0,-diht_h*0.5])
                rotate([0,45,0])
                  cube([3*over,cover_mtpad_height-cover_mtpad_d*0.3,3*over],center=true);
              translate([0,i*(height-thick-5*over)/2,-diht_h*0.5])
                rotate([45,0,0])
                  cube([cover_mtpad_width-cover_mtpad_d*0.3,3*over,3*over],center=true);

            }
          }
        // nogice za šarafe poklopca
        if(1)
        for(i = [-1:2:1])
        for(j = [-1:2:1])
        translate([i*cover_mtpad_width/2,j*cover_mtpad_height/2,depth/2-cover_mtpad_h-thick])
          difference()
          {
            // pad
            cylinder(d=cover_mtpad_d,h=cover_mtpad_h,center=false);
            // screw hole
            translate([0,0,cover_mtpad_h-cover_mtpad_hole_depth+0.01])
              cylinder(d=cover_mtpad_hole,h=cover_mtpad_hole_depth,center=false);
            // print friendly angular cut
            translate([-i*cover_mtpad_d*0.8,-j*cover_mtpad_d*0.8,0])
            rotate([0,0,i*j*45])
            rotate([0,1*45,0])
              cube([2*cover_mtpad_d,2*cover_mtpad_d,2*cover_mtpad_d],center=true);
          }
      }
}

module poklopac()
{
      // poklopac (samo dio za zaustavi prolaz)
      translate([0,0,depth/2-thick+cover_thick/2])
        difference()
        {
          // ploča poklopca
          union()
          {
            rounded_cube([width-2*thick-cover_side_clearance,height-2*thick-cover_side_clearance,cover_thick],curvature_r-thick-cover_side_clearance/2);
            // zub preko
            translate([0,0,cover_thick/2-(cover_thick-thick-cover_depth_clearance)/2])
              difference()
              {
                rounded_cube([width-cover_side_clearance,height-cover_side_clearance,cover_thick-thick-cover_depth_clearance],curvature_r-cover_side_clearance/2);
                // cable, rez za izlaz kabla van
                translate([0,height/2-thick+thick/2-0.1,0])
                  cube([cable_width,thick+0.2,thick+0.001],center=true);
              }
              // držač za skidanje s printera
              drzac_h=10;
              if(0)
              translate([0,-height/2+thick*2+over+drzac_h/2,-thick-drzac_h/2])
              difference()
              {
                cube([drzac_h*2,drzac_h,drzac_h],center=true);
                rotate([0,90,0])
                  cylinder(d=drzac_h/2,h=drzac_h*2+0.01,center=true);
              }
          }
          // rupe za šarafe
          for(i = [-1:2:1])
            for(j = [-1:2:1])
            {
              // screw hole (must be done again to the pads at the same position)
              translate([i*cover_mtpad_width/2,j*cover_mtpad_height/2,0])
                cylinder(d=cover_hole,h=cover_thick+0.01,$fn=10,center=true);
            }
          // cable, rez ispod poklopca
          translate([0,height/2-cable_pass/2,-cover_thick/2+cable_thick/2-0.01])
            cube([cable_width,cable_pass,cable_thick],center=true);
          // cable, rez za izlaz kabla van
          if(0)
          translate([0,-height/2+thick+cable_thick/2,0])
            cube([cable_width,cable_thick+0.01,thick+0.01],center=true);
        }
}

module magnet()
{
  if(0) // postavljen maget da se vidi kako stane
  translate([0,magnet_gore,depth/2+magnet_d/2+cover_thick-thick+thick*0])
    rotate([0,90,0])
      cylinder(d=10,h=width-clearance,center=true);
  translate([0,magnet_gore,depth/2+magnet_d/2+cover_thick-thick+thick/2])
  difference()
  {
    union()
    {
        // kocka koja sardrži magnet
        cube([width-clearance,magnet_d+2*thick+2*magnet_d_clearance,magnet_d+thick+magnet_d_clearance],center=true);
        // kocka za izvlačenje
        translate([0,-(magnet_d+2*thick+2*magnet_d_clearance)/2-magnet_d/2,0])
          cube([4*thick,magnet_d,magnet_d+thick+magnet_d_clearance],center=true);
        // podloga
        translate([0,-magnet_gore,-(magnet_d+thick+magnet_d_clearance)/2+thick/2])
          difference()
          {
            rounded_cube([width-cover_side_clearance,height-cover_side_clearance,thick],curvature_r-cover_side_clearance/2);
            // cable, rez za izlaz kabla van
            translate([0,height/2-thick+thick/2-0.1,0])
              cube([cable_width,thick+0.2,thick+0.001],center=true);
          }
    }
    // izrezana rupa za magnet
    translate([0,0,-thick/2])
    rotate([0,90,0])
      union()
      {
        // rupa za magnet
        cylinder(d=magnet_d+magnet_d_clearance,h=width-clearance+0.01,center=true);
        // print-friendly rez do kraja
        if(1)
        translate([(magnet_d+magnet_d_clearance)/2,0,0])
          cube([
          magnet_d+magnet_d_clearance,
          magnet_d+magnet_d_clearance,
          width-clearance+0.01,
          ],center=true);
      }
    // rupe za šarafe
          for(i = [-1:2:1])
            for(j = [-1:2:1])
            {
    // screw hole (must be done again to the pads at the same position)
              translate([i*cover_mtpad_width/2,j*cover_mtpad_height/2-magnet_gore,-(magnet_d+thick+magnet_d_clearance)/2+thick/2])
                cylinder(d=cover_hole,h=thick+0.01,$fn=10,center=true);
            }
            // rupa za izvlačenje
            translate([0,-(magnet_d+2*thick+2*magnet_d_clearance)/2-magnet_d/2,thick/2])
              rotate([0,90,0])
                    cylinder(d=6,h=4*thick+0.01,center=true);

  }
}

module slider_rod(add=0)
{
    
    cube([width+add+slider_over,slider_y+add,slider_z+add],center=true);
    
}

module kajla(add=0)
{
    intersection()
    {
      rotate([0,0,45])
          cylinder(d1=kajla_d1+add,d2=kajla_d2+add,h=kajla_h+add,$fn=4,center=true);
      // side intersect limits to redice y-size to that of the slider
      cube([width,slider_y+add,kajla_h+add],center=true);
    }
}

module chep(strana=1,kocka=0,kosina=1)
{
  d=chep_d;
  translate([0,0,depth/2+d/2+thick+clearance])
  difference()
  {
    union()
    {
      rounded_cube([width,height,d],curvature_r);
      // kocka za izvlačenje
      if(kocka>0.5)
      translate([0,-14,d])
        difference()
        {
          cube([1.5*d,d,d],center=true);
          rotate([0,90,0])
            cylinder(d=d/2,h=1.5*d+0.1,$fn=16,center=true);
        }
    }
    // cable, rez za izlaz kabla van
    translate([0,height/2-thick+thick/2-0.1,0])
      cube([cable_width,thick+0.2,d+0.001],center=true);
    // kosina za šaraf
    if(kosina>0.5)
    translate([-strana*cable_width/2,-(height/2+thick/4-0.1),0])
      rotate([-10,0,0])
        cube([cable_width,thick+0.2,2*d+0.001],center=true);
    // rebra za lakše skidanje
    nlines2=floor(width/thick/4);
    for(i=[-nlines2:nlines2])
      translate([i*thick*2,0,-d/2+cover_depth_clearance/2])
        cube([thick,height,cover_depth_clearance+0.01],center=true);
    // rupa za slider
    translate([0,0,d/2-slider_z/2-slider_depth])
      slider_rod(add=slider_clearance);
    kajla_add=slider_clearance;
    translate([0,0,d/2-kajla_h/2+0.001])
      kajla(add=slider_clearance);
    // rupa za šaraf slidera
    translate([0,0,d/2-chep_screw_depth/2])
      cylinder(d=chep_screw_hole,h=chep_screw_depth+0.01,$fn=16,center=true);
    // skinut gornji sloj iznad slidera
    // radi lakšeg printanja
    translate([0,0,slider_y/2+0.001])
      cube([width+0.01,slider_y-slider_cutover,slider_z],center=true);
    // duboki tijesni utor za maticu
    translate([0,0,-d/2+chep_nut_depth/2-0.001])
      cylinder(d=chep_nut_d,h=chep_nut_depth,$fn=6,center=true);
    // plitki labavi utor za maticu
    translate([0,0,-d/2+chep_nut_ins_depth/2-0.001])
      cylinder(d=chep_nut_ins_d,h=chep_nut_ins_depth,$fn=6,center=true);
    // konusni prijelaz za lakše printanje
    if(1)
    translate([0,0,-d/2+chep_nut_depth+chep_nut_transition_depth/2-0.001])
      cylinder(d1=chep_nut_d,d2=0,h=chep_nut_transition_depth+0.005,$fn=6,center=true);

  }
}

module slider()
{
    translate([0,0,depth/2+chep_d/2+thick+clearance+chep_d/2-slider_z/2-slider_depth])
    {
      difference()
      {
        union()
        {
          slider_rod(add=0);
          // notches for easier removal
          if(1)
          for(i=[-1:2:1])
          translate([i*(width/2-slider_y/2),0,slider_z/2+slider_z/8])
            cube([slider_y,slider_y/2,slider_z/4],$fn=16,center=true);
        }
        // cut space for kajla
        slider_kajla_clearance=slider_clearance;
        translate([0,0,-slider_z/2+kajla_h/2+slider_kajla_clearance/2-0.01])
        kajla(add=slider_kajla_clearance);
        // holes for easier removal
        if(0)
        for(i=[-1:2:1])
          translate([i*width/4,0,0])
            cylinder(d=3,h=slider_z,$fn=16,center=true);
      }
      // place kajla
      translate([0,0,-slider_z/2+kajla_h/2])
      difference()
      {
        kajla();
        // central screw hole
        cylinder(d=kajla_hole,h=kajla_h+0.01,$fn=16,center=true);
      }
  }
}


module kutijica(kutija=1, poklopac=1, magnet=0, slider=0, chep=1, strana=1)
{
  union()
  {
    // zaobljeni dio četvrtaste cijevi
    if(kutija > 0.5)
      kutija(strana);
    if(poklopac > 0.5)
      poklopac();
    if(magnet > 0.5)
      magnet();
    if(chep > 0.5)
      chep(strana=strana);
    if(slider > 0.5)
        slider();
  }
}

pos_connector = [1.27,3.5,10];
%translate(pos_connector)
  connector14p();

module connector_holder()
{
  dim_conn_inner = [23,6.5,10];
  dim_conn_outer = dim_conn_inner+[4,4,-0.01];
  translate(pos_connector)
  {
    difference()
    {
      box(dim_conn_outer);
      // inside cut
      box(dim_conn_inner);
      // notch cut
      translate([0,dim_conn_inner[1]/2,3])
        box([5,4,10]);
    };
    // fit for pcb holder rails
    //translate([0,dim_conn_outer[1]/2-1,-7])
      difference()
      {
        union()
        {
          // top
          translate([0,dim_conn_outer[1]/2-1,-7])
            box([dim_conn_outer[0],2,5]);
          // bottom
          translate([0,-dim_conn_outer[1]/2-2,-7])
            box([dim_conn_outer[0],2,5]);
         for(i=[-1,1])
           translate([i*12.5,-1.5,-7])
             box([2,13,5]);
        }
        // cut for rails
        for(i=[-1,1])
          translate([-1.3+i*10,0,-7])
            box([2.5,40,10]);
      }
  }
}

if(1)
translate([0,0,-4.5])
connector_holder();

// kutija 1:generirat 0:ne
// poklopac 1:generirat 0:ne
// strana: -1:lijeva 1:desna
// chep: 1:generiraj 0:ne
difference()
{
if(1)
kutijica(kutija=1,poklopac=0,magnet=0,chep=0,slider=0,strana=1);
translate([0,0,-depth/2+sensor_pcb[1]/2])
  rotate([-90,0,0])
    %sensor_adxl355();
if(0)
translate([50,0,0])
    cube([100,100,100],center=true);
}
