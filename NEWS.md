# sciSpatialR 0.1.0

First version. Everything below is new.

## Reference layers

* `ab_crs()`, `ab_boundary()`, and `ab_grid()` return the project
  CRS (NAD83 / Alberta 10-TM, EPSG:3400), the 2020 provincial
  boundary, and the ABMI 1 km reference grid. The boundary and grid
  ship with the package, so the harmonization functions need only
  the layer being harmonized.
* The grid template is snapped to the lattice of the ABMI's 1 km
  grid polygons, so a cell's raster row and column reproduce its
  source `GRID_LABEL`.

## Harmonization

* `check_alignment()` compares a layer against the reference on
  CRS, extent, resolution, and origin, and returns the result
  invisibly as a named logical vector so it can gate a pipeline.
* `resample_to_grid()` snaps a layer onto the reference lattice,
  choosing the resampling method from the resolution ratio and
  whether the layer is categorical, and reporting what it picked.
  It errors rather than silently returning an empty layer when the
  CRS does not already match.
* `mask_to_boundary()` clips to Alberta by default, or to a
  supplied polygon; `inverse = TRUE` keeps the outside instead.
* `harmonize_crs()` transforms points to the raster CRS and warns
  when raster reprojection would be implied.

## Extraction

* `extract_points()` for point-in-cell values, `extract_buffer()`
  for summary statistics within one or more radii,
  `extract_proportion()` for class composition within a buffer, and
  `extract_vector()` for point-in-polygon attribute joins.
* All four return columns in input row order, so `bind = FALSE`
  results can be combined with a single `cbind()`.

## Inspection

* `raster_stats()` reports per-layer cell counts, missingness, and
  value summaries for a `SpatRaster`, a path, or a directory of
  GeoTIFFs.
* `plot_raster()` and `plot_hist()` return ggplot objects, with the
  colour scale clamped to central quantiles by default so a handful
  of extreme cells cannot flatten the pattern.
* `theme_science_map()` is exported for other figures in a project.

## Catalogue and metadata

* `build_catalogue()` scans the ABMI spatial data share and parses
  every dataset readme into a manifest; `list_themes()`,
  `list_layers()`, `find_layer()`, `get_layer()`, and
  `layer_files()` query and retrieve from it.
* `spatial_root()` reports where the catalogue reads from and is
  overridable by option or environment variable.
* `read_metadata()`, `as_metadata_row()`, `layer_meta()`, and
  `check_metadata()` parse and audit the readme files stored beside
  each layer.

## Documentation

* Four vignettes: harmonizing layers to the reference grid,
  inspecting layers, extracting covariates at survey locations, and
  working with the catalogue.
* A pkgdown site published at
  <https://ABbiodiversity.github.io/sciSpatialR/>.
