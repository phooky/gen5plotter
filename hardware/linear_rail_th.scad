use <sg90.scad>
use <mounting.scad>

// Constants

// ----- M2 fastener -----
m2_bolt_head_dia = 3.8; // mm
m2_bolt_head_clearance_dia = 4.4; // mm
m2_bolt_head_height = 2; // mm
m2_bolt_thread_dia = 2; // mm
m2_bolt_thread_clearance_dia = 2.4; // mm
m2_bolt_length = 10; // mm

// ----- Linear rail -----
rail_width = 9; // mm
rail_height = 6.3; // mm
rail_length = 100; // mm
m2_mounting_height = 4.6; // mm
rail_first_hole_offset = 10; // mm
rail_successive_offset = 20; // mm

// ----- M2 hex nut ------
m2_hex_width = 4; // mm
m2_hex_nut_depth = 1.6; // mm (usual depth)
m2_hex_width_clearance = 4.5; // mm

// ----- Linear rail support -----
rail_support_height =  m2_bolt_length - m2_mounting_height; // mm
// support has a lip at one end to help locate the rail vertically
rail_support_lip_width = 1.5; // mm
rail_support_lip_height = 1; // mm

module m2_fastener_hole(length = 20, head_ht = 20) {
    $fn = 40;
    // The hole is located with the origin at the base of the head.
    // The fastener is oriented with the thread in the -Z direction.
    cylinder(d=m2_bolt_head_clearance_dia, h=head_ht); // bolt head
    // threaded bolt
    translate([0,0,-length])
	cylinder(d=m2_bolt_thread_clearance_dia, h=length+0.1); // 0.1 adjustment to ensure overlap
}

// mock fastener for assembly testing
module m2_fastener(length = m2_bolt_length, head_ht = 2) {
    $fn = 40;
    // The hole is located with the origin at the base of the head.
    // The fastener is oriented with the thread in the -Z direction.
    cylinder(d=m2_bolt_head_dia, h=head_ht); // bolt head
    // threaded bolt
    translate([0,0,-length])
	cylinder(d=m2_bolt_thread_dia, h=length+0.1); // 0.1 adjustment to ensure overlap
}

module rail_holes(rail_length = 100, mocks=false) {
    // located from bottom center of one end of the rail; rail extends in +Y direction
    for (offset = [rail_first_hole_offset : rail_successive_offset : rail_length]) {
	translate([0,offset,m2_mounting_height])
	    if (mocks) m2_fastener();
	    else m2_fastener_hole();
    }
}

module rail_approximate(rail_length = 100) {
    color("red") difference() {
	translate([-rail_width/2,0,0])
	    cube([rail_width,rail_length,rail_height]);
	rail_holes();
    }
}

module m2_hex_nut_hole(depth=10) {
    // located from the center of the nut, bottom face
    $fn=40;
    intersection_for(theta = [0, 60, 120]) {
	rotate([0,0,theta])
	    translate([0,0,depth/2])
	    cube([m2_hex_width_clearance,100,depth],center=true);
    }
    translate([0,0,-20])
	cylinder(d=m2_bolt_thread_clearance_dia,h=40);
}

module rail_support(rail_length = 100) {
    difference() {
	union() { // rail support + lip
	    translate([-rail_width/2,0,0])
		cube([rail_width + rail_support_lip_width,
		      rail_length,
		      rail_support_height]);
	    translate([rail_width/2,0,rail_support_height])
		cube([rail_support_lip_width,
		      rail_length,
		      rail_support_lip_height]);
	}
	// holes for hex nuts
	for (offset = [rail_first_hole_offset : rail_successive_offset : rail_length]) {
	    translate([0,offset,m2_hex_nut_depth])
		rotate([180,0,0]) m2_hex_nut_hole();

	}
    }
}

//m2_hex_nut_hole();
translate([0,0,rail_support_height]) {
    // #color("green") rail_holes(mocks=true);	
    // #rail_approximate();
}
rail_support();
support(4);

// *** copied from sg90.scad, ugh "use" vs "import" ***
m_body_width = 23;
m_body_wing_height = 2.5;
m_body_depth = 12.5;

// ----- mounting holes ----
sg90_mounting_hole_dia = 2.5; // mm
sg90_mounting_hole_d_from_body = 2.65; // mm
sg90_mounting_hole_separation = m_body_width + sg90_mounting_hole_d_from_body * 2;

module sg90_support() {
    mount_th = 5;
    mount_w = (sg90_mounting_hole_d_from_body*2) - 0.1;
    mount_d = m_body_depth;
    module one_mount() {
	// located with origin at the top of the mounting hole
	difference() {
	    translate([0,0,-mount_th/2])
		cube([mount_w,mount_d,mount_th], center=true);
	    translate([0,0,-mount_th + m2_hex_nut_depth])
		rotate([180,0,0]) m2_hex_nut_hole();
	}
    }
    one_mount();
    translate([sg90_mounting_hole_separation,0,0]) one_mount();
}

sg90_support_height = 10 - m_body_wing_height;
translate([18,30,sg90_support_height]) {
    rotate([0,0,90]) {
	//# sg90_mount_origin();
	sg90_support();
    }
}
// bridge. this is hacky but whatevs, i'm busy
color("orange")
hull() {
    translate([18-m_body_depth/2,27.3,sg90_support_height-5])
	cube([0.05,5.6+sg90_mounting_hole_separation,5]);
    translate([rail_width/2,28,rail_height-5])
	cube([0.05,4+sg90_mounting_hole_separation,5]);
}
