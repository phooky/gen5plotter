use <sg90.scad>
use <mounting.scad>

filament_diameter = 1.75 + 0.15;
clip_diameter = 5;
clip_ht = 3.5;

guide_width = 25;
guide_th = 2;

$fn=45;
thumbscrew_bolt_diameter = 5;

clearances_motor = 0.1;
module motor_bracket() {
    cm = clearances_motor;
    difference() {
        translate([-10,0,10])
        cube([34,10,20], center=true);
        translate([-10,18 - (5 + 2.5),12])
        rotate([90,0,0])
        union() {
            minkowski() {
                sg90(horn_angle=30);
                cube([cm,cm,cm], center=true);
            }
            // cable entry clearance
            hull() {
                translate([-0.5,0,12])
                cord(length=3);
                cord(length=4);
            }
        }
    }
}

module pen_holder() {
    ph_h = 10;
    outer_diameter = 19;
    inner_diameter = 13;
    center_to_hinge = 40;
    translate([-outer_diameter/2,0,0])
    cube([outer_diameter,3,27]);
    translate([-15,0,27-6])
    cube([10,3,6]);
    difference() { 
        hull() { // outside of holder
            translate([0,center_to_hinge,0])
            cylinder(h=ph_h,d=outer_diameter);
            translate([-outer_diameter/2,0,0])
            cube([outer_diameter,1,ph_h]);
        }
        translate([0,center_to_hinge,0])
        intersection() {
            cylinder(h=22,d=inner_diameter,center=true);
            translate([0,4.7,0])
            intersection_for( i = [30,-30] ) {
            rotate([0,0,i])
            cube([20,20,22],center=true);
            }
        }
        translate([0,center_to_hinge,ph_h/2])
        rotate([-90,0,0])
        cylinder(d=5, h=20);
    }
}

module pen_hinge() {
    translate([8,-4,0])
    cube([19,0.7,15]);
    translate([8+19/2,5,8])
    rotate([90,0,0])
    pen_holder();
}



gl_ht = 10.0;
gl_width = 32.0;
gl_depth = 4.0;

module guide () {
    difference(){
    translate([-28.5,0,2.5+gl_width/2])
    rotate([0,90,0])
    rotate([90,0,0])
    difference() {
        // body
        cube([gl_width,gl_depth,gl_ht],center=true);
        // filament holes
        for (theta = [90, -90]) {
            rotate([0,0,theta])
            translate([0,(guide_width+filament_diameter)/2,0])
            cylinder(d=filament_diameter+0.3, h=100,center=true);
        }
    }
    translate([-65/2,0,0])
    cylinder(d=7,h=40);
    }
}

//#color("#8080ff") 
//translate([-10,18 - (5 + 2.5),12])
//rotate([90,0,0]) sg90(horn_angle=0);
union() {
    support(2.5);
    motor_bracket();
    guide();
}
color("#00ff00") pen_hinge();

