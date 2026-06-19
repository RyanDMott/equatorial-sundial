// Equatorial Sundial - Parametric design for 3D printing
// The annulus is aligned with Earth's equator, and a sphere casts shadows to indicate time

use <analemma_groove.scad>

// ===== INPUT PARAMETERS =====
latitude = 51.5 * 0 + 0 * 10 + 1 * 50.11;           // Latitude of location (degrees, positive = North)
longitude = -0.1 * 0 + 14.44 * 1;         // Longitude of location (degrees, positive = East)
time_now = 4 * 0 + 1 * 2;             // Current local time (24-hour format)
time_gmt = 1 * 0;          // Current Greenwich Mean Time (24-hour format)
is_daylight_saving = true; // Is time_now daylight saving time?

// ===== DESIGN PARAMETERS =====
earth_tilt = 23.44;        // Earth's axial tilt in degrees
inner_radius = 50;         // Inner radius of annulus in mm
annulus_thickness = 3;     // Radial thickness of annulus
segments = 24;             // Number of segments (24 for hours)
sphere_radius = 2;         // Fixed radius of central sphere in mm

// Text parameters
text_height = 2;           // Embossing depth for numbers
text_size = 6;             // Size of hour numbers

// Support structure parameters
support_width = 8;         // Width of support arc
support_thickness = 3;     // Thickness of support arc
shaft_radius_top = sphere_radius * 0.7;  // Radius at sphere (30% smaller than sphere)
shaft_radius_mid = 3;      // Radius of main shaft
shaft_taper_fraction = 1/3; // Fraction of shaft that is tapered
base_disc_radius = inner_radius * 0.5;     // Radius of base disc
base_disc_thickness = 4;   // Thickness of base disc
spacer_height = 16;        // Raise above the base disc 

// ===== DERIVED PARAMETERS =====
outer_radius = inner_radius + annulus_thickness;

is_northern = latitude > 0;

// Calculate time offset (hours difference between local time and London)
effective_time_now = time_now - (is_daylight_saving ? 1 : 0);
time_offset = ( effective_time_now - time_gmt + 12 ) % 24 - 12;

// Hour angle rotation (counterclockwise for time ahead of London)
hour_angle = time_offset * 15; // 15 degrees per hour (360/24)

// Rotation for longitude (annulus rotates about z-axis)
// Start with edge center at 0° longitude aligned with x-axis
longitude_rotation = - longitude;

// outer radius of support arc
support_radius = inner_radius + support_width;

// Height to reach earth_tilt elevation with half-angle cone
solstice_height = inner_radius * sin(earth_tilt);

// shift base towards center of mass. Close except near equator?
base_offset = inner_radius * 0.25 * ( is_northern ? 1 : - 1 );
spacer_length = 2 * ( base_disc_radius - base_offset ) - 1;

// ===== HELPER MODULES =====

// Create annulus using cone subtraction method
module annulus() {
    // Cone slope is half of earth_tilt
    cone_angle = earth_tilt / 2;
    
    inner_height = solstice_height + 0.2; // Add small amount to avoid z-fighting
    
    difference() {
        // Outer cones - cut at earth_tilt elevation
        union() {
            // Upper cone (0° to earth_tilt elevation)
            cylinder(h = solstice_height, 
                    r1 = outer_radius, 
                    r2 = outer_radius - solstice_height * tan(cone_angle), 
                    $fn = segments);
            
            // Lower cone (0° to -earth_tilt elevation)
            rotate([180, 0, 0])
                cylinder(h = solstice_height, 
                        r1 = outer_radius, 
                        r2 = outer_radius - solstice_height * tan(cone_angle), 
                        $fn = segments);
        }
        
        // Inner cones (to create hollow annulus) - also cut at earth_tilt elevation
        union() {
            // Upper cone - extend slightly to avoid z-fighting
            cylinder(h = inner_height, 
                    r1 = inner_radius, 
                    r2 = inner_radius - inner_height * tan(cone_angle), 
                    $fn = segments);
            
            // Lower cone - extend slightly to avoid z-fighting
            translate([0, 0, 0.1]) // Offset to avoid z-fighting at bottom
                rotate([180, 0, 0])
                    cylinder(h = inner_height+0.2, 
                            r1 = inner_radius, 
                            r2 = inner_radius - inner_height * tan(cone_angle), 
                            $fn = segments);
        }
    }
}

// Add hour numbers embossed on annulus face
module hour_numbers(top_face = true, rotation_offset = 0) {
    // Cone angle for tilting text
    cone_angle = earth_tilt / 2;
    
    for (hour = [1:12]) {
        for (cycle = [0:1]) {
            // Calculate angle for this hour (starting from 0° = x-axis edge center)
            // Rotate counterclockwise (when viewed from +z) for increasing hours
            angle = -((hour ) + cycle * 12) * (360 / segments) + rotation_offset - (360 / segments / 2);
            
            // Calculate radial position on the inner surface
            r = inner_radius * cos(earth_tilt / 2);
            
            // Calculate vertical position based on face
            z_pos = top_face ? 
                r * tan(earth_tilt / 2) : 
                -r * tan(earth_tilt / 2);
            
            // Position and orient the text
            rotate([0, 0, angle])
                translate([r, 0, z_pos])
                    rotate([0, top_face ? -cone_angle : cone_angle, 0]) // Tilt radially into surface
                        rotate([90, 0, 90])
                            rotate([0, 0, (latitude < 0) ? 180 : 0]) // Flip for southern hemisphere
                                rotate([0, 180, 0])
                                    linear_extrude(height = 3 * text_height)
                                        text(str(hour), size = text_size, halign = "center", valign = "center", font = "Liberation Sans:style=Bold");
        }
    }
}

