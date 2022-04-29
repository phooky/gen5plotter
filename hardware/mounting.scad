m3_head_clearance = 5.3;
m3_screw_clearance = 3.2;
$fn=30;

module m3_bolt(bolt_len) {
    head_len=5;
    translate([0,0,bolt_len/2]) cylinder(d=m3_screw_clearance,h=bolt_len+0.05,center=true);
    translate([0,0,-head_len/2]) cylinder(d=m3_head_clearance,h=head_len,center=true);
}

module bolts(hole_distance,bolt_len) {
    translate([hole_distance/2,0,0]) m3_bolt(bolt_len);
    translate([-hole_distance/2,0,0]) m3_bolt(bolt_len);
}

// clearance between bolthole center and belt
upper_clearance = 5.0;

// measured parameters
hole_distance = 65.0;
bolt_len = 15.0;

module support(support_th) {
    difference() {
        hull() {
            translate([hole_distance/2,0,support_th/2])
                cylinder(r=upper_clearance,h=support_th,center=true);
            translate([-hole_distance/2,0,support_th/2])
                cylinder(r=upper_clearance,h=support_th,center=true);
        }
        translate([0,0,-0.05]) bolts(hole_distance, bolt_len);
    }
}

servo_screw_hole_d = 1.8;

support(2.5);
