// helper include with default center=true

module box(dims, center=true) {
    cube(dims, center=center);
}

module rect(dims, center=true) {
    square(dims, center=center);
}

module disc(h, r, d, r1, r2, d1, d2, center=true) {
    cylinder(h=h, r=r, d=d, r1=r1, r2=r2, d1=d1, d2=d2, center=center);
}

module extrude(height, convexity, twist, scale, slices, center=true) {
    linear_extrude(height=height, convexity=convexity, twist=twist, scale=scale, slices=slices, center=center)
        children();
}

module surf(file, convexity, center=true) {
    surface(file=file, convexity=convexity, center=center);
}
