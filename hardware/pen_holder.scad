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

module simple_penholder(inner_d) {
    inner_clearance = 1.5;
    th = 2.2;
    translate([0,-(inner_d/2+th+inner_clearance),0])
    difference() {
        union() {
            hull() {
                cylinder(d=inner_d+(th*2),h=upper_clearance*2,center=true);
                translate([0,inner_d/2 + th + inner_clearance/2,0])
                cube([inner_d+(th*2), inner_clearance, upper_clearance*2],center=true);
            }
            translate([0,-inner_d/2 - th, 0])
            rotate(90,[0,1,0])
            cylinder(h=th*3,r=upper_clearance,center=true);
        }
        cylinder(d=inner_d,h=upper_clearance*2 + 1.0, center=true);
        rotate(90,[0,1,0])
        translate([0,-inner_d/2 -th,-15/2]) m3_bolt(15);
        translate([0,-inner_d,0])
        cube([th*1.5,inner_d*2,upper_clearance*2 + 1.0],center=true);
    }
}
    
    

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

    
support(3);
rotate(-90,[1,0,0])
translate([0,-2.9,0]) simple_penholder(15);
