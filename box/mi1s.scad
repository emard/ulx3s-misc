stand_l=200; // length
stand_w=143; // width
stand_t=13.5;  // thickness

mudguard_w=40;
mudguard_t=5;

hold_l = stand_w+12; // 1mm space on each side
hold_w = 15;
hold_t = 4;
hold_holedist = 30*2.54; // pcb hole mount
hold_pcbside = 20; // move PCB on a side
hold_batside = -57;

bat_up = 43; // move bat up/down
bat_dim = [92,43,22.1]; // battery dimensions

bat_hold_t = 2; // thickness of bat holder
bat_hold_d = [40,40]; // depth of bat holder rear,front
bat_hold_back = [-7,-17]+(bat_hold_d-[18,40])/2; // move holder back: rear,front

bat_screw_d1 = 5;
bat_screw_d2 = 9;
bat_screw_h  = 3;
bat_screw_dist = 18; // distance between 2 screws

bat_clr = [0.5,0.5,0.5]; // from each side
bat_cut = [99,30,12]; // cut for connector
bat_btn_d = 28; // cut for button
bat_btn_x = 19; // position from edge

bat_charger_dim=[9,9]; // connector cut
bat_charger_pos=[15,-1]; // connector center position

hold_holes = [hold_pcbside-hold_holedist/2,hold_pcbside+hold_holedist/2, hold_batside+bat_screw_dist/2, hold_batside-bat_screw_dist/2]; // list of holes position relative to center

// bar
hold_sh  = 3.5; // spacer height
hold_sd1 = 5; // spacer diameter top
hold_sd2 = 7.5; // spacer diameter bot

// plate grips
grip_a = 3; // anti-rotate thick
grip_b = 5; // anti-rotate len
grip_w = hold_w+2*grip_a+0.4;
grip_w0 = 5;
grip_h = stand_t;
grip_l = 12;
grip_t = 5;

screw_hhead = 2.5;
screw_dhead = 5;
screw_thru  = 2.7;
screw_in    = 1.8;

mgrip_x  = 0; // position more back
mgrip_z  = 50; // position up grip

mgrip_d1 = 18.5; // mudguard grip dia
mgrip_d2 = 25; // mudguard grip dia
mgrip_h  = 11; // mudguard total height
mgrip_ht =5.5; // mudguard grip top height (hook thickness)
mgrip_depth = 11; // mudguard cut depth
mgrip_hspace = 5; // mudguard space
mgrip_angle = 22; // about 22 deg

mgrip_hold_t = 3; // mgrip holder thickness
mgrip_screw_depth = 8.5; // depth of 2 screws for mounting to the box
mgrip_hold_h = 11.5; // holder height
mgrip_hold_clr = 0.2; // mgrip holder clearance form each side
mgrip_hole_h = 8.4; // M3 tightening hole pos from top
mgrip_hole_x = 3.5; // move holes front
mgrip_hole_d = 3.5; // M3 thru dia

sensor_pcb  = [20.4,20.4,1.6]; // xyz pcb size
sensor_dist = 2.54*9;
sensor_clr  = [0.4, 0.4, 0.4]; // sensor xyz clearance in the box 0.2 - very tight
sensor_conn_dim = [12.5,6,55.5];

sensor_rail_w = 1; // sensor rail width
sensor_rail_z = -3; // sensor rail up/down

box_t = 2; // box wall thickness
box_x = -4; // move box x relative to holder
box_cover_screw_w = 6; // width of screw holder for the cover

mgrip_box_internal = [34,sensor_pcb[1]+sensor_dist+2*sensor_clr[1],16];

mgrip_box_dim = mgrip_box_internal+[box_t,box_t*2,box_t*2];

mgrip_screw_dist = 5; // screw holes distance for mgrip mounting
mgrip_screw_x = -5.5; // x-offset screw holes
mgrip_screw_h = 3; // screw depth

module stand()
{
  cube([stand_l,stand_w,stand_t], center=true);
  translate([stand_l/2,0,0])
    cylinder(d=stand_w,h=stand_t,center=true);
  translate([stand_l/2,0,stand_t/2+mudguard_t/2])
    cylinder(d=mudguard_w,h=mudguard_t,center=true);
}

