Harmonizing layers to the reference grid
================

``` r
library(sciSpatialR)
library(terra)
library(sf)
```

## One grid, three questions

Covariates arrive from wherever they were published — a global DEM in
geographic coordinates, a national land cover product at 30 m, a
provincial polygon layer. Before any of them can be stacked, extracted
from, or compared, they have to agree on four properties: coordinate
reference system, extent, resolution, and origin.

This package answers that with a single default target. Every
harmonization function takes `ref = ab_grid()` and every masking call
defaults to Alberta, so the common case needs no arguments and layers
processed with the package align by construction rather than by
convention.

The workflow is three questions, in order:

1.  **What am I aligning to?** The reference layers — `ab_crs()`,
    `ab_boundary()`, `ab_grid()`.
2.  **Does this layer already align?** `check_alignment()`.
3.  **How do I make it align?** `harmonize_crs()`, `resample_to_grid()`,
    `aggregate_to_grid()`, `mask_to_boundary()`.

## The reference layers

### `ab_crs()`

The CRS everything harmonizes to: NAD83 / Alberta 10-TM (Forest).

``` r
ab_crs()
#> [1] "EPSG:3400"
```

It is a projected CRS in metres, which is what makes the rest of the
package sane — resolutions, buffer radii, and areas are all in the same
unit, and no function has to reason about degrees varying with latitude.

### `ab_grid()`

The ABMI 1 km reference grid, returned as a template `SpatRaster`:

``` r
ref <- ab_grid()
ref
#> class       : SpatRaster 
#> dimensions  : 1234, 695, 1  (nrow, ncol, nlyr)
#> resolution  : 1000, 1000  (x, y)
#> extent      : 170616.2, 865616.2, 5425532, 6659532  (xmin, xmax, ymin, ymax)
#> coord. ref. : NAD83 / Alberta 10-TM (Forest) (EPSG:3400) 
#> source      : grid_1km.tif 
#> name        : grid_1km 
#> min value   :        1 
#> max value   :        1
```

Cells covering Alberta hold `1`; everything else is `NA`. Of the 857,630
cells in the rectangle, the province occupies:

``` r
global(ref, "notNA")
#>           notNA
#> grid_1km 664762
```

Two properties are worth knowing before you rely on it.

The template is *snapped to the lattice of the source grid polygons*,
not to a round number. That is why the origin is an odd pair of values
rather than `0, 0`:

``` r
origin(ref)
#> [1] -383.8178 -467.5689
```

The payoff is that a cell’s raster row and column reproduce its source
`GRID_LABEL` (`"<row>_<col>"`, row 1 at the north edge, column 1 at the
west edge), so raster work and the ABMI grid tabulations refer to the
same cells. Snapping the template to a tidier origin would break that
correspondence.

