import math

def _julian_day(year, month, day, hour=12):
    """
    Compute Julian Day Number for a given calendar date at a given hour UT.
    Uses the standard algorithm valid for dates after 1582-10-15 (Gregorian).
    """
    # Integer division helper
    if month <= 2:
        year -= 1
        month += 12
    A = int(year / 100)
    B = 2 - A + int(A / 4)
    return int(365.25 * (year + 4716)) + int(30.6001 * (month + 1)) + day + B - 1524.5 + (hour - 12) / 24.0


def _day_of_year_to_date(year, doy):
    """
    Convert 1-based day-of-year to (year, month, day).
    Ignores leap years as specified.
    """
    month_days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    remaining = doy
    for m, days in enumerate(month_days, start=1):
        if remaining <= days:
            return year, m, remaining
        remaining -= days
    # If doy > 365 just clamp to Dec 31
    return year, 12, 31


def _solar_geometry(year, doy):
    """
    Core solar geometry calculation.  Returns a dict with intermediate and
    final values so both EoT and declination can be extracted cleanly.

    All angular arithmetic is done in degrees; trig helpers convert as needed.
    """
    # --- helpers -----------------------------------------------------------
    def sind(d):  return math.sin(math.radians(d))
    def cosd(d):  return math.cos(math.radians(d))
    def atand2(y, x): return math.degrees(math.atan2(y, x))

    # --- Julian century from J2000.0 (noon, 1 Jan 2000) ------------------
    y, m, d = _day_of_year_to_date(year, doy)
    JD = _julian_day(y, m, d, hour=12)          # noon UT on that day
    T  = (JD - 2451545.0) / 36525.0             # Julian centuries

    # --- Mean elements -----------------------------------------------------
    L0 = (280.46646 + 36000.76983 * T) % 360    # mean longitude (deg)
    M  = (357.52911 + 35999.05029 * T) % 360    # mean anomaly   (deg)

    # --- Equation of centre (Sun) ------------------------------------------
    C  = ( (1.9146 - 0.004817 * T - 0.000014 * T**2) * sind(M)
         + (0.019993 - 0.000101 * T)            * sind(2 * M)
         + 0.000290                             * sind(3 * M) )

    # --- True / apparent longitude -----------------------------------------
    L_true   = L0 + C                           # true longitude
    Omega    = (125.04 - 1934.136 * T) % 360    # Moon's ascending node
    lam      = L_true - 0.00569 - 0.00478 * sind(Omega)   # apparent longitude

    # --- Obliquity (corrected for nutation) --------------------------------
    eps0     = 23.439291 - 0.0130042 * T        # mean obliquity
    eps      = eps0 + 0.00256 * cosd(Omega)     # corrected obliquity

    # --- Right ascension ---------------------------------------------------
    # atan2 gives [-180, 180]; we need alpha in the same 360° quadrant as lam.
    alpha    = atand2(cosd(eps) * sind(lam), cosd(lam))   # [-180, 180]
    # Shift alpha into [0, 360) for the modular subtraction below
    alpha_360 = alpha % 360

    # --- Equation of Time (degrees, then minutes) -------------------------
    # EoT = mean_solar_noon - apparent_solar_noon  (in angular units)
    #      = L0 - 0.0057183 - alpha   (mod 360, wrapped to [-180, 180])
    eot_deg  = (L0 - 0.0057183 - alpha_360) % 360
    if eot_deg > 180:
        eot_deg -= 360                          # wrap to [-180, 180]
    eot_min  = eot_deg * 4.0                    # 1 degree = 4 minutes of time

    # --- Declination -------------------------------------------------------
    decl     = math.degrees(math.asin(sind(eps) * sind(lam)))

    return {
        "T": T, "JD": JD,
        "L0": L0, "M": M, "C": C,
        "L_true": L_true, "Omega": Omega, "lam": lam,
        "eps": eps, "alpha": alpha,
        "eot_deg": eot_deg, "eot_min": eot_min,
        "declination": decl,
    }


# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------

def equation_of_time(year, doy):
    """
    Return the Equation of Time in **minutes** for a given year and
    day-of-year (1 = Jan 1, 365 = Dec 31).

    Positive EoT means the apparent sun is *ahead* of mean sun
    (sundial is fast relative to clock).

    Algorithm: VSOP-lite via Meeus, "Astronomical Algorithms" ch. 28.
    Accuracy: better than ±30 seconds for dates 1900-2100.
    """
    return _solar_geometry(year, doy)["eot_min"]


def solar_declination(year, doy):
    """
    Return the Sun's apparent declination in **degrees** for a given year
    and day-of-year.  Range is roughly [-23.44, +23.44].
    """
    return _solar_geometry(year, doy)["declination"]


def annual_eot_declination(year):
    """
    Iterate over 365 days of *year* (ignoring leap day) and return a list
    of 365 (x, y) pairs where:
        x = Equation of Time  (minutes)
        y = solar declination (degrees)

    This traces the analemma for that year.
    """
    return [(equation_of_time(year, d), solar_declination(year, d))
            for d in range(1, 366)]


# ---------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    # --- known reference values (verified against NOAA solar calculator) ----
    # Tolerances: ±0.5 min EoT, ±0.15 deg declination.
    # Algorithm accuracy is ~30 s / ~0.01 deg; margin covers NOAA rounding.
    checks = [
        # (year, doy, label,                       eot_min,  decl_deg)
        (2024,   1,  "Jan  1 – near solstice",     -3.09,   -23.059),
        (2024,  43,  "Feb 12 – EoT minimum",      -14.20,   -13.931),
        (2024, 106,  "Apr 15 – EoT zero (spring)", +0.21,   +10.223),
        (2024, 164,  "Jun 12 – EoT zero (early)",  -0.09,   +23.268),
        (2024, 173,  "Jun 21 – summer solstice",   -2.03,   +23.434),
        (2024, 245,  "Sep  1 – EoT zero (autumn)", +0.31,    +7.809),
        (2024, 308,  "Nov  3 – EoT maximum",      +16.44,   -15.455),
        (2024, 356,  "Dec 21 – winter solstice",   +1.44,   -23.437),
        (2024, 359,  "Dec 24 – EoT zero (winter)", -0.05,   -23.388),
    ]

    eot_tol  = 0.5    # minutes
    decl_tol = 0.15   # degrees

    print(f"{'Label':<35} {'EoT (min)':>10} {'Decl (deg)':>11}   "
          f"{'EoT err':>8} {'Decl err':>9}  {'Pass?'}")
    print("-" * 90)

    all_pass = True
    for year, doy, label, exp_eot, exp_decl in checks:
        eot  = equation_of_time(year, doy)
        decl = solar_declination(year, doy)
        eot_err  = eot  - exp_eot
        decl_err = decl - exp_decl
        ok = abs(eot_err) < eot_tol and abs(decl_err) < decl_tol
        if not ok:
            all_pass = False

        print(f"{label:<35} {eot:>+10.2f} {decl:>+11.3f}   "
              f"{eot_err:>+8.2f} {decl_err:>+9.3f}  {'✓' if ok else '✗ FAIL'}")

    print("-" * 90)
    print("All checks passed!" if all_pass else "SOME CHECKS FAILED.")

    # --- print a sample of the analemma data --------------------------------
    print("\n--- Sample analemma points for 2024 (every 30 days) ---")
    print(f"{'Day':>4}  {'EoT (min)':>10}  {'Decl (deg)':>11}")
    pairs = annual_eot_declination(2024)
    for i in range(0, 365, 30):
        eot, decl = pairs[i]
        print(f"{i+1:>4}  {eot:>+10.2f}  {decl:>+11.3f}")