module mgrip()
{
  dist = mgrip_d2-mgrip_d1;
  rotate([0,-mgrip_angle,0])
  difference()
  {
  union()
  {
  for(i=[-1:2:1])
    translate([-i*dist/2,0,0])
      cylinder(d=mgrip_d1,h=mgrip_h,$fn=24,center=true);
  cube([dist,mgrip_d1,mgrip_h],center=true);
  }
    // cut inside
    translate([-mgrip_d2+mgrip_depth,0,mgrip_h/2-mgrip_hspace/2-mgrip_ht])
      cube([mgrip_d2+0.01,mgrip_d1+0.01,mgrip_hspace],center=true);
  }
}

module battery()
{
  cube(bat_dim,center=true);
}

// j=0 no button opening
// j=1 button opening
module bat_holder(j)
{
  translate([bat_hold_back[j],0,0])
  difference()
  {
    union()
    {
      // outer shell
      cube([bat_hold_d[j]+bat_hold_t*2,bat_dim[1]+bat_hold_t*2,bat_dim[2]+bat_hold_t*2]+bat_clr*2,center=true);
      // screw mount
      for(i=[-1:2:1])
        translate([-bat_hold_back[j],-bat_dim[2]-bat_hold_t-bat_screw_h+0.01,i*bat_screw_dist/2])
        rotate([-90,0,0])
        cylinder(d1=bat_screw_d1,d2=bat_screw_d2,h=bat_screw_h,$fn=24);
    }
    // cut for battery fit
    translate([bat_dim[0]/2-bat_hold_d[j]/2,0,0])
    cube(bat_dim+bat_clr*2,center=true);
    // cut for connector
    translate([0,0,0])
      cube(bat_cut,center=true);
    // cut for charger
    if(j > 0.5) // only on front side
    translate([-bat_hold_d[j]/2+bat_charger_dim[0]/2+bat_charger_pos[0],bat_dim[1]/2,bat_charger_pos[1]])
    {
      cube([bat_charger_dim[0],bat_dim[1]/2,bat_charger_dim[1]],center=true);
      // print-friendly circles
      for(k=[-1:2:1])
      translate([k*bat_charger_dim[0]/2,0,0])
        rotate([90,0,0])
          cylinder(d=bat_charger_dim[1],h=bat_dim[1]/2,$fn=12,center=true);
    }
    // cut for screw
    for(i=[-1:2:1])
      translate([-bat_hold_back[j],-bat_dim[1]/2,i*bat_screw_dist/2])
      rotate([-90,0,0])
        cylinder(d=screw_in,h=bat_dim[1]/2,$fn=12,center=true);
    // cut for button
    translate([bat_btn_x-bat_hold_d[j]/2,0,-j*bat_dim[2]/2])
    {
      // circular
      rotate([0,0,0])
        cylinder(d=bat_btn_d,h=bat_hold_t*5,$fn=48,center=true);
      // straight
      translate([bat_btn_d/2,0,0])
        cube([bat_btn_d,bat_btn_d,bat_hold_t*5],center=true);
    }
  }
}

module holder_grip()
{
  difference()
  {
  union()
  {
  cube([grip_w, grip_w0, grip_h],center=true);
  translate([0,grip_w0/2-grip_l/2,-grip_h/2-grip_t/2])
    cube([grip_w,grip_l,grip_t],center=true);
  translate([grip_w/2-grip_a/2,grip_w0/2-grip_b/2,grip_h/2+hold_t/2])
    cube([grip_a,grip_b,hold_t],center=true);
  translate([-grip_w/2+grip_a/2,grip_w0/2-grip_b/2,grip_h/2+hold_t/2])
    cube([grip_a,grip_b,hold_t],center=true);
  }
  cylinder(d=screw_in,h=grip_h*10,$fn=12,center=true);
  }
}

module spacer(h)
{
  difference()
  {
    cylinder(d=6,h=h,$fn=12,center=true);
    cylinder(d=screw_thru,h=h+0.01,$fn=12,center=true);
  }
}

module holder_bar()
{
  difference()
  {
    union()
    {
      cube([hold_w,hold_l,hold_t],  center=true);
      // reinforcement spacers
        for(i=[0:1:3])
          translate([0,hold_holes[i],hold_t/2+hold_sh/2])
        cylinder(d2=hold_sd1,d1=hold_sd2,h=hold_sh,$fn=24,center=true);
            //cube([hold_w,hold_w,hold_t], center=true);
    }
    // grip holes
    for(i=[-1:2:1])
    translate([0,i*(hold_l/2-grip_w0/2),0])
      cylinder(d=screw_thru,h=hold_t*2,$fn=12,center=true);
    // pcb holes
    
    for(i=[0:1:3])
    translate([0,hold_holes[i],0])
    {
      // main hole
      cylinder(d=screw_thru,h=hold_t*10,$fn=12,center=true  );
      // head space
      translate([0,0,-hold_t/2+screw_hhead/2])
        cylinder(d=screw_dhead,h=screw_hhead+0.01,$fn=12,center=true);
      // conical transition
      translate([0,0,-hold_t/2+screw_hhead])
       cylinder(d1=screw_dhead,d2=0,h=screw_dhead*0.7+0.01,$fn=12,center=false);
    }
  }
}

