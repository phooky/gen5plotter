M3_tap_flats = 2.794;
tap_flats_clearance = 0.07;
handle_length = 50;
$fn=50;
module tap_hole() {
    a = M3_tap_flats + 2*tap_flats_clearance;
    cube([a,a,20],center=true);
}

module tap_body() {
    translate([0,0,0.5]) cylinder(d=10,h=6,center=true);
    cube([handle_length,5,5],center=true);
}

difference() {
    tap_body();
    tap_hole();
}