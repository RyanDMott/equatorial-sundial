// Equatorial Sundial - Parametric design for 3D printing
// The annulus is aligned with Earth's equator, and a sphere casts shadows to indicate time

// ===== INPUT PARAMETERS =====
latitude = 40.7;           // Latitude of location (degrees, positive = North)
longitude = -74.0;         // Longitude of location (degrees, positive = East)
time_now = 14;             // Current local time (24-hour format)
time_london = 19;          // Current time in London (24-hour format)
is_daylight_saving = false; // Is time_now daylight saving time?

// ===== DESIGN PARAMETERS =====
earth_tilt = 23.44;        // Earth's axial tilt in degrees
inner_radius = 50;         // Inner radius of annulus in mm
annulus_thickness = 5;     // Radial thickness of annulus
segments = 24;             // Number of segments (24 for hours)
sun_angular_width = 0.5;   // Angular width of sun in degrees
margin = 1.2;              // 20% margin for sphere size
cutoff_margin = 3;         // mm above/below earth_tilt edges to cut annulus

// Text parameters
text_height = 2;           // Embossing depth for numbers
text_size = 6;             // Size of hour numbers

// Support structure parameters
support_width = 8;         // Width of support arc
support_thickness = 3;     // Thickness of support arc
shaft_radius_base = 3;     // Radius of shaft at base
shaft_radius_top = 1.5;    // Radius of shaft at sphere
base_disc_radius = 60;     // Radius of base disc
base_disc_thickness = 4;   // Thickness of base disc

// ===== DERIVED PARAMETERS =====
outer_radius = inner_radius + annulus_thickness;
sphere_radius = inner_radius * tan(sun_angular_width) * margin;

// Calculate time offset (hours difference between local time and London)
effective_time_now = time_now - (is_daylight_saving ? 1 : 0);
time_offset = effective_time_now - time_london;

// Hour angle rotation (counterclockwise for time ahead of London)
hour_angle = time_offset * 15; // 15 degrees per hour (360/24)

// Rotation for longitude (annulus rotates about z-axis)
// Start with edge center at 0° longitude aligned with x-axis
longitude_rotation = longitude;

// ===== HELPER MODULES =====

// Create annulus using cone subtraction method
module annulus() {
    difference() {
        // Outer cones
        union() {
            // Upper cone (0° to earth_tilt)
            cylinder(h = outer_radius * tan(earth_tilt) + cutoff_margin, 
                    r1 = outer_radius, r2 = outer_radius - (outer_radius * tan(earth_tilt) + cutoff_margin) * tan(earth_tilt), 
                    $fn = segments);
            
            // Lower cone (0° to -earth_tilt)
            rotate([180, 0, 0])
                cylinder(h = outer_radius * tan(earth_tilt) + cutoff_margin, 
                        r1 = outer_radius, r2 = outer_radius - (outer_radius * tan(earth_tilt) + cutoff_margin) * tan(earth_tilt), 
                        $fn = segments);
        }
        
        // Inner cones (to create hollow annulus)
        union() {
            // Upper cone
            cylinder(h = inner_radius * tan(earth_tilt) + cutoff_margin + 1, 
                    r1 = inner_radius, r2 = inner_radius - (inner_radius * tan(earth_tilt) + cutoff_margin + 1) * tan(earth_tilt), 
                    $fn = segments);
            
            // Lower cone
            rotate([180, 0, 0])
                cylinder(h = inner_radius * tan(earth_tilt) + cutoff_margin + 1, 
                        r1 = inner_radius, r2 = inner_radius - (inner_radius * tan(earth_tilt) + cutoff_margin + 1) * tan(earth_tilt), 
                        $fn = segments);
        }
    }
}

