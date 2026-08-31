# Reference layers

The default reference bounds and grid that sciSpatialR harmonizes
to. Both are in **NAD83 / Alberta 10-TM (Forest), EPSG:3400** — the
CRS returned by `ab_crs()`.

Regenerate both with `data-raw/make_reference_layers.R`, which
requires access to the ABMI science share.

---

## `alberta.gpkg` — provincial boundary

Accessed with `ab_boundary()`; the default `boundary` argument of
`mask_to_boundary()`.

| | |
| --- | --- |
| Source | `\\ABMI-DATA2\science\spatial_data\boundaries\alberta\AB2020_provincial_boundary.shp` |
| Vintage | 2020 revision (source files dated 2023-12-04) |
| Geometry | 1 dissolved polygon |
| CRS | EPSG:3400 |
| Extent | 170844.33, 865133.52, 5425575.49, 6659344.34 (xmin, xmax, ymin, ymax) |
| Area | 6.6258e+11 m² (662,578 km²) |

Converted from the source shapefile set to a single-file GeoPackage.
The ArcGIS bookkeeping fields `Shape_Leng` and `Shape_Area` were
dropped, since they would go stale if the geometry were ever edited;
use `terra::expanse()` for area.

---

## `grid_1km.tif` — 1 km reference grid

Accessed with `ab_grid()`; the default `ref` argument of
`check_alignment()`, `resample_to_grid()`, `aggregate_to_grid()`, and
the default `raster` argument of `harmonize_crs()`.

| | |
| --- | --- |
| Source | `\\ABMI-DATA2\science\spatial_data\location\GRID1SQKM_AB2020_gdb\GRID1SQKM_AB2020.gdb`, layer `Grid_1KM_revAB2020` |
| Vintage | 2020 revision (source files dated 2023-08-30 / 2023-09-13) |
| CRS | EPSG:3400 |
| Dimensions | 1234 rows × 695 columns (857,630 cells) |
| Resolution | 1000 m × 1000 m |
| Extent | 170616.1822, 865616.1822, 5425532.4311, 6659532.4311 (xmin, xmax, ymin, ymax) |
| Values | `1` for the 664,762 cells of the source grid; `NA` elsewhere |
| Storage | `INT1U`, NoData 0, DEFLATE compressed (~7 KB) |

### Why a raster, not the source polygons

The source file geodatabase is roughly 340 MB — unsuitable for
version control — and every harmonization function in this package
consumes the reference grid as a `SpatRaster`. The template is
therefore built from the grid's own lattice rather than being
re-derived independently.

### Alignment guarantee

The template is snapped to the corner coordinates of the source
polygons, so a cell's raster row and column reproduce its source
`GRID_LABEL` (`"<row>_<col>"`, row 1 at the north edge, column 1 at
the west edge). The build script asserts that the anchor recovered
from several full-size cells agrees to within 1e-6 m, and that the
count of non-`NA` cells equals the 664,762 features in the source
layer.

Note that source cells along the provincial boundary are clipped
polygons of less than 1 km² (`GridArea` in the geodatabase), whereas
every raster cell is a full 1 km². Area-weighted work on edge cells
should go back to the source polygons.

### Not included

The geodatabase also holds `Grid_10KM_revAB2020` and the
`linkid_1km_to_10km` lookup, which are not packaged here. They remain
on the network share, in the source geodatabase listed above.

The raster shipped here is also catalogued on the share at
`\\ABMI-DATA2\science\spatial_data\location\GRID1SQKM_AB2020_raster\`
(as `GRID1SQKM_AB2020.tif`), with a `readme.txt` recording its
lineage from the geodatabase.
