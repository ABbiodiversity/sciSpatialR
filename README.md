# sciSpatialR
![In Development](https://img.shields.io/badge/Status-In%20Development-yellow)
![Lifecycle](https://img.shields.io/badge/Lifecycle-Experimental-orange)
![Languages](https://img.shields.io/badge/Languages-R-blue)


## Table of Contents
- [About](#about)
- [Installation](#installation)
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

## Functions

| Domain | Function | Description |
|---|---|---|
| Input and Validation | `check_alignment()` | Test CRS, extent, resolution, and origin congruence against a reference grid |
| Harmonization | `mask_to_boundary()` | Mask to Alberta, natural regions, or a user-supplied polygon |
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