// Support arc connecting sphere to annulus
module support_arc() {
    // Create a disc section in the x-z plane
    difference() {
        // Outer disc
        rotate([90, 0, 0])
            cylinder(h = support_thickness, r = support_radius, center = true, $fn = 100);
        
        // Cut out middle to avoid z-fighting
        rotate([90, 0, 0])
            cylinder(h = support_thickness + 2*support_width, r = inner_radius, center = true, $fn = 100);
        
        // Select quadrant based on latitude
        if (latitude >= 0) {
            // Keep lower +x quadrant for positive latitude
            translate([0, 0, 100 + solstice_height])
                cube([200, 200, 200], center = true); // Remove upper half
            translate([-100, 0, 0])
                cube([200, 200, 200], center = true); // Remove -x half
        } else {
            // Keep upper +x quadrant for negative latitude
            translate([0, 0, -100 - solstice_height])
                cube([200, 200, 200], center = true); // Remove lower half
            translate([-100, 0, 0])
                cube([200, 200, 200], center = true); // Remove -x half
        }
    }
}

// Tapered shaft connecting sphere to support arc
module support_shaft() {
    // Calculate arc radius to match support_arc
    arc_radius = inner_radius - inner_radius * tan(earth_tilt) * tan(earth_tilt / 2);
    shaft_length = support_radius;
    taper_length = shaft_length * shaft_taper_fraction;
    straight_length = shaft_length - taper_length;
    
    if (latitude >= 0) {
        // Shaft going down for positive latitude
        translate([0, 0, -shaft_length]) {
            // Tapered section (top 1/3 nearest sphere)
            translate([0, 0, straight_length])
                cylinder(h = taper_length, r1 = shaft_radius_mid, r2 = shaft_radius_top, $fn = 32);
            
            // Straight section (bottom 2/3)
            cylinder(h = straight_length, r = shaft_radius_mid, $fn = 32);
        }
    } else {
        // Shaft going up for negative latitude
        // Straight section (bottom 2/3)
        cylinder(h = straight_length, r = shaft_radius_mid, $fn = 32);
        
        // Tapered section (top 1/3 nearest sphere)
        translate([0, 0, straight_length])
            cylinder(h = taper_length, r1 = shaft_radius_mid, r2 = shaft_radius_top, $fn = 32);
    }
}

// Base disc
module base_disc() {
    time_str = str(time_offset > 0 ? "+" : "-", abs(time_offset), "H GMT");
    union()
    {
        cylinder(h = base_disc_thickness, r = base_disc_radius, 
            center = false, $fn = 100);
        translate([0,0,base_disc_thickness-0.01])
            union(){
                translate([0, 10, 0])
                    rotate([0,0,90])
                    mirror([1,0,0])
                    analemma_groove(); 
                linear_extrude(0.4)
                    union(){
                        translate([0,15,0])
                            rotate([0,0,180])
                            text("shadow offset", size=3, 
                                halign="center", valign="top");   
                        translate([0,-5,0])
                            text(str("Lat: ", latitude), size=3, 
                                halign="center", valign="top");
                        translate([0,-10,0])
                            text(str("Lon: ", longitude), size=3, 
                                halign="center", valign="top");
                        translate([0,-15,0])
                            text(time_str, size=3, 
                                halign="center", valign="top");
                    }
            }
    }
}

// ===== MAIN ASSEMBLY =====

// Cut plane through y-axis - normal makes angle with -x axis = latitude
module cut_plane() {
    // Had been 90-latitude, which I don't think is right
    rotate([0, latitude, 0])
        translate([-support_radius, 0, 0])
            cube(2 * ( support_radius ), center = true);
}

union() {
    // Step 1-3: Create annulus with text, rotate by longitude, then cut
    difference() {
        union() {
            rotate([0, 0, longitude_rotation]) {
                rotate([0, 0, hour_angle]) {
                    // Annulus with embossed text
                    difference() {
                        annulus();
                        // Subtract hour numbers (emboss into surface)
                        hour_numbers(top_face = true, rotation_offset = 0);
                        hour_numbers(top_face = false, rotation_offset = 360/segments); // Offset by 1 segment
                    }
                }
            };
    
            // Support arc
            support_arc();
        }
            
        // Cut by plane through y-axis
        cut_plane();
    }
    
    // Step 4: Add support structures (only rotated by hour_angle, not longitude)
    // Central sphere
    sphere(r = sphere_radius, $fn = 64);
    
    // Tapered shaft
    support_shaft();
    
    // Base disc - rotated to be perpendicular to cut plane normal
    // Position at end of support arc
    rotate([0, latitude-90, 0])
    union()
    {
        translate([0, 0, -inner_radius-spacer_height/2])
        cube([spacer_length, support_thickness, spacer_height], center=true);
        
        translate([base_offset, 0, -support_radius+support_width-spacer_height])
            base_disc();    
    }
}
