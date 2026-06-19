// analemma_groove.scad
//
// Engraves the analemma curve as a groove on a flat surface.
// The curve is the locus  (x, y) = ( R*sin(EoT*0.25 deg),  R*sin(decl deg) )
// for each day of the year, where EoT is in minutes and decl in degrees.
//
// Requires: analemma_2030.scad  (include'd below)
//
// Public modules:
//   analemma_groove()       - groove + arrowhead as a positive solid
//                             (subtract from your own surface)
//   analemma_demo_slab()    - a rectangular slab with the groove already cut

include <analemma_2030.scad>

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------
ANALEMMA_R   = 50;        // projection radius (mm)
GROOVE_WIDTH = 0.5;       // total width of groove (mm)
GROOVE_DEPTH = 0.3;       // depth  of groove (mm)
ARROW_LENGTH = 3;       // arrowhead tip-to-base (mm)
ARROW_WIDTH  = 2;       // arrowhead base width  (mm)

// Demo-slab dimensions
SLAB_HALF_W  = 16;        // half-width  in x (mm)
SLAB_HALF_H  = 28;        // half-height in y (mm)
SLAB_THICK   = 3;         // thickness       (mm)

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// One ANALEMMA_DATA entry  ->  [x, y] in mm.
// sin() in OpenSCAD takes degrees already.
// EoT is in minutes; * 0.25 converts to degrees.
function analemma_xy(entry) =
    [ ANALEMMA_R * sin(entry[0] * 0.25),
      ANALEMMA_R * sin(entry[1])
    ];

// Contiguous run of [x,y] points, 0-based indices a..b inclusive.
function analemma_points(a, b) =
    [ for (i = [a : b]) analemma_xy(ANALEMMA_DATA[i]) ];

// ---------------------------------------------------------------------------
// Lobe geometry
//
// The analemma self-intersects exactly once, between the segments
// day102->103 and day242->243 (1-based), at approx (-0.15, +7.77) mm.
// Splitting there gives two lobes, each a simple (non-self-intersecting)
// closed curve.  Python brute-force search confirmed zero self-intersections
// in either lobe.
//
// The lobe endpoints (indices 102 and 242) are 0.25 mm apart — well within
// the 0.5 mm groove width — so polygon()'s implicit closing edge is fully
// buried inside the stripe and invisible.
//
//   Lobe 1 (lower, wraps through January):
//       indices 242 .. 364, then 0 .. 102
//   Lobe 2 (upper):
//       indices 102 .. 242
//
// Each lobe is turned into a stripe via the standard dilate-minus-erode
// idiom:
//       difference() {
//           offset(+GROOVE_WIDTH/2)  polygon(lobe_points);
//           offset(-GROOVE_WIDTH/2)  polygon(lobe_points);
//       }
// This is well-defined because both lobes have nonzero area and the
// erosion (0.25 mm) is much smaller than any feature size.
// ---------------------------------------------------------------------------

function lobe1_points() = concat(analemma_points(242, 364),
                                 analemma_points(0,   102));
function lobe2_points() = analemma_points(102, 242);

// ---------------------------------------------------------------------------
// Groove lobe – dilate-minus-erode stripe, extruded to groove depth
// ---------------------------------------------------------------------------
module groove_lobe(pts) {
    linear_extrude(height = GROOVE_DEPTH)
        difference() {
            offset(r = +GROOVE_WIDTH / 2)  polygon(pts);
            offset(r = -GROOVE_WIDTH / 2)  polygon(pts);
        }
}

// ---------------------------------------------------------------------------
// Arrowhead at Jan 1 (index 0), pointing toward Jan 2 (index 1).
//
// Triangle in a local frame where +Y is "forward", rotated into world
// coords and translated to the Jan-1 point.  Extruded to groove depth.
// ---------------------------------------------------------------------------

module analemma_arrowhead() {
    i0 = 0;
    i1 = 15; // HACK lookahead ~ arrowhead length instead of one day
    p0 = analemma_xy(ANALEMMA_DATA[i0]);
    p1 = analemma_xy(ANALEMMA_DATA[i1]);

    dx = p1[0] - p0[0];
    dy = p1[1] - p0[1];
    // atan2(x, y) -> angle from +Y toward +X, exactly what rotate([0,0,a])
    // needs to map local +Y onto the (dx, dy) tangent.
    angle = atan2(dx, dy);

    translate([p0[0], p0[1], 0])
        rotate([0, 0, -angle])
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
        groove_lobe(lobe1_points());
        groove_lobe(lobe2_points());
        analemma_arrowhead();
    }
}

// ---------------------------------------------------------------------------
// Demo slab – a plain block with the groove cut into its top face.
// ---------------------------------------------------------------------------
module analemma_demo_slab() {
    difference() {
        // Slab: top face flush at z = 0
        translate([0, 0, -SLAB_THICK/2])
            cube([2*SLAB_HALF_W, 2*SLAB_HALF_H, SLAB_THICK], center = true);

        // Groove cuts downward from z = 0
        translate([0, 0, -0.01])
        analemma_groove();
    }
}

// ---------------------------------------------------------------------------
// Default render – the demo slab.
// Swap to  analemma_groove();  if you only need the cutter shape.
// ---------------------------------------------------------------------------
analemma_demo_slab();