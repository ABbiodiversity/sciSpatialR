# ---
# title: Package-level documentation and shared utilities
# author: Brendan Casey
# created: 2026-08-12
# notes:
#   Package-level roxygen2 documentation and any internal
#   helpers shared across functions.
# ---

#' sciSpatialR: Spatial Harmonisation and Covariate Extraction
#'
#' Provides tools for harmonising spatial layers (masking,
#' resampling, aggregating) and extracting covariates at point
#' locations for Alberta-focused biodiversity and species
#' distribution modelling workflows.
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
#' @section Catalogue and Provenance:
#' * [list_layers()] — list catalogue contents
#' * [find_layer()] — filter manifest by theme, year, extent,
#'   resolution, CRS
#' * [get_layer()] — return SpatRaster or path from canonical layer
#'   name
#' * [layer_meta()] — source, vintage, licence, caveats, contact
#'
#' @keywords internal
"_PACKAGE"

# End of script ----