The second property is a caveat: every raster cell is a full 1 km²,
whereas the source polygons along the provincial boundary are clipped to
less than that. Area-weighted work on edge cells should go back to the
source polygons on the share. Provenance for both layers is in
[`inst/extdata/README.md`](https://github.com/bgcasey/sciSpatialR/blob/main/inst/extdata/README.md).

### `ab_boundary()`

The 2020 provincial boundary as one dissolved polygon, in the same CRS:

``` r
ab_boundary()
#>  class       : SpatVector 
#>  geometry    : polygons 
#>  dimensions  : 1, 0  (geometries, attributes)
#>  extent      : 170844.3, 865133.5, 5425575, 6659344  (xmin, xmax, ymin, ymax)
#>  source      : alberta.gpkg
#>  coord. ref. : NAD83 / Alberta 10-TM (Forest) (EPSG:3400)
```

It carries no attributes on purpose — it exists to clip, not to join to.
Layers are read from disk on each call rather than cached, because terra
objects hold external pointers that do not survive a session; both files
are small enough that re-reading is cheap.

## Checking alignment

`check_alignment()` compares a layer against the reference on all four
properties and messages the result. The reference grid trivially agrees
with itself:

``` r
check_alignment(ref)
#> CRS: OK
#> Extent: OK
#> Resolution: OK
#> Origin: OK
```

Something freshly downloaded usually does not. Here is a stand-in for
one — a synthetic temperature surface in geographic coordinates, built
so this vignette needs no external data:

``` r
src <- rast(
  nrows = 120, ncols = 90,
  xmin = -121, xmax = -109,
  ymin = 48.5, ymax = 60.5,
  crs  = "EPSG:4326"
)
src <- 25 - 0.55 * init(src, "y") + 2 * sin(init(src, "x") / 2)
names(src) <- "mean_temp"
src
#> class       : SpatRaster 
#> dimensions  : 120, 90, 1  (nrow, ncol, nlyr)
#> resolution  : 0.1333333, 0.1  (x, y)
#> extent      : -121, -109, 48.5, 60.5  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326) 
#> source(s)   : memory
#> name        :   mean_temp 
#> min value   : -10.2473076 
#> max value   :   0.2970103
```

``` r
check_alignment(src)
#> CRS: MISMATCH — x and ref have different CRS.
#> Extent: MISMATCH.
#> Resolution: MISMATCH.
#> Origin: MISMATCH.
```

Four mismatches, which is the normal starting point. The function
returns the results invisibly as a named logical vector, so it can gate
a pipeline as well as inform a human:

``` r
ok <- check_alignment(src, verbose = FALSE)
ok
#>        crs     extent resolution     origin 
#>      FALSE      FALSE      FALSE      FALSE
all(ok)
#> [1] FALSE
```

`sf` objects are accepted too, but only the CRS is meaningful for them —
a point layer has no resolution or origin to compare, and those checks
are skipped rather than silently reported as failures:

``` r
pts <- st_as_sf(
  data.frame(
    site = c("calgary", "edmonton"),
    x    = c(-114.07, -113.49),
    y    = c(51.05, 53.55)
  ),
  coords = c("x", "y"),
  crs    = 4326
)
check_alignment(pts)
#> CRS: MISMATCH — x and ref have different CRS.
#> Extent, resolution, and origin checks skipped (x is an sf object).
```

Extent, resolution, and origin are compared with a tolerance (`tol`,
default `1e-6`) rather than exactly, since coordinates that have been
through a projection rarely round-trip bit-for-bit.

## Get the CRS right first

**This is the step to not skip.** `resample_to_grid()` wraps
`terra::resample()`, which aligns a layer to a template but does *not*
reproject. Handed a layer in the wrong CRS, it treats the reference
extent as though it were in the layer’s own coordinates — where nothing
overlaps — and returns a raster of the right shape holding nothing at
all:

``` r
bad <- resample_to_grid(src)          # src is still EPSG:4326
global(bad, "notNA")
#>           notNA
#> mean_temp     0
crs(bad, describe = TRUE)$name
#> [1] "WGS 84"
```

No error and no warning: 857,630 cells, none of them data, still
carrying the source CRS. Running `check_alignment()` first is what
catches this, and reprojecting is what fixes it. For rasters that means
`terra::project()`, choosing the method to suit the measurement:

``` r
src_ab <- project(src, ab_crs())      # bilinear, fine for continuous
check_alignment(src_ab, verbose = FALSE)[["crs"]]
#> [1] TRUE
```

The CRS now agrees; the grid geometry still does not, which is what
`resample_to_grid()` is for.

## Harmonizing rasters

### `resample_to_grid()`

With the CRS settled, resampling snaps the layer onto the reference
lattice:

``` r
temp_1km <- resample_to_grid(src_ab)
temp_1km
#> class       : SpatRaster 
#> dimensions  : 1234, 695, 1  (nrow, ncol, nlyr)
#> resolution  : 1000, 1000  (x, y)
#> extent      : 170616.2, 865616.2, 5425532, 6659532  (xmin, xmax, ymin, ymax)
#> coord. ref. : NAD83 / Alberta 10-TM (Forest) (EPSG:3400) 
#> source(s)   : memory
#> varname     : grid_1km 
#> name        :   mean_temp 
#> min value   : -10.0464020 
#> max value   :   0.1029203
aligned <- check_alignment(temp_1km, verbose = FALSE)
aligned
#>        crs     extent resolution     origin 
#>       TRUE       TRUE       TRUE       TRUE
```

All four properties now agree, which is the whole point: any two layers
put through this call can be stacked, differenced, or extracted from
together without further thought.

The default method is `"bilinear"`, which is right for continuous
measurements and wrong for class codes. Interpolating between land cover
classes 1 and 3 produces a 2 that means nothing. Build a categorical
layer from the same surface to see it:

``` r
zones <- classify(
  src,
  matrix(
    c(-Inf, -8, 1,
        -8, -5, 2,
        -5, -2, 3,
        -2, Inf, 4),
    ncol = 3, byrow = TRUE
  )
)
names(zones) <- "zone"
zones_ab <- project(zones, ab_crs(), method = "near")
sort(unique(values(zones_ab, na.rm = TRUE)))
#> [1] 1 2 3 4
```

Resampled with the default method, those four codes become a continuum:

``` r
wrong <- resample_to_grid(zones_ab)
length(unique(values(wrong, na.rm = TRUE)))
#> [1] 26056
range(values(wrong, na.rm = TRUE))
#> [1] 1 4
```

`categorical = TRUE` forces nearest-neighbour and keeps the codes
intact:

``` r
zone_1km <- resample_to_grid(zones_ab, categorical = TRUE)
sort(unique(values(zone_1km, na.rm = TRUE)))
#> [1] 1 2 3 4
```

The flag is a guardrail, not new behaviour — it is equivalent to
`method = "near"`, but it says *why* nearest neighbour was chosen, which
survives review better than a bare method string.

### `aggregate_to_grid()`

Resampling a 30 m layer straight to 1 km samples one fine cell per
coarse cell and discards the other roughly 1,100. When the coarse value
should summarise the fine cells rather than sample them — mean canopy
height, total road length, dominant cover class — aggregate instead.

`aggregate_to_grid()` derives an integer factor from the resolution
ratio and calls `terra::aggregate()`. Take a window of the reference
grid and a 250 m layer nested inside it:

``` r
win  <- crop(ref, ext(400000, 500000, 5800000, 5900000))
fine <- disagg(win, fact = 4)         # 250 m, nested in win
fine <- init(fine, "y")               # a surface to summarise
res(fine)
#> [1] 250 250
```

``` r
coarse <- aggregate_to_grid(fine, win)
res(coarse)
#> [1] 1000 1000
check_alignment(coarse, win, verbose = FALSE)[["origin"]]
#> [1] TRUE
```

`fun` chooses the summary — `"mean"` by default, or `"sum"`, `"max"`,
`"min"`, or any function `terra::aggregate()` accepts. For class codes,
`categorical = TRUE` forces the modal class, since a mean of class codes
is meaningless in the same way a bilinear interpolation of them is:

``` r
fine_cat  <- (init(fine, "row") - 1) %/% 100 + 1   # four bands
modal_1km <- aggregate_to_grid(fine_cat, win, categorical = TRUE)
sort(unique(values(modal_1km, na.rm = TRUE)))
#> [1] 1 2 3 4
```

Two limitations follow from aggregation working by factor.

**The ratio has to be an integer.** A 300 m layer does not divide into 1
km, so the factor is rounded and the result lands at 900 m with a
warning rather than silently pretending to be 1 km:

``` r
odd <- rast(
  xmin = 400000, xmax = 500200,
  ymin = 5800000, ymax = 5900200,
  res  = 300, crs = ab_crs()
)
odd <- init(odd, "y")
res(odd)
#> [1] 300 300
agg_odd <- aggregate_to_grid(odd, win)
#> Warning in aggregate_to_grid(odd, win): Resolution ratio is not an
#> exact integer multiple. Using factor = 3 x 3. Results may not
#> align perfectly with `ref`.
res(agg_odd)
#> [1] 900 900
```

**Aggregation preserves the input’s origin.** The factor fixes
resolution, not position, so a layer offset from the reference lattice
aggregates to the right cell size in the wrong place:

``` r
shifted     <- shift(fine, dx = 125, dy = 125)
agg_shifted <- aggregate_to_grid(shifted, win)

off <- check_alignment(agg_shifted, win, verbose = FALSE)
off
#>        crs     extent resolution     origin 
#>       TRUE      FALSE       TRUE      FALSE
```

Resolution and CRS pass; extent and origin do not. The fix is to
aggregate for the summary statistic, then resample to snap:

``` r
snapped <- resample_to_grid(agg_shifted, win)
all(check_alignment(snapped, win, verbose = FALSE))
#> [1] TRUE
```

Aggregate-then-resample is the general recipe for a fine layer that is
not already nested in the reference lattice: aggregation does the
statistically meaningful part, resampling does the alignment. Always
confirm with `check_alignment()` rather than assuming.

### Which one to use

| Situation | Call |
|----|----|
| Layer coarser than, or near, 1 km | `resample_to_grid()` |
| Layer much finer, and the coarse value should summarise the fine cells | `aggregate_to_grid()`, then `resample_to_grid()` if it does not align |
| Class codes, either way | add `categorical = TRUE` |
| Wrong CRS | `terra::project()` first — neither function reprojects |

### `mask_to_boundary()`

Harmonizing to the grid gives a layer the right geometry but not the
right footprint: a reprojected national product still carries values
across almost the whole reference rectangle, including well outside
Alberta.

``` r
global(temp_1km, "notNA")
#>            notNA
#> mean_temp 852260
```

Masking clips it to the province. The default boundary is `"alberta"`,
so the common call takes no second argument:

``` r
temp_ab <- mask_to_boundary(temp_1km)
global(temp_ab, "notNA")
#>            notNA
#> mean_temp 664749
```

`inverse = TRUE` keeps the outside instead — useful for checking what a
clip removed, or for building an outside-Alberta mask:

``` r
global(mask_to_boundary(temp_1km, inverse = TRUE), "notNA")
#>        notNA
#> layer 187511
```

Any `SpatVector` or `sf` polygon can be passed directly, and it is
reprojected to the raster’s CRS when needed, so a study-area polygon in
whatever CRS it arrived in works without preparation:

``` r
study_area <- vect(
  ext(400000, 500000, 5800000, 5900000),
  crs = ab_crs()
)
global(mask_to_boundary(temp_1km, study_area), "notNA")
#>           notNA
#> mean_temp 10201

study_ll <- project(study_area, "EPSG:4326")
global(mask_to_boundary(temp_1km, study_ll), "notNA")
#>           notNA
#> mean_temp 10201
```

Same count from both: the reprojection happens internally rather than
being left to the caller. Unknown shortcuts fail loudly and list what is
valid:

``` r
mask_to_boundary(temp_1km, "saskatchewan")
#> Error in .load_builtin_boundary(boundary): Unknown boundary shortcut 'saskatchewan'. Valid shortcuts: alberta, natural_regions.
```

`"natural_regions"` is recognised as a shortcut but the layer is not yet
packaged, so it errors with that explanation and asks for a polygon
instead. Until it ships, pull the natural regions layer from the
catalogue — `get_layer("natural_regions_subregions_of_alberta")` — and
pass it directly.

## Harmonizing points

Points get their own function, because for point data the right answer
is almost always to move the points rather than the raster. Reprojecting
a raster resamples it and introduces artefacts; reprojecting points is
exact.

``` r
pts_ab <- harmonize_crs(pts)
#> Reprojecting `points` to the reference grid CRS (NAD83 / Alberta 10-TM (Forest)).
st_crs(pts_ab)$input
#> [1] "NAD83 / Alberta 10-TM (Forest)"
st_coordinates(pts_ab)
#>             X       Y
#> [1,] 565160.9 5653533
#> [2,] 600000.8 5932142
```

Note the message. The reporting distinguishes two cases, and the
distinction is deliberate:

- Left at the default — the package reference grid — reprojection is the
  intended outcome, so it is reported as a **message**.
- Given a raster the caller supplied, a CRS mismatch may well be a
  mistake, and reprojecting the raster might have been the better
  choice, so it **warns**.

``` r
utm <- rast(
  nrows = 10, ncols = 10, crs = "EPSG:32612",
  xmin = 300000, xmax = 400000,
  ymin = 5600000, ymax = 5700000
)
pts_utm <- harmonize_crs(pts, utm)
#> Warning in harmonize_crs(pts, utm): CRS of `points` differs from
#> `raster`. Reprojecting `points` to raster CRS (WGS 84 / UTM zone
#> 12N). Consider whether the raster should have been reprojected
#> instead.
st_crs(pts_utm)$input
#> [1] "WGS 84 / UTM zone 12N"
```

Points already in the target CRS are returned untouched, with no message
and no needless transformation, so the call is safe to leave in a
pipeline that runs on both raw and prepared inputs:

``` r
identical(harmonize_crs(pts_ab), pts_ab)
#> [1] TRUE
```

Pass `warn = FALSE` to silence both, once the reprojection is a known,
intended step.

## A worked pipeline

Everything above, as it would appear in a covariate-preparation script —
a downloaded continuous layer and a point set, both brought onto the
reference grid:

``` r
# 1. Check what arrived
check_alignment(src)
#> CRS: MISMATCH — x and ref have different CRS.
#> Extent: MISMATCH.
#> Resolution: MISMATCH.
#> Origin: MISMATCH.

# 2. CRS first; nothing else works until this passes
covariate <- project(src, ab_crs())

# 3. Snap to the reference grid
covariate <- resample_to_grid(covariate)

# 4. Clip to Alberta
covariate <- mask_to_boundary(covariate)

# 5. Confirm, do not assume
check_alignment(covariate)
#> CRS: OK
#> Extent: OK
#> Resolution: OK
#> Origin: OK

# 6. Bring the points into the same CRS
sites <- harmonize_crs(pts)
#> Reprojecting `points` to the reference grid CRS (NAD83 / Alberta 10-TM (Forest)).
```

``` r
covariate
#> class       : SpatRaster 
#> dimensions  : 1234, 695, 1  (nrow, ncol, nlyr)
#> resolution  : 1000, 1000  (x, y)
#> extent      : 170616.2, 865616.2, 5425532, 6659532  (xmin, xmax, ymin, ymax)
#> coord. ref. : NAD83 / Alberta 10-TM (Forest) (EPSG:3400) 
#> source(s)   : memory
#> varname     : grid_1km 
#> name        :   mean_temp 
#> min value   : -9.99693680 
#> max value   :  0.04908441
```

From here `extract_points()` and the other extraction functions take
over; they are covered separately.

## Working off the default grid

Every reference default is an ordinary argument, so a project on a
different grid — a 250 m analysis, a single natural subregion, work
outside Alberta — overrides it in place:

``` r
own_ref <- rast(
  xmin = 400000, xmax = 500000,
  ymin = 5800000, ymax = 5900000,
  res  = 250, crs = ab_crs()
)
own <- resample_to_grid(src_ab, ref = own_ref)
all(check_alignment(own, ref = own_ref, verbose = FALSE))
#> [1] TRUE
```

`ref` is the argument for `check_alignment()`, `resample_to_grid()`, and
`aggregate_to_grid()`; `raster` for `harmonize_crs()`; `boundary` for
`mask_to_boundary()`. The package’s own reference layers are just the
defaults those arguments carry, not a requirement — but note that the
guarantee at the top of this vignette weakens accordingly. Layers
harmonized to different references align with each other only if you
have arranged it.

## Known gaps

`resample_to_grid()` and `aggregate_to_grid()` do not reproject, and
`resample_to_grid()` fails silently when handed a mismatched CRS — an
all-`NA` raster rather than an error, as shown above. Calling
`check_alignment()` first is currently the defence; the functions could
reasonably reproject on the fly, or at least refuse.

`"natural_regions"` is a recognised `mask_to_boundary()` shortcut with
no packaged layer behind it yet.
