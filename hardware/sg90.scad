$fn=50;

// oriented facing up, with the center of the bottom
// on the XY plane

// error term for making sure tangent objects are fused
fuse = 0.0001;

// measurements
    m_body_width = 22.6;
    m_body_height = 22.1;
    m_body_base_to_wingtop = 18.0;
    m_body_wing_height = 2.5;
    m_body_wingtip_to_wingtip = 32.1;
    m_body_depth = 12.3;
    m_cord_depth = 4;
    m_cord_height = 3;
    m_cord_zloc = 5.6;
    
    m_boss_height = 5;
    m_boss_diameter = 11.6;
    
    m_horn_top = 31.4;
    m_horn_base_diameter = 7.1;
    m_horn_end_diameter = 3.5;
    m_horn_length = 32;
    m_horn_th = 1.3;

module sg90(horn_angle=0, cord_length=6) {
    body();
    cord(length = cord_length);
    boss();
    horn(angle=horn_angle);
}

module horn(angle = 0) {
    horn_height = m_horn_top - (m_body_height + m_boss_height);
    translate([m_body_width/4,0,m_body_height+m_boss_height])
    rotate([0,0,angle])
    union() {
        cylinder(h=horn_height,
            d = m_horn_base_diameter);
        translate([0,0,horn_height - m_horn_th])        
        hull() {
            translate([m_horn_length/2,0,0])
            cylinder(h=m_horn_th, d = m_horn_end_diameter);
            translate([-m_horn_length/2,0,0])
            cylinder(h=m_horn_th, d = m_horn_end_diameter);
            cylinder(h=m_horn_th, d = m_horn_base_diameter);
        }
    }
}

module cord(length = 6) {
    // cord clearance
    translate([-fuse, 0, 0])
    translate([m_body_width/2,m_cord_depth-m_body_depth/2,
        m_cord_zloc-m_cord_height/2])
    cube([length, m_cord_depth, m_cord_height]);
}

module body() {
    translate([0,0,-fuse])
    translate([-m_body_width/2, -m_body_depth/2, 0])
    union() {
        cube([m_body_width, m_body_depth, m_body_height]);
        translate([-(m_body_wingtip_to_wingtip - m_body_width)/2,
            0, m_body_base_to_wingtop - m_body_wing_height])
        cube([m_body_wingtip_to_wingtip, 
            m_body_depth, m_body_wing_height]);
    }
}

module boss() {
    translate([0,0,m_body_height])
    hull() {
        cylinder(h=m_boss_height, d = m_boss_diameter);
        translate([m_body_width/4,0,0])
        cylinder(h=m_boss_height, d = m_boss_diameter);
    }        
}   

sg90();

