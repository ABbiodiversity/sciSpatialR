# ---
# title: Package-level documentation and shared utilities
# author: Brendan Casey
# created: 2026-08-12
# notes:
#   Package-level roxygen2 documentation and any internal
#   helpers shared across functions.
# ---

#' sciSpatialR: Spatial Harmonization and Covariate Extraction
#'
#' Provides tools for harmonizing spatial layers (masking,
#' resampling, aggregating) and extracting covariates at point
#' locations for Alberta-focused biodiversity and species
#' distribution modelling workflows.
#'
#' @section Reference Layers:
#' Harmonization defaults to the Alberta provincial boundary and the
#' ABMI 1 km grid, both in NAD83 / Alberta 10-TM (Forest),
#' `EPSG:3400`.  Every function below that takes a reference grid or
#' boundary falls back to these, so layers harmonized with this
#' package share one CRS, extent, resolution, and origin unless a
#' caller opts out.
#'
#' * [ab_crs()] — default CRS, `"EPSG:3400"`
#' * [ab_boundary()] — Alberta provincial boundary (2020 revision)
#' * [ab_grid()] — ABMI 1 km reference grid, 1234 x 695 cells
#'
#' @section Input and Validation:
#' * [check_alignment()] — test CRS, extent, resolution, and origin
#'   congruence against a reference grid
#' * [harmonize_crs()] — transform points to raster CRS; warn if
#'   raster reprojection would be implied
#'
#' @section Harmonization:
#' * [mask_to_boundary()] — mask to Alberta, natural regions, or a
#'   user-supplied polygon
#' * [resample_to_grid()] — resample to a reference grid; nearest
#'   neighbour enforced for categorical layers
#' * [aggregate_to_grid()] — coarsen to reference grid using
#'   mean/sum/max for continuous or mode for categorical layers
#'
#' @section Extraction:
#' * [extract_points()] — point-in-cell raster extraction
#' * [extract_vector()] — point-in-polygon attribute join
#' * [extract_proportion()] — class proportions within buffer for
#'   categorical layers
#' * [extract_buffer()] — summary statistic within one or more radii
#'
#' @section Catalogue and Metadata:
#' The catalogue is built by scanning the spatial data share and
#' parsing the readme stored beside each dataset, so it is always a
#' description of the data as it actually sits on disk.  Readmes
#' follow the ABMI spatial metadata template documented in the
#' geospatial catalog and management guide at
#' \url{https://github.com/bgcasey/geospatial_catalog_and_management_guide}.
#'
#' * [spatial_root()] — location of the data share
#' * [build_catalogue()] — scan the share into a manifest
#' * [list_layers()] — list catalogue contents
#' * [list_themes()] — list ISO 19115 theme folders
#' * [find_layer()] — filter by theme, keyword, year, extent,
#'   resolution, CRS
#' * [get_layer()] — return a SpatRaster, SpatVector, or path
#' * [layer_files()] — list a layer's data files
#' * [layer_meta()] — source, vintage, licence, caveats, contact
#' * [read_metadata()] — parse one readme
#' * [as_metadata_row()] — flatten metadata to a data.frame row
#' * [check_metadata()] — audit metadata completeness
#'
#' @keywords internal
#' @importFrom stats setNames
#' @importFrom tools file_ext
#' @importFrom utils head
"_PACKAGE"

# End of script ----