module mgrip_holder()
{
  dist = mgrip_d2-mgrip_d1;
  add_h = tan(mgrip_angle)*(mgrip_d2+mgrip_hold_t*2+mgrip_hold_clr*2);
  // sensors box
  difference()
  {
  union()
  {
  rotate([0,-mgrip_angle,0])
    difference()
    {
      if(1)
      union()
      {
        for(i=[-1:2:1])
        translate([i*dist/2,0,add_h/2])
        cylinder(d=mgrip_d1+2*mgrip_hold_clr+2*mgrip_hold_t,h=mgrip_hold_h+add_h,center=true);
        translate([0,0,add_h/2])
        cube([dist,mgrip_d1+2*mgrip_hold_clr+2*mgrip_hold_t,mgrip_hold_h+add_h],center=true);
      }
      // internal cut
      for(i=[-1:2:1])
        translate([i*dist/2,0,0])
          cylinder(d=mgrip_d1+2*mgrip_hold_clr,h=mgrip_hold_h+0.01,center=true);
      cube([dist,mgrip_d1+2*mgrip_hold_clr,mgrip_hold_h+0.01],center=true);
      // scew holes
      translate([-mgrip_hole_x,0,mgrip_hold_h/2-mgrip_hole_h])
        rotate([90,0,0])
          cylinder(d=mgrip_hole_d,h=100,$fn=12,center=true);
    }
  }
    // screws cut
    for(i=[-1:2:1])
      translate([mgrip_screw_x,i*mgrip_screw_dist,0])
      {
        // thru hole
        cylinder(d=screw_thru,h=100,$fn=12,center=true);
        // head
        translate([0,0,mgrip_screw_depth])
        {
        rotate([180,0,0])
        {
        cylinder(d2=screw_dhead,d1=0,h=(screw_dhead)/2,$fn=12, center=false);
        translate([0,0,screw_dhead/2-0.01])
        cylinder(d=screw_dhead,h=10,$fn=12,center=false);
        }
        }
      }
    // box cut
    translate([0,0,mgrip_box_dim[2]/2+mgrip_hold_h/2+sin(mgrip_angle)*mgrip_d2/2])
    cube(mgrip_box_dim+[10,10,0],center=true);
  }
}

module mgrip_box()
{
  dist = mgrip_d2-mgrip_d1;
  add_h = tan(mgrip_angle)*(mgrip_d2+mgrip_hold_t*2+mgrip_hold_clr*2);
  box_translate = [box_x,0,mgrip_box_dim[2]/2+mgrip_hold_h/2+sin(mgrip_angle)*mgrip_d2/2];
  //cover_screw_translate = [0,i*(mgrip_box_dim[1]/2),-mgrip_box_dim[2]/2+box_cover_screw_w/2];
  // sensors box
  difference()
  {
    translate(box_translate)
    {
      cube(mgrip_box_dim,center=true);
      // side screw mounts
      for(i=[-1:2:1])
      translate([0,i*(mgrip_box_dim[1]/2+box_t/2),-mgrip_box_dim[2]/2+box_cover_screw_w/2])
      difference()
      {
        cube([mgrip_box_dim[0],box_cover_screw_w,box_cover_screw_w],center=true);
        // angular cuts for print friendly
        translate([10,0,0])
        rotate([0,0,-i*45])
          cube([100,18,18],center=true);
        // holes for screws
        //rotate([0,90,0])
        //cylinder(d=screw_in,h=100,$fn=12,center=true);
      }
    }
    // box interior
    translate(box_translate+[-box_t,0,0])
      cube(mgrip_box_internal+[0,0,0],center=true);
    // screws cut
    for(i=[-1:2:1])
      translate([mgrip_screw_x,i*mgrip_screw_dist,mgrip_box_dim[2]/2])
        // thru hole
        cylinder(d=screw_in,h=mgrip_box_dim[2],$fn=12,center=true);
    // connector out cut
    translate(box_translate+[-15,20,2.5 ])
      cube([15,10,9],center=true);
    // cable out cut
    translate(box_translate+[-17.5,0,9])
      cube([1.01,100,5],center=true);
    // cut for cover screws
    for(i=[-1:2:1])
      translate(box_translate+[0,i*(mgrip_box_dim[1]/2+box_t/2),-mgrip_box_dim[2]/2+box_cover_screw_w/2])
        // holes for screws
        rotate([0,90,0])
        cylinder(d=screw_in,h=100,$fn=12,center=true);

  }
  translate(box_translate)
    {
      inx = 5; // todo find parameters
      // wall between sensors
      translate([inx,0,0])
        cube([sensor_pcb[0],sensor_dist-sensor_pcb[1]-2*sensor_clr[1],mgrip_box_dim[2]],center=true);
      for(i=[-1:2:1]) // left/right sensor
      // rails for pcb
      for(j=[-1:2:1]) // left/right edges
      for(k=[-1:2:1]) // up/down edges
      translate([inx,i*sensor_dist/2+j*(sensor_pcb[1]+2*sensor_clr[1]-1*sensor_rail_w)/2,sensor_rail_z+k*(sensor_pcb[2]+sensor_rail_w+2*sensor_clr[2])/2])
        cube([sensor_pcb[0],sensor_rail_w,sensor_rail_w],center=true);
    }
}

