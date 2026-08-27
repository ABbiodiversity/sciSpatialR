# sciSpatialR (development version)

## Catalogue

* New `list_variables()` reports the bands each product documents —
  what they measure, their units, measurement scale, and valid range
  — so the variables available for extraction can be browsed without
  opening a readme. Defaults to every product; narrow with `theme`
  or `product`. Bands are a product-level fact, so a product with
  several variants contributes one set of rows rather than one per
  variant, and a product documenting no bands is listed with `band`
  `NA` so the gap stays visible.

* The scan follows the share's product/variant layout. Products sit
  directly under their ISO topic category, so the manifest's
  `sub_theme` column is gone — there is no longer an intermediate
  level to derive it from.
* A dataset's readme may be split in two, as the data management
  guide describes: a **product** record holding the title, licence,
  and citation, and a **variant** record holding the measured
  resolution, CRS, extent, and derivation of one processed copy.
  Splitting is optional; a product documented in a single readme is
  catalogued exactly as before.
* Where a product holds variant subfolders it contributes one row
  per variant rather than a row of its own, since the data lives in
  the variant. The two records are merged for that row, the variant
  winning on any field it fills in, so a variant row carries its own
  geometry alongside the product's identity. Previously a variant
  readme was catalogued as a separate, near-empty layer and the
  product row reported `n_files = 0`.
* New manifest columns `product_id`, `variant` (`NA` when the product
  has no variant folders), and `product_readme` (equal to `readme`
  unless the record is split).
* `layer_meta()` and `check_metadata()` read both halves of a split
  record, so a variant is no longer scored as missing the title and
  licence its product record carries.
* A variant folder holding data but no variant readme is now reported
  by `check_metadata()` instead of being treated as covered by its
  product's readme.
* Esri file geodatabases are counted as one vector dataset rather
  than as the internal tables a recursive listing finds inside them.
  A `.gdb` previously reported `n_files = 0` and `data_type = NA`,
  and `get_layer()` could not open one; an undocumented `.gdb` also
  went unreported, since its internals carry no recognised
  extension. `size_mb` still totals the bundle's real contents.


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
  GeoTIFFs. Only cells inside `aoi` are summarised, which defaults
  to the Alberta boundary the reference grid covers, so `n_total`
  counts the cells of the study area rather than the cells of the
  rectangle an export arrived on; `aoi = NULL` summarises the whole
  layer.
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
* The share's top-level `_temp` folder is skipped by every scan, so
  work in progress and staging copies are neither catalogued as
  layers nor reported as missing readmes by `check_metadata()`.
* `read_metadata()`, `as_metadata_row()`, `layer_meta()`, and
  `check_metadata()` parse and audit the readme files stored beside
  each layer.

## Documentation

* Four vignettes: harmonizing layers to the reference grid,
  inspecting layers, extracting covariates at survey locations, and
  working with the catalogue.
* A pkgdown site published at
  <https://ABbiodiversity.github.io/sciSpatialR/>.
