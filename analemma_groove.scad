// analemma_groove.scad
//
// Engraves the analemma curve as a groove on a flat surface.
// The curve is the locus  (x, y) = ( R·sin(EoT·0.25°),  R·sin(decl°) )
// for each day of the year, where EoT is in minutes and decl in degrees.
//
// Requires: analemma_2030.scad  (include'd below)
//
// Public modules:
//   analemma_groove()       – groove + arrowhead as a positive solid
//                             (subtract from your own surface)
//   analemma_demo_slab()    – a rectangular slab with the groove already cut

include <analemma_2030.scad>

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------
ANALEMMA_R   = 50;        // projection radius (mm)
GROOVE_WIDTH = 0.5;       // total width of groove (mm)
GROOVE_DEPTH = 0.3;       // depth  of groove (mm)
ARROW_LENGTH = 1.4;       // arrowhead tip-to-base (mm)
ARROW_WIDTH  = 1.0;       // arrowhead base width  (mm)

// Demo-slab dimensions
SLAB_HALF_W  = 16;        // half-width  in x (mm)
SLAB_HALF_H  = 28;        // half-height in y (mm)
SLAB_THICK   = 3;         // thickness       (mm)

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// One ANALEMMA_DATA entry  ->  [x, y] in mm.
// sin() in OpenSCAD takes degrees, which is what we want for declination.
// EoT is in minutes; multiply by 0.25 to convert to degrees first.
function analemma_xy(entry) =
    [ ANALEMMA_R * sin(entry[0] * 0.25),
      ANALEMMA_R * sin(entry[1])
    ];

// Contiguous run of [x,y] points, 0-based indices a..b inclusive.
function analemma_points(a, b) =
    [ for (i = [a : b]) analemma_xy(ANALEMMA_DATA[i]) ];

// Reverse a vector of points.  (No built-in reverse() in OpenSCAD.)
function reverse_pts(pts) =
    [ for (i = [len(pts)-1 : -1 : 0]) pts[i] ];

// ---------------------------------------------------------------------------
// Open-path stripe via the "degenerate loop" trick:
//
//   polygon() always closes its point list.  If we feed it a *closed*
//   loop of zero width — forward points followed by the same points in
//   reverse — the resulting polygon has zero area but the correct
//   topology.  offset(+r) then inflates it into a uniform stripe of
//   width 2r around the open path, with rounded ends.  No spurious
//   closing edge appears because the forward and reverse edges overlap
//   exactly.
// ---------------------------------------------------------------------------
function stripe_loop(pts) = concat(pts, reverse_pts(pts));

// ---------------------------------------------------------------------------
// Self-intersection split
//
// Brute-force segment search (done offline in Python) found exactly one
// crossing: between the segment day102->103 and day242->243  (1-based),
// i.e. 0-based indices 101->102 and 241->242.
// Splitting at indices 102 and 242 produces three arcs each free of
// self-intersection, safe for offset().
//
//   Arc A:  0  .. 102   (Jan  1 – Apr 12)
//   Arc B:  102 .. 242  (Apr 12 – Aug 30)   <- upper lobe
//   Arc C:  242 .. 364  (Aug 30 – Dec 31)
// ---------------------------------------------------------------------------
SPLIT_1 = 102;
SPLIT_2 = 242;

// ---------------------------------------------------------------------------
// Groove arc – one non-self-intersecting piece of the curve
// ---------------------------------------------------------------------------
module groove_arc(a, b) {
    linear_extrude(height = GROOVE_DEPTH)
        offset(r = GROOVE_WIDTH / 2)
            polygon(stripe_loop(analemma_points(a, b)));
}

// ---------------------------------------------------------------------------
// Arrowhead at Jan 1 (index 0), pointing toward Jan 2 (index 1).
//
// Built as a triangle in a local frame where +Y is the forward direction,
// then rotated into world coordinates and translated to the Jan-1 point.
// Extruded to the same depth as the groove.
// ---------------------------------------------------------------------------
module analemma_arrowhead() {
    p0 = analemma_xy(ANALEMMA_DATA[0]);
    p1 = analemma_xy(ANALEMMA_DATA[1]);

    dx = p1[0] - p0[0];
    dy = p1[1] - p0[1];
    // atan2(x, y) gives the angle from +Y toward +X, which is exactly
    // what rotate([0,0,angle]) needs to map local +Y onto (dx, dy).
    angle = atan2(dx, dy);

    translate([p0[0], p0[1], 0])
        rotate([0, 0, angle])
            linear_extrude(height = GROOVE_DEPTH)
                polygon([
                    [ 0,                ARROW_LENGTH ],   // tip
                    [-ARROW_WIDTH / 2,  0            ],   // base left
                    [ ARROW_WIDTH / 2,  0            ]    // base right
                ]);
}

// ---------------------------------------------------------------------------
// Public: complete groove + arrowhead (positive solid).
//   Sits on z = 0, extrudes in +z.  Subtract from a surface whose top
//   face is at z = 0.
// ---------------------------------------------------------------------------
module analemma_groove() {
    union() {
        groove_arc(0,       SPLIT_1);
        groove_arc(SPLIT_1, SPLIT_2);
        groove_arc(SPLIT_2, 364);
        analemma_arrowhead();
    }
}

// ---------------------------------------------------------------------------
// Demo slab – a plain block with the groove cut into its top face.
// ---------------------------------------------------------------------------
module analemma_demo_slab() {
    difference() {
        // Slab: top face flush at z = 0
        translate([0, 0, -SLAB_THICK])
            cube([2*SLAB_HALF_W, 2*SLAB_HALF_H, SLAB_THICK], center = true);

        // Groove cuts downward from z = 0
        analemma_groove();
    }
}

// ---------------------------------------------------------------------------
// Default render – the demo slab.
// Swap to  analemma_groove();  if you only need the cutter shape.
// ---------------------------------------------------------------------------
analemma_demo_slab();
