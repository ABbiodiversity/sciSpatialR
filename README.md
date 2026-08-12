# sciSpatialR
![In Development](https://img.shields.io/badge/Status-In%20Development-yellow)
![Languages](https://img.shields.io/badge/Languages-R-blue)


## Table of Contents
- [About](#about)
- [Installation](#installation)
- [Functions](#functions)
- [Directory Structure](#directory-structure)
- [Contact](#contact)

---

## About

**sciSpatialR** is an R package providing tools for harmonising
spatial layers and extracting covariates at point locations for
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

### Input and Validation

| Function | Description |
|---|---|
| `check_alignment()` | Test CRS, extent, resolution, and origin congruence against a reference grid |
| `harmonize_crs()` | Transform points to raster CRS; warn if raster reprojection would be implied |

### Harmonization

| Function | Description |
|---|---|
| `mask_to_boundary()` | Mask to Alberta, natural regions, or a user-supplied polygon |
| `resample_to_grid()` | Resample to reference grid; nearest neighbour enforced for categorical layers |
| `aggregate_to_grid()` | Coarsen to reference grid (mean/sum/max continuous; mode categorical) |

### Extraction

| Function | Description |
|---|---|
| `extract_points()` | Point-in-cell raster extraction (core function) |
| `extract_vector()` | Point-in-polygon attribute join (natural subregion, LUF, ownership, watershed) |
| `extract_proportion()` | Class proportions within buffer for categorical layers; zero-filled absent classes |
| `extract_buffer()` | Summary statistic within one or more radii; vectorised over radii |

### Catalogue and Provenance *(placeholder — under development)*

| Function | Description |
|---|---|
| `list_layers()` | List catalogue contents |
| `find_layer()` | Filter manifest by theme, year, extent, resolution, CRS |
| `get_layer()` | Return SpatRaster or path from canonical layer name |
| `layer_meta()` | Source, vintage, licence, caveats, contact |

---

## Directory Structure

| **Item**                 | **Description**                        |
| ------------------------ | -------------------------------------- |
| **R/**                   | Package function source files          |
| **tests/**               | testthat unit tests                    |
| **0_data/**              | Raw and manipulated data               |
| ├── external/            | Raw data from external sources         |
| └── processed/           | Data that has been manipulated         |
| **1_code/**              | Analysis scripts                       |
| ├── r/                   | R scripts                              |
| ├── python/              | Python scripts                         |
| └── javascript/          | JavaScript scripts                     |
| **2_pipeline/**          | Temporary pipeline files               |
| **3_output/**            | Final project output files             |
| **4_writing/**           | Manuscript and reports                 |
| **README.md**            | Project overview and instructions      |

---

## Contact

For questions regarding the contents of this repository or data
access, please contact Brendan Casey at
brendan.casey@ualberta.ca.

