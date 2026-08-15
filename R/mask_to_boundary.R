# ---
# title: mask_to_boundary — mask a raster to a boundary polygon
# author: Brendan Casey
# created: 2026-08-12
# inputs:
#   x        - SpatRaster to mask
#   boundary - SpatVector, sf object, or the character shortcut
#              "alberta"; defaults to "alberta", the packaged
#              provincial boundary
# outputs: SpatRaster masked to the boundary extent
# notes:
#   Thin wrapper around terra::mask().  "alberta" is the only
#   character shortcut: it is the reference bound for this package
#   and ships with it; see ab_boundary().  Any other boundary is
#   passed in directly as an sf or SpatVector polygon, including
#   layers read off the share with get_layer() — for natural
#   regions and subregions that is
#   get_layer("natural_regions_subregions_of_alberta").
# ---

#' Mask a raster to a boundary polygon
#'
#' Masks a `SpatRaster` to Alberta or to any user-supplied polygon.
#' The character shortcut `"alberta"` refers to the provincial
#' boundary packaged with sciSpatialR; any `sf` or `SpatVector`
#' polygon may also be passed directly.
#'
#' @param x A `SpatRaster` to mask.
#' @param boundary A `SpatVector`, an `sf` polygon, or the character
#'   shortcut `"alberta"`.  Defaults to `"alberta"`, the packaged
#'   provincial boundary also returned by [ab_boundary()].
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
#' # Mask to the default Alberta provincial boundary
#' r_ab <- mask_to_boundary(r)
#'
#' # Mask to a user polygon
#' poly <- vect("my_polygon.gpkg")
#' r_masked <- mask_to_boundary(r, poly)
#'
#' # Anything on the share works the same way
#' nsr <- get_layer("natural_regions_subregions_of_alberta")
#' r_nsr <- mask_to_boundary(r, nsr)
#' }
#'
#' @export
mask_to_boundary <- function(x,
                              boundary = "alberta",
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
      "`boundary` must be a SpatVector, an sf object, or the ",
      "shortcut 'alberta'."
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
#' `"alberta"` is the only shortcut.  Boundaries that do not ship
#' with the package are passed in as polygons rather than named
#' here, so there is no shortcut that resolves to a missing file.
#'
#' @param name Character; `"alberta"`.
#' @return A `SpatVector`.
#' @noRd
.load_builtin_boundary <- function(name) {
  valid <- "alberta"
  name  <- tolower(trimws(name))
  if (!name %in% valid) {
    stop(
      "Unknown boundary shortcut '", name, "'. The only shortcut ",
      "is 'alberta'; pass any other boundary as an sf or ",
      "SpatVector polygon."
    )
  }

  # Delegate to the packaged provincial boundary so the reference
  # layer has a single reader.
  ab_boundary()
}

# End of script ----