module mgrip_box_cover()
{
  dist = mgrip_d2-mgrip_d1;
  add_h = tan(mgrip_angle)*(mgrip_d2+mgrip_hold_t*2+mgrip_hold_clr*2);
  box_translate = [box_x,0,mgrip_box_dim[2]/2+mgrip_hold_h/2+sin(mgrip_angle)*mgrip_d2/2];

    translate(box_translate+[-22,0,0])
    {
      cube([box_t,mgrip_box_dim[1],mgrip_box_dim[2]],center=true);
      for(i=[-1:2:1])
        translate([0,i*(mgrip_box_dim[1]+box_t)/2,-mgrip_box_dim[2]/2+box_cover_screw_w/2])
          difference()
          {
            cube([box_t,box_cover_screw_w,box_cover_screw_w],center=true);
            rotate([0,90,0])
              cylinder(d=screw_thru,h=100,$fn=12,center=true);
          }
    }
}


module sensors()
{
  for(i = [-1:2:1])
    translate([0,i*sensor_dist/2,0])
      cube(sensor_pcb,center=true);
}

module assembly()
{
  %stand();
  translate([37,hold_batside,bat_up])
    rotate([90,0,0])
    %battery();
  translate([stand_l/2+mgrip_x,0,mgrip_z])
    %mgrip();
  translate([stand_l/2+mgrip_x,0,mgrip_z]+[2,0,17.5])
    %sensors();
  translate([stand_l/2+mgrip_x,0,mgrip_z])
    {
      mgrip_holder();
      mgrip_box();
    }
  translate([0,0,stand_t/2+hold_t/2])
  {
    holder_bar();
    translate([0,hold_l/2-grip_w0/2,-hold_t/2-grip_h/2])
      holder_grip();
    translate([0,-hold_l/2+grip_w0/2,-hold_t/2-grip_h/2])
      rotate([0,0,180])
        holder_grip();
  }
  // battery holder
  translate([0,hold_batside,bat_up])
    rotate([90,0,0])
    bat_holder(0);
}

module print_bar()
{
  holder_bar();
}

module print_grip()
{
  rotate([-90,0,0])
  holder_grip();
}

module print_bat(j)
{
  rotate([0,-90,0])
    bat_holder(j);
}

module print_box_holder()
{
  rotate([180,0,0])
  mgrip_holder();
}

module print_box()
{
  rotate([0,90,0])
    mgrip_box();
}

module print_box_cover()
{
  rotate([0,90,0])
    mgrip_box_cover();
}

assembly();
//print_bar();
//print_grip();
//print_bat(0); // batt_rear
//print_bat(1); // batt_front
//print_box_holder();
//print_box();
//print_box_cover();
//spacer(2);

// some debug assys
//mgrip_box();
//mgrip_box_cover();
//mgrip_holder();

// check angle
//if(0)
//difference()
//{
//  mgrip_box();
//  translate([0,50,0])
//    cube([100,100,100],center=true);
//}

