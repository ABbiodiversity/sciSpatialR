<!--
<img src="https://drive.google.com/uc?id=1fgYuG7jpnekZrkoL_PdVUnSiUFBFX-vI" alt="Logo" width="150" style="float: left; margin-right: 10px;">
-->

<img src="https://drive.google.com/uc?id=1szqLViKqTX5C1XF8uV7HbIst0i6Xvv7g" alt="Logo" width="300">

# sciSpatialR
![In Development](https://img.shields.io/badge/Status-In%20Development-yellow)
![Lifecycle](https://img.shields.io/badge/Lifecycle-Experimental-orange)
![Languages](https://img.shields.io/badge/Languages-R-blue)


## Table of Contents
- [About](#about)
- [Installation](#installation)
- [Reference layers](#reference-layers)
- [Inspecting layers](#inspecting-layers)
- [Extracting covariates](#extracting-covariates)
- [Catalogue](#catalogue)
- [Functions](#functions)
- [Licence](#licence)
- [Contact](#contact)

---

## About

**sciSpatialR** is an R package with tools for harmonizing
spatial layers and extracting covariates to point locations for
Alberta-focused biodiversity and species distribution modelling
workflows.

It is developed by and for the Alberta Biodiversity Monitoring
Institute (ABMI) and is intended for internal use; see
[Licence](#licence).

---

## Installation

```r
# Install from GitHub (requires remotes)
remotes::install_github("bgcasey/sciSpatialR")
```

---

## Reference layers

Harmonization defaults to the Alberta provincial boundary and the
ABMI 1 km grid, both in **NAD83 / Alberta 10-TM (Forest),
EPSG:3400**. Both ship with the package, so the harmonization
functions need only the layer being harmonized — layers processed
with this package share one CRS, extent, resolution, and origin
unless a caller opts out.

| Accessor | Returns |
|---|---|
| `ab_crs()` | `"EPSG:3400"` — the default CRS |
| `ab_boundary()` | Alberta provincial boundary (2020 revision), one dissolved polygon |
| `ab_grid()` | ABMI 1 km reference grid, 1234 × 695 cells of 1000 m |

```r
library(sciSpatialR)

# Harmonize a layer onto the default grid and clip to Alberta.
# The resampling method is chosen from the resolution ratio and
# reported on the console; pass `method` to override it.
harmonized <- resample_to_grid(my_raster)
harmonized <- mask_to_boundary(harmonized)

# Confirm an existing layer already aligns
check_alignment(my_raster)

# Override the defaults with your own reference grid
resample_to_grid(my_raster, ref = my_own_grid)
```

The grid is stored as a raster template snapped to the lattice of
the source polygons, so a cell's row and column reproduce its source
`GRID_LABEL`. Provenance, exact geometry, and caveats are documented
in [`inst/extdata/README.md`](inst/extdata/README.md); both layers
are rebuilt by
[`data-raw/make_reference_layers.R`](data-raw/make_reference_layers.R),
which needs access to the ABMI science share.

The reference layers, `check_alignment()`, and the harmonization
functions are walked through with worked examples in the
harmonization vignette — read it
[rendered on GitHub](docs/harmonization.md), or as
`vignette("harmonization", package = "sciSpatialR")`. Unlike the
catalogue vignette its examples are executed at build time, so the
output shown is real. Source:
[`vignettes/harmonization.Rmd`](vignettes/harmonization.Rmd).

---

## Inspecting layers

Three functions answer the questions asked of a layer before it is
trusted as a covariate: how much of it is missing, what values it
holds, and whether the pattern and clipping look right.

```r
# Cell counts, missingness, and value summaries — one row per layer,
# under a printed definition of each column
raster_stats(my_raster)
raster_stats(my_raster, quantiles = c(0.02, 0.5, 0.98))
raster_stats(my_raster, verbose = FALSE)   # table only

# Every GeoTIFF in a folder of exports, in one table
raster_stats("2_pipeline/gee_exports")

# Quick look: colour scale clamped to the 2nd–98th percentile,
# Alberta outline drawn over it
plot_raster(my_raster)
plot_raster(my_raster, na_col = "firebrick2")  # show missing cells

# A ggplot, so it composes and saves as one
p <- plot_raster(my_raster, main = "FABDEM") +
  ggplot2::labs(caption = "1 km, EPSG:3400")
ggplot2::ggsave("2_pipeline/fab_dem.png", p, width = 9, height = 6)

# The distribution behind that map
plot_hist(my_raster, bins = 100)
```

`raster_stats()` streams the raster with `terra::global()`, so
province-wide layers summarise without being loaded. The plots and
the `quantiles` argument need the values themselves, and sample
layers above `maxcell` on a regular lattice.

`raster_stats()` takes a `SpatRaster`, a raster path, or a directory
of GeoTIFFs; the two plot functions take one raster at a time and
both return a **ggplot** styled with `theme_science_map()` — save
with `ggsave()`, and swap the scale or theme by adding your own.
Multi-layer rasters are facetted. Both use the MetBrewer
"Hiroshige" ramp reversed (dark blue low, red high), reproduced in
the package rather than depended on.

All three are walked through, with figures, in the inspection
vignette — read it [rendered on GitHub](docs/inspection.md), or as
`vignette("inspection", package = "sciSpatialR")`. Like the
harmonization vignette its examples are executed at build time, so
the tables and maps shown are real. Source:
[`vignettes/inspection.Rmd`](vignettes/inspection.Rmd).

---

## Extracting covariates

Four functions turn harmonized layers into a modelling table — one
row per survey location, one column per covariate.

```r
sites <- harmonize_crs(sites)

# The value of the cell each point falls in
extract_points(chm, sites)

# Neighbourhood summaries at several scales in one call
extract_buffer(chm, sites, radii = c(1000, 5000), na.rm = TRUE)

# Class composition within a buffer, for a categorical layer
extract_proportion(land_cover, sites, radius = 5000)

# Attributes of the polygon each point falls in
extract_vector(sites, subregions, cols = "NRNAME")
```

The three raster functions take `sf` or `SpatVector` points,
reproject them to the raster when needed, and return a plain
`data.frame` — `bind = FALSE` returns just the extracted columns in
input row order, which is what makes one `cbind` at the end of a
script safe. `extract_vector()` is `sf` in, `sf` out, and reprojects
the polygons instead.

The walkthrough is in the extraction vignette — read it
[rendered on GitHub](docs/extraction.md), or as
`vignette("extraction", package = "sciSpatialR")`. Its examples are
executed at build time, so the tables shown are real. Source:
[`vignettes/extraction.Rmd`](vignettes/extraction.Rmd).

---

## Catalogue

The catalogue is the data share itself. `build_catalogue()` walks
`\\ABMI-DATA2\science\spatial_data`, parses the readme stored beside
each dataset, and assembles a manifest — so the catalogue can never
drift from the data, and documenting a dataset means editing its
readme rather than registering it somewhere.

Readmes follow the ABMI spatial metadata template, and folders follow
the ISO 19115 topic categories, both documented in
[`geospatial_catalog_and_management_guide`](https://github.com/bgcasey/geospatial_catalog_and_management_guide).

A walkthrough with worked examples is in the catalogue vignette —
read it [rendered on GitHub](docs/catalogue.md), or as
`vignette("catalogue", package = "sciSpatialR")` once the package is
installed with `build_vignettes = TRUE`. The source is
[`vignettes/catalogue.Rmd`](vignettes/catalogue.Rmd); `docs/catalogue.md`
is generated from it by [`data-raw/render_docs.R`](data-raw/render_docs.R)
and needs re-rendering whenever the vignette changes.

```r
library(sciSpatialR)

list_layers()                       # everything catalogued
list_themes()                       # topic categories and counts
list_layers(theme = "elevation")    # one theme


# Find layers by matadata
find_layer(keyword = "elevation")
find_layer(extent = c(-120, -110, 49, 60), resolution = c(0, 120))
find_layer(year = c(2020, 2024))

# Load one, or just locate it
twi  <- get_layer("topographic_wetness_index")
path <- get_layer("fab_dem", return_path = TRUE)
layer_files("grassland_inventory")

# Provenance, licence, and contact from the readme
layer_meta("fab_dem")
```

A layer is any folder holding a readme written to the dataset
template; short `Category` readmes mark theme folders and are read by
`list_themes()` instead. Datasets sit at whatever depth a theme needs
(`elevation/fab_dem`, `biota/vegetation/grassland_inventory`), so
layers are addressed by short name when unambiguous and by full id
(`elevation/fab_dem`) otherwise.

`check_metadata()` audits the share, reporting which required
template fields each readme is missing and which data folders have no
readme at all:

```r
check_metadata()                       # one row per layer
check_metadata(detail = TRUE)          # one row per missing field
```

The scan is cached per session; pass `refresh = TRUE` after the share
changes. Point the catalogue somewhere else — a mirror, a mapped
drive, or a local copy — with
`options(sciSpatialR.spatial_root = "...")` or the
`SCISPATIALR_SPATIAL_ROOT` environment variable.

### Adding a field to the template

Readmes are parsed generically, so a new field is readable as soon
as you write it — no code change. Any `Label: value` line is
captured, and sub-fields indented under a parent label are
namespaced by it:

```
Coordinate Reference System:
    Name: NAD83 / Alberta 10-TM (Forest)
    Authority Code: EPSG:3400
```

is reachable straight away as
`layer_meta("x")$coordinate_reference_system_authority_code`.

Becoming a **column** of the manifest — and so filterable by
`find_layer()` — is the one step that needs code: add the parsed key
to `.meta_field_map` in [`R/metadata.R`](R/metadata.R). Add it to
`.meta_required` in the same file to make `check_metadata()` count it
towards completeness. Nothing in `R/catalogue.R` needs touching.

The `Coordinate Reference System` block above is already wired up,
giving the `crs`, `crs_name`, `datum`, and `vertical_crs` columns:

```r
find_layer(crs = "3400")            # by authority code
find_layer(crs = "Alberta 10-TM")   # or by name
```

**Known gap:** no readme on the share carries the block yet, so
`crs` is `NA` for all 15 catalogued layers until they are
backfilled. Several readmes also leave the bounding coordinates
blank, which excludes them from `extent` filters.

---

## Functions

| Domain | Function | Description |
|---|---|---|
| Reference Layers | `ab_crs()` | Default CRS for Alberta workflows (`EPSG:3400`) |
| Reference Layers | `ab_boundary()` | Alberta provincial boundary; default bound for masking |
| Reference Layers | `ab_grid()` | ABMI 1 km reference grid; default target for harmonization |
| Input and Validation | `check_alignment()` | Test CRS, extent, resolution, and origin congruence against a reference grid |
| Inspection | `raster_stats()` | Per-layer cell counts, missingness, and value summaries |
| Inspection | `plot_raster()` | Quick-look ggplot map with a quantile-stretched colour scale and boundary overlay |
| Inspection | `plot_hist()` | Histogram of cell values as a ggplot, bars filled along the value ramp |
| Inspection | `theme_science_map()` | Minimal ggplot2 theme applied to package maps |
| Harmonization | `mask_to_boundary()` | Mask to Alberta (default), natural regions, or a user-supplied polygon |
| Harmonization | `resample_to_grid()` | Align to reference grid; method chosen from the resolution ratio and whether the layer is categorical, and reported |
| Harmonization | `harmonize_crs()` | Transform points to raster CRS; warn if raster reprojection would be implied |
| Extraction | `extract_points()` | Point-in-cell raster extraction (core function) |
| Extraction | `extract_vector()` | Point-in-polygon attribute join (natural subregion, LUF, ownership, watershed) |
| Extraction | `extract_proportion()` | Class proportions within buffer for categorical layers; zero-filled absent classes |
| Extraction | `extract_buffer()` | Summary statistic within one or more radii; vectorised over radii |
| Catalogue and Metadata | `spatial_root()` | Location of the data share; overridable by option or env var |
| Catalogue and Metadata | `build_catalogue()` | Scan the share and parse every dataset readme into a manifest |
| Catalogue and Metadata | `list_layers()` | List catalogue contents, optionally by theme |
| Catalogue and Metadata | `list_themes()` | ISO 19115 topic categories and layer counts |
| Catalogue and Metadata | `find_layer()` | Filter manifest by theme, keyword, year, extent, resolution, CRS |
| Catalogue and Metadata | `get_layer()` | Return SpatRaster, SpatVector, or path from a layer name |
| Catalogue and Metadata | `layer_files()` | List the data files in a layer folder |
| Catalogue and Metadata | `layer_meta()` | Source, vintage, licence, caveats, contact |
| Catalogue and Metadata | `read_metadata()` | Parse one readme into structured fields |
| Catalogue and Metadata | `as_metadata_row()` | Flatten parsed metadata to a one-row data.frame |
| Catalogue and Metadata | `check_metadata()` | Audit metadata completeness across the share |


---

## Licence

Copyright (c) 2026 Alberta Biodiversity Monitoring Institute. All
rights reserved.

This package was developed for ABMI and is provided for internal use
only. ABMI staff, students, and collaborators may use and modify it
for ABMI work; redistribution outside that scope requires written
permission. The spatial data the package reads is licensed
separately, under the terms recorded in each layer's metadata and by
the original data providers. See [LICENSE](LICENSE) for the full
terms.

---

## Contact

For questions regarding the contents of this repository or data
access, please contact Dr. Brendan Casey at
brendan.casey@ualberta.ca.

