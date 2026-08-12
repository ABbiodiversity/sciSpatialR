# ---
# title: mask_to_boundary — mask a raster to a boundary polygon
# author: Brendan Casey
# created: 2026-08-12
# inputs:
#   x        - SpatRaster to mask
#   boundary - SpatVector, sf object, or one of the character
#              shortcuts "alberta", "natural_regions"
# outputs: SpatRaster masked to the boundary extent
# notes:
#   Thin wrapper around terra::mask() with convenience shortcuts
#   for common Alberta boundaries.  When boundary is a character
#   shortcut the function looks for the corresponding built-in
#   dataset in the package's extdata/ folder; users may also
#   supply any sf or SpatVector polygon.
# ---

#' Mask a raster to a boundary polygon
#'
#' Masks a `SpatRaster` to Alberta, to Alberta natural regions, or
#' to any user-supplied polygon.  Character shortcuts `"alberta"` and
#' `"natural_regions"` refer to built-in boundary datasets included
#' in the package.  Any `sf` or `SpatVector` polygon may also be
#' passed directly.
#'
#' @param x A `SpatRaster` to mask.
#' @param boundary A `SpatVector`, an `sf` polygon, or one of the
#'   character shortcuts `"alberta"` or `"natural_regions"`.
#' @param inverse Logical; if `TRUE`, cells *outside* the boundary
#'   are retained and cells inside are set to `NA`.  Default
#'   `FALSE`.
#' @param ... Additional arguments passed to [terra::mask()].
#'
#' @return A `SpatRaster` with cells outside (or inside, if
#'   `inverse = TRUE`) the boundary set to `NA`.
#'
#' @examples
#' \dontrun{
#' library(terra)
#' r   <- rast(nrows = 100, ncols = 100,
#'             xmin = -120, xmax = -110,
#'             ymin =   49, ymax =   60,
#'             crs = "EPSG:4326")
#' r[] <- runif(ncell(r))
#' # Mask to a user polygon
#' poly <- vect("my_polygon.gpkg")
#' r_masked <- mask_to_boundary(r, poly)
#' }
#'
#' @export
mask_to_boundary <- function(x,
                              boundary,
                              inverse = FALSE,
                              ...) {
  # 1. Validate inputs ----
  if (!methods::is(x, "SpatRaster")) {
    stop("`x` must be a SpatRaster.")
  }

  # 2. Resolve boundary ----
  if (is.character(boundary)) {
    boundary <- .load_builtin_boundary(boundary)
  } else if (methods::is(boundary, "sf")) {
    boundary <- terra::vect(boundary)
  } else if (!methods::is(boundary, "SpatVector")) {
    stop(
      "`boundary` must be a SpatVector, sf object, or one of ",
      "'alberta', 'natural_regions'."
    )
  }

  # 3. Reproject boundary to raster CRS if needed ----
  if (!terra::same.crs(x, boundary)) {
    boundary <- terra::project(boundary, terra::crs(x))
  }

  # 4. Mask ----
  terra::mask(x, boundary, inverse = inverse, ...)
}


# Internal helper -------------------------------------------------

#' Load a built-in boundary dataset
#'
#' @param name Character; one of `"alberta"` or
#'   `"natural_regions"`.
#' @return A `SpatVector`.
#' @noRd
.load_builtin_boundary <- function(name) {
  valid <- c("alberta", "natural_regions")
  name  <- tolower(trimws(name))
  if (!name %in% valid) {
    stop(
      "Unknown boundary shortcut '", name, "'. ",
      "Valid shortcuts: ",
      paste(valid, collapse = ", "), "."
    )
  }
  path <- system.file(
    "extdata", paste0(name, ".gpkg"),
    package = "sciSpatialR"
  )
  if (!nzchar(path) || !file.exists(path)) {
    stop(
      "Built-in boundary file for '", name, "' not found. ",
      "Please supply a polygon directly."
    )
  }
  terra::vect(path)
}

# End of script ----