// Add hour numbers embossed on annulus face
module hour_numbers(top_face = true, rotation_offset = 0) {
    for (hour = 1; hour <= 12; hour++) {
        for (cycle = 0; cycle < 2; cycle++) {
            // Calculate angle for this hour (starting from 0° = x-axis edge center)
            // Rotate counterclockwise (when viewed from +z) for increasing hours
            angle = -((hour - 1) + cycle * 12) * (360 / segments) + rotation_offset - (360 / segments / 2);
            
            // Calculate radial position (middle of annulus thickness)
            r = (inner_radius + outer_radius) / 2;
            
            // Calculate vertical position based on face
            z_pos = top_face ? 
                r * tan(earth_tilt / 2) : 
                -r * tan(earth_tilt / 2);
            
            // Position and orient the text
            rotate([0, 0, angle])
                translate([r, 0, z_pos])
                    rotate([top_face ? -earth_tilt/2 : earth_tilt/2, 0, 0])
                        rotate([90, 0, 90])
                            rotate([0, 0, (latitude < 0) ? 180 : 0]) // Flip for southern hemisphere
                                linear_extrude(height = text_height)
                                    text(str(hour), size = text_size, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
        }
    }
}

// Support arc connecting sphere to annulus
module support_arc() {
    // Arc extends from xy-plane on annulus to z-axis
    arc_radius = outer_radius + support_width/2;
    arc_angle = 90; // Always 90 degrees
    
    // Rotate to x-z plane and orient based on latitude
    rotate([0, 0, 0]) // Start at x-axis
        rotate([90, 0, 0]) // Rotate to x-z plane
            translate([0, 0, -support_thickness/2]) // Center on x-z plane
                if (latitude >= 0) {
                    // Arc going downward (negative z) for positive latitude
                    rotate([0, 0, 180])
                        rotate_extrude(angle = arc_angle, $fn = 100)
                            translate([arc_radius, 0, 0])
                                square([support_width, support_thickness], center = true);
                } else {
                    // Arc going upward (positive z) for negative latitude
                    rotate_extrude(angle = arc_angle, $fn = 100)
                        translate([arc_radius, 0, 0])
                            square([support_width, support_thickness], center = true);
                }
}

// Tapered shaft connecting sphere to support arc
module support_shaft() {
    shaft_length = (latitude >= 0) ? 
        outer_radius + support_width/2 : 
        outer_radius + support_width/2;
    
    if (latitude >= 0) {
        // Shaft going down for positive latitude
        translate([0, 0, -shaft_length])
            cylinder(h = shaft_length, r1 = shaft_radius_top, r2 = shaft_radius_base, $fn = 32);
    } else {
        // Shaft going up for negative latitude
        cylinder(h = shaft_length, r1 = shaft_radius_base, r2 = shaft_radius_top, $fn = 32);
    }
}

// Base disc
module base_disc() {
    cylinder(h = base_disc_thickness, r = base_disc_radius, center = true, $fn = 100);
}

// ===== MAIN ASSEMBLY =====

// Cut plane through y-axis - normal makes angle with -x axis = latitude
module cut_plane() {
    rotate([0, latitude, 0])
        translate([-200, 0, 0])
            cube([400, 400, 400], center = true);
}

// First apply hour angle rotation, then longitude rotation, then cut
rotate([0, 0, longitude_rotation]) {
    difference() {
        rotate([0, 0, hour_angle]) {
            union() {
                // Main annulus with hour numbers
                difference() {
                    annulus();
                    // Subtract hour numbers (emboss into surface)
                    hour_numbers(top_face = true, rotation_offset = 0);
                    hour_numbers(top_face = false, rotation_offset = 360/segments); // Offset by 1 segment
                }
                
                // Central sphere
                sphere(r = sphere_radius, $fn = 64);
                
                // Support arc in x-z plane
                support_arc();
                
                // Tapered shaft
                support_shaft();
                
                // Base disc - rotated to be perpendicular to cut plane normal
                // Position at end of support arc
                if (latitude >= 0) {
                    translate([0, 0, -(outer_radius + support_width/2)])
                        rotate([latitude, 0, 0])
                            base_disc();
                } else {
                    translate([0, 0, (outer_radius + support_width/2)])
                        rotate([latitude, 0, 0])
                            base_disc();
                }
            }
        }
        
        // Cut by plane through y-axis
        cut_plane();
    }
}
