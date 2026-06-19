# Equatorial Sphere-Shadow Sundial

A parametric 3D-printable sundial and companion analemma engraving,
generated with OpenSCAD and Python.

---

## Files

| File | Purpose |
|---|---|
| `solar.py` | Equation of Time and solar declination functions |
| `demo_analemma.py` | Generates the analemma plot and OpenSCAD data file |
| `analemma_2030.scad` | Auto-generated data: 365 × (EoT, declination) pairs for 2030 |
| `analemma_groove.scad` | OpenSCAD module: analemma figure-eight groove for engraving |
| `equatorial_sundial.scad` | Main sundial body |

---

## Prerequisites

**Python 3** with matplotlib:
```
pip install matplotlib
```

**OpenSCAD** 2021.01 or later: https://openscad.org/downloads.html

---

## Running the scripts

### 1. Generate the analemma data and plot

```
python3 demo_analemma.py
```

This writes two files:
- `analemma_plot.png` — a colour-coded figure-eight plot of the analemma for 2030
- `analemma_2030.scad` — the data file consumed by `analemma_groove.scad`

To generate data for a different year, change `YEAR = 2030` near the top of
`demo_analemma.py` and re-run.  Rename the output `.scad` file and update the
`include` line in `analemma_groove.scad` to match.

### 2. Render the sundial in OpenSCAD

Open `equatorial_sundial.scad` in OpenSCAD and set the parameters at the top
of the file for your location:

```openscad
latitude         = 50.11;   // degrees North (negative for South)
longitude        = 14.44;   // degrees East  (negative for West)
time_now         = 14;      // your local time, 24-hour
time_gmt         = 13;      // current time in GMT (UTC+0; same as London time in winter)
is_daylight_saving = false; // true if your time_now is DST
```

Press **F6** to render, then export as STL for printing.

### 3. Render the analemma groove

Place `analemma_2030.scad` and `analemma_groove.scad` in the same directory,
then open `analemma_groove.scad` in OpenSCAD and press **F6**.

By default it renders `analemma_demo_slab()` — a flat tile with the groove
already cut in.  To use the groove as a cutter in your own design instead,
replace the last line with:

```openscad
analemma_groove();
```

---

## Setting up and reading the sundial

### Orientation

The sundial is an **equatorial** design: its annular ring sits parallel to
Earth's equator when flat its base at the printed latitude.

1. Mount or hold the sundial on a level surface.
   The top cut should be level with the horizon.
2. Rotate the whole assembly so the support arc points toward true North
   (Northern Hemisphere) or true South (Southern Hemisphere).  Use a compass
   and correct for **magnetic declination** for your location.
   The engraved numbers should face the equator.

### Reading the time

The small central sphere casts a shadow onto the inside of the annular ring.
Read the hour number nearest the centre of the shadow. 
Use the lower set of engraved numbers if clocks are on daylight saving time.

### Converting to clock time

Earth's elliptical orbit and axial tilt mean the sun runs up to ~16 minutes
fast or slow relative to a perfect clock throughout the year.
A timelapse video of photos at noon across a whole year would show 
the sun's shadow tracing a figure eight from top in winter to bottom in summer
centered on the 12:00 line but offset up to 16 minutes from it.
The analemma groove encodes this offset (shown for Northern Hemisphere):

- The **x axis** (left–right) represents the EoT in minutes at the same scale as the sundial.
  Positive x (right) means the shadow is fast/ahead — subtract those minutes.
  Negative x (left) means the shadow is slow/behind — add those minutes.
- The **y axis** (up–down) represents solar declination (the sun's
  apparent latitude), ranging from −23.4° (winter solstice) to
  +23.4° (summer solstice).  This axis lets you locate today's date on
  the curve. 

**To find today's correction:**
1. Estimate today's position on the figure-eight: narrow lobe = northern summer,
   wider lobe = northern winter, and the arrowhead on January 1 shows which way
   the date progresses.
2. Read the x position of that point on the curve.  
3. Add or subtract that distance from the sundial reading, to get standard clock time.  

### Additional readings

 - The shadow's vertical location indicates time of year. The shadow ranges from
   * the bottom edge at the summer solstice
   * the top edge at the winter solstice
   * the middle crease at spring and autumn equinoxes
   Note that the transition from standard to Daylight Saving time does not generally
   happen at equinoxes. But in general, if the shadow is well into the top half,
   you should probably read the upper set of numbers, and vice-versa.
 - The ring is cut off at the horizon such that the shadow reaches the edge
   at sunrise and sunset. 

---

## How it works (brief)

The annular ring has the same tilt as Earth's equator relative to your
horizon, so the sun sweeps across it at a constant angular rate of 15°/hour
regardless of season.  The sphere's shadow therefore always falls on the
correct hour line — no seasonal correction is needed for the ring itself.

The hour markings are pre-rotated so that 12 o'clock is directly between
you and the sun at apparent solar noon, and adjusted for your time zone
offset relative to London (UTC) at render time.  A second set of markings
offset by one face (15°) is engraved on the underside for daylight saving
reference.

## Extension ideas
 - Cut grooves at the facet edges to make the grid more visible.
 - Check southern hemisphere logic
