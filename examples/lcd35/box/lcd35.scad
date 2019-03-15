xdisp = 77;
ydisp = 64-2;
zdisp = 3.5;  // thickness of LCD itself
ynopcb = 32; // length without PCB
ycoverpcb = 47; // part of y-lcd covered with PCB
zlcdpcb = 6; // thickness of LCD including PCB

xview = 74; // view opening x
yview = 57; // view opening y

wthick = 2; // wall thickness

module dispouter()
{
  cube([xdisp+2*wthick, ydisp+2*wthick, zlcdpcb+2*wthick], center=true);
}

module dispcutter()
{
  addcut = 10;
  cube([xdisp,addcut + ydisp, zdisp], center=true);
  translate([0,-addcut -ydisp/2+ycoverpcb/2,-zdisp/2+0*zlcdpcb/2-0.001])
    cube([xdisp,ycoverpcb,zlcdpcb],center=true);
}

module dispcover()
{
  difference()
  {
    dispouter();
    // cut inside
    translate([0,-5,1.5])
      dispcutter();
    // cut opening
    translate([0,-3,6])
      cube([xview,yview+8,10],center=true);
  }   
}


dispcover();
