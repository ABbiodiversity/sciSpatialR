# sciSpatialR
![In Development](https://img.shields.io/badge/Status-In%20Development-yellow)
![Lifecycle](https://img.shields.io/badge/Lifecycle-Experimental-orange)
![Languages](https://img.shields.io/badge/Languages-R-blue)


## Table of Contents
- [About](#about)
- [Installation](#installation)
- [Reference layers](#reference-layers)
- [Functions](#functions)
- [Directory Structure](#directory-structure)
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
| Catalogue and Metadata | `list_layers()` | List catalogue contents |
| Catalogue and Metadata | `find_layer()` | Filter manifest by theme, year, extent, resolution, CRS |
| Catalogue and Metadata | `get_layer()` | Return SpatRaster or path from canonical layer name |
| Catalogue and Metadata | `layer_meta()` | Source, vintage, licence, caveats, contact |


---

## Contact

For questions regarding the contents of this repository or data
access, please contact Dr. Brendan Casey at
brendan.casey@ualberta.ca.

