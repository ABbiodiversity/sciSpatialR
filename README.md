# sciSpatialR
![In Development](https://img.shields.io/badge/Status-In%20Development-yellow)
![Lifecycle](https://img.shields.io/badge/Lifecycle-Experimental-orange)
![Languages](https://img.shields.io/badge/Languages-R-blue)


## Table of Contents
- [About](#about)
- [Installation](#installation)
- [Reference layers](#reference-layers)
- [Catalogue](#catalogue)
- [Functions](#functions)
- [Contact](#contact)

---

## About

**sciSpatialR** is an R package with tools for harmonising
spatial layers and extracting covariates to point locations for
Alberta-focused biodiversity and species distribution modelling
workflows.

---

## Installation

```r
# Install from GitHub (requires remotes)
remotes::install_github("bgcasey/sciSpatialR")
```

---

## Reference layers

Harmonisation defaults to the Alberta provincial boundary and the
ABMI 1 km grid, both in **NAD83 / Alberta 10-TM (Forest),
EPSG:3400**. Both ship with the package, so the harmonisation
functions need only the layer being harmonised — layers processed
with this package share one CRS, extent, resolution, and origin
unless a caller opts out.

| Accessor | Returns |
|---|---|
| `ab_crs()` | `"EPSG:3400"` — the default CRS |
| `ab_boundary()` | Alberta provincial boundary (2020 revision), one dissolved polygon |
| `ab_grid()` | ABMI 1 km reference grid, 1234 × 695 cells of 1000 m |

```r
library(sciSpatialR)

# Harmonise a layer onto the default grid and clip to Alberta
harmonised <- resample_to_grid(my_raster)
harmonised <- mask_to_boundary(harmonised)

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

```r
library(sciSpatialR)

list_layers()                       # everything catalogued
list_layers(theme = "elevation")    # one theme
list_themes()                       # topic categories and counts

# Find layers by what they are rather than where they live
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

**Known gap:** the metadata template has no CRS element, so
`find_layer(crs = )` matches only the few readmes that record one.
Either add a CRS field to the template or read it from the file
headers.

---

## Functions

| Domain | Function | Description |
|---|---|---|
| Reference Layers | `ab_crs()` | Default CRS for Alberta workflows (`EPSG:3400`) |
| Reference Layers | `ab_boundary()` | Alberta provincial boundary; default bound for masking |
| Reference Layers | `ab_grid()` | ABMI 1 km reference grid; default target for harmonisation |
| Input and Validation | `check_alignment()` | Test CRS, extent, resolution, and origin congruence against a reference grid |
| Harmonization | `mask_to_boundary()` | Mask to Alberta (default), natural regions, or a user-supplied polygon |
| Harmonization | `resample_to_grid()` | Resample to reference grid; nearest neighbour enforced for categorical layers |
| Harmonization | `aggregate_to_grid()` | Coarsen to reference grid (mean/sum/max continuous; mode categorical) |
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

## Contact

For questions regarding the contents of this repository or data
access, please contact Dr. Brendan Casey at
brendan.casey@ualberta.ca.

