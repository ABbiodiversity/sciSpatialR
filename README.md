
<img src="man/figures/abmi_logo.png" alt="ABMI Logo" width="300" style="margin-top: 40px;">

# sciSpatialR
![In Development](https://img.shields.io/badge/Status-In%20Development-yellow)
![Lifecycle](https://img.shields.io/badge/Lifecycle-Experimental-orange)
![Languages](https://img.shields.io/badge/Languages-R-blue)

<img src="man/figures/science_centre_logo_unofficial.png" alt="ABMI Science Centre (Unofficial)" width="185">

> [!IMPORTANT]
> This package is developed by and for the Science Centre at the Alberta Biodiversity Monitoring
Institute (ABMI). It is intended for internal use; see
[Licence](#licence).
> 


## Table of Contents
- [About](#about)
- [Installation](#installation)
- [Overview of functions](#overview-of-functions)
- [Reference layers](#reference-layers)
- [Inspecting layers](#inspecting-layers)
- [Extracting covariates](#extracting-covariates)
- [Catalogue](#catalogue)
- [Licence](#licence)
- [Contact](#contact)

---

## About

**sciSpatialR** is an R package with tools for harmonizing
spatial layers and extracting covariates to point locations for
Alberta-focused biodiversity and species distribution modelling
workflows.

---

## Installation

```r
# Install from GitHub (requires remotes)
remotes::install_github("ABbiodiversity/sciSpatialR")
```

Full function reference and vignettes are published at
<https://ABbiodiversity.github.io/sciSpatialR/>.

---

## Overview of Functions

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
| Harmonization | `mask_to_boundary()` | Mask to Alberta (default) or a user-supplied polygon |
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
[on the package site](https://ABbiodiversity.github.io/sciSpatialR/articles/harmonization.html),
or as
`vignette("harmonization", package = "sciSpatialR")`.

---

## Inspecting layers

Functions for evaluating covariate rasters:

```r
# Cell counts, missingness, and value summaries — one row per layer,
# under a printed definition of each column. Cells inside the
# Alberta boundary only, so pct_na measures the study area
raster_stats(my_raster)
raster_stats(my_raster, quantiles = c(0.02, 0.5, 0.98))
raster_stats(my_raster, verbose = FALSE)   # table only

# Another area of interest, or none at all
raster_stats(my_raster, aoi = my_study_area)
raster_stats(my_raster, aoi = NULL)        # every cell of the layer

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

- `raster_stats()` takes a `SpatRaster`, a raster path, or a directory of GeoTIFFs and calculates summary statistics of the cell values inside an area of interest — by default the Alberta boundary the reference grid covers, so an export's surrounding rectangle does not count toward the missingness or the value summaries.
- `plot_raster()` produces a consistently themed raster plot.
- `plot_hist()` produces a histogram of a raster's cell values. 

All three are walked through in the inspection
vignette — read it
[on the package site](https://ABbiodiversity.github.io/sciSpatialR/articles/inspection.html),
or as
`vignette("inspection", package = "sciSpatialR")`.

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
reproject them to the raster when needed, and returns a plain
`data.frame` with extracted columns in input row order.

The walkthrough is in the extraction vignette — read it
[on the package site](https://ABbiodiversity.github.io/sciSpatialR/articles/extraction.html),
or as
`vignette("extraction", package = "sciSpatialR")`. Source:
[`vignettes/extraction.Rmd`](vignettes/extraction.Rmd).

---

## Catalogue

The catalogue is the data share itself. `build_catalogue()` scans
`\\ABMI-DATA2\science\spatial_data`, parses the readme stored beside
each dataset, and assembles a manifest — so the catalogue can never
drift from the data, and documenting a dataset means editing its
readme rather than registering it in a database elsewhere.

Readmes follow the ABMI spatial metadata template, and folders follow
the ISO 19115 topic categories, both documented in
[`geospatial_catalog_and_management_guide`](https://github.com/bgcasey/geospatial_catalog_and_management_guide).


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

### What the catalogue holds

A frozen scan of the share — what `list_layers(verbose = FALSE)`
returns, narrowed to the columns worth tabulating. Empty cells are
fields missing from the corresponding readme.

<!-- catalogue-table:start -->

|theme                     |name                                  |title                                                                                           | year|  res (m)|type   |   size (MB)|
|:-------------------------|:-------------------------------------|:-----------------------------------------------------------------------------------------------|----:|--------:|:------|-----------:|
|biota                     |natural_regions_subregions_of_alberta |Natural Regions and Subregions of Alberta                                                       | 2022|         |vector |        11.2|
|biota                     |grassland_inventory                   |Grassland Inventory for Alberta, Manitoba, and Saskatchewan (2023)                              | 2024|    30.00|raster |    30,110.4|
|boundaries                |alberta                               |AB2020_provincial_boundary                                                                      | 2023|         |vector |         0.4|
|elevation                 |fab_dem                               |FABDEM – Forest And Buildings Removed Copernicus Global DEM (30 m)                              | 2018|   100.00|raster |    11,272.9|
|elevation                 |geomorpho90                           |Alberta Geomorphometric Layers (Geomorpho90m)                                                   | 2023|    90.00|raster |    11,197.9|
|elevation                 |nrcan_mrdem_dsm                       |Medium Resolution Digital Elevation Model (MRDEM) - DSM Cloud Optimized GeoTIFF (COG)           | 2006|    30.00|raster |    56,895.8|
|elevation                 |nrcan_mrdem_dtm                       |Medium Resolution Digital Elevation Model (MRDEM) - DTM Cloud Optimized GeoTIFF (COG)           | 2006|    30.00|raster |    57,503.7|
|elevation                 |nrcan_mrdem_dtm_hillshade             |Medium Resolution Digital Elevation Model (MRDEM) - DTM Hillshade Cloud Optimized GeoTIFF (COG) | 2006|    30.00|raster |    13,648.1|
|imageryBaseMapsEarthCover |landsat_summer_mean_indices_2000_2024 |Landsat Time Series - Alberta Mean Spectral Indices (2000-2024)                                 | 2024|    30.00|raster | 2,772,122.1|
|imageryBaseMapsEarthCover |modis_land_cover_dynamics_2001_2023   |MODIS Annual Land Cover Dynamics (MCD12Q2) - 500m Phenology                                     | 2023|   500.00|raster |     2,529.0|
|imageryBaseMapsEarthCover |scanfi_v1.2                           |SCANFI: Spatialized Canadian National Forest Inventory                                          | 2020|    30.00|raster |    34,349.8|
|inlandWaters              |dynamicSurfaceWaterMaps               |Dynamic Surface Water Maps of Canada from 1984-2023 Landsat Satellite Imagery                   | 2023|         |raster |    21,796.5|
|inlandWaters              |hydrologically adjusted elevations    |Height Above Nearest Drainage (HAND) - Hydrologically Adjusted Elevations                       | 2024|    92.77|raster |       239.0|
|inlandWaters              |archydro2                             |Alberta ArcHydro Phase 2 Data                                                                   | 1996|   100.00|vector |       680.3|
|inlandWaters              |topographic_wetness_index             |Topographic Wetness Index (TWI)                                                                 | 2024|    92.77|raster |     1,193.0|
|location                  |GRID1SQKM_AB2020_gdb                  |GRID1SQKM_AB2020                                                                                |     | 1,000.00|       |       322.8|
|location                  |GRID1SQKM_AB2020_raster               |GRID1SQKM_AB2020_raster                                                                         | 2026| 1,000.00|raster |         0.0|
|transportation            |government_of_alberta_access_layers   |Access and Facility Roads - Alberta                                                             | 2023|         |vector |     1,399.7|

*Scanned 2026-08-16 from `\\ABMI-DATA2\science\spatial_data`. Regenerate with [`data-raw/make_catalogue_snapshot.R`](data-raw/make_catalogue_snapshot.R).*

<!-- catalogue-table:end -->

`check_metadata()` audits the share, reporting which required
template fields each readme is missing and which data folders have no
readme at all:

```r
check_metadata()                       # one row per layer
check_metadata(detail = TRUE)          # one row per missing field
```

A walkthrough with worked examples is in the catalogue vignette —
read it
[on the package site](https://ABbiodiversity.github.io/sciSpatialR/articles/catalogue.html),
or as
`vignette("catalogue", package = "sciSpatialR")` once the package is
installed with `build_vignettes = TRUE`.

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

