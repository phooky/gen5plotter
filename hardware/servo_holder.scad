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

module pillar() {
    ht_to_under_flange=16;
    difference() {
        hull() {
            translate([0,0,2.5]) cube([4.5,upper_clearance*2,5],center=true);
            translate([0,0,ht_to_under_flange-2.5]) cube([4.5,12,5],center=true);
        }
        translate([1,0,ht_to_under_flange]) cylinder(d=servo_screw_hole_d,h=16,center=true);
    }
}

module pillars() {
    translate([27.5,0,0]) pillar();
    difference() {
        mirror([1,0,0]) pillar();
        translate([0,2.7,0]) cube([10,10,12],center=true);
    }
}

support(2.5);
translate([-15,0,0]) {
color([1,0,0])
#translate([-1.5,-50-(12-upper_clearance*2)/2,16 + 2.5]) import("sg90.stl",convexity=3);
translate([0,0,2.49]) pillars();
}
//translate([0,0,2.49])
//hinge_a();
//rotate(-90,[1,0,0])
//translate([0,-2.9,0]) simple_penholder(15);
