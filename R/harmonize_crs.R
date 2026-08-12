# ---
# title: harmonize_crs — transform points to raster CRS
# author: Brendan Casey
# created: 2026-08-12
# inputs:
#   points - sf object of point locations
#   raster - SpatRaster whose CRS is the target
# outputs: sf object reprojected to the raster CRS
# notes:
#   Reprojects an sf point layer to match the CRS of a reference
#   SpatRaster.  If raster reprojection would have been required
#   (i.e., the two CRS differ but the raster CRS was chosen as the
#   canonical one), a warning is issued so the caller is aware.
#   The raster itself is never modified.
# ---

#' Transform points to the CRS of a reference raster
#'
#' Reprojects an `sf` point layer to match the CRS of a reference
#' `SpatRaster`.  The raster is never modified.  A warning is issued
#' when the CRS of `points` and `raster` differ, to alert the caller
#' that raster reprojection would have been the alternative approach
#' (which is typically costlier and introduces resampling artefacts).
#'
#' @param points An `sf` object (any geometry, but typically points).
#' @param raster A `SpatRaster` whose CRS is the target CRS.
#' @param warn Logical; if `TRUE` (default), emit a warning when
#'   reprojection is performed.
#'
#' @return An `sf` object with the same features as `points` but
#'   projected to the CRS of `raster`.
#'
#' @examples
#' \dontrun{
#' library(terra)
#' library(sf)
#' ref <- rast(nrows = 10, ncols = 10, crs = "EPSG:3400")
#' pts <- st_as_sf(
#'   data.frame(x = c(-114, -113), y = c(53, 54)),
#'   coords = c("x", "y"),
#'   crs    = 4326
#' )
#' pts_proj <- harmonize_crs(pts, ref)
#' }
#'
#' @export
harmonize_crs <- function(points,
                           raster,
                           warn = TRUE) {
  # 1. Validate inputs ----
  if (!methods::is(points, "sf")) {
    stop("`points` must be an sf object.")
  }
  if (!methods::is(raster, "SpatRaster")) {
    stop("`raster` must be a SpatRaster.")
  }

  # 2. Compare CRS ----
  crs_pts    <- sf::st_crs(points)
  crs_raster <- sf::st_crs(terra::crs(raster))

  if (crs_pts == crs_raster) {
    return(points)
  }

  # 3. Warn and reproject points ----
  if (warn) {
    warning(
      "CRS of `points` differs from `raster`. ",
      "Reprojecting `points` to raster CRS (",
      crs_raster$input, "). ",
      "Consider whether the raster should have been ",
      "reprojected instead."
    )
  }
  sf::st_transform(points, crs = crs_raster)
}

# End of script ----
