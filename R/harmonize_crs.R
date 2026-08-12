# ---
# title: harmonize_crs — transform points to raster CRS
# author: Brendan Casey
# created: 2026-08-12
# inputs:
#   points - sf object of point locations
#   raster - SpatRaster whose CRS is the target; defaults to the
#            ABMI 1 km Alberta grid returned by ab_grid()
# outputs: sf object reprojected to the raster CRS
# notes:
#   Reprojects an sf point layer to match the CRS of a reference
#   SpatRaster.  The raster itself is never modified.
#
#   Reprojecting onto the package's own reference grid is the
#   intended workflow, so that case reports a message.  A
#   caller-supplied raster is different: the CRS mismatch may be
#   unintended, and reprojecting the raster instead may have been
#   the better choice, so that case warns.
# ---

#' Transform points to the CRS of a reference raster
#'
#' Reprojects an `sf` point layer to match the CRS of a reference
#' `SpatRaster`.  The raster is never modified.
#'
#' When `raster` is left at its default — the package reference grid
#' — reprojection is the intended outcome and is reported as a
#' message.  When the caller supplies a raster, a differing CRS may
#' be unintended, so a warning is issued instead: reprojecting the
#' raster is the alternative approach, though it is typically
#' costlier and introduces resampling artefacts.
#'
#' @param points An `sf` object (any geometry, but typically points).
#' @param raster A `SpatRaster` whose CRS is the target CRS.
#'   Defaults to the ABMI 1 km Alberta grid, [ab_grid()], whose CRS
#'   is [ab_crs()].
#' @param warn Logical; if `TRUE` (default), report when
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
#'
#' # Onto the default ABMI 1 km Alberta grid (EPSG:3400)
#' pts_ab <- harmonize_crs(pts)
#' }
#'
#' @export
harmonize_crs <- function(points,
                           raster = ab_grid(),
                           warn = TRUE) {
  # Whether the caller accepted the package reference grid decides
  # how a CRS mismatch is reported (see step 3).
  use_reference <- missing(raster)

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

  # 3. Report and reproject points ----
  if (warn) {
    if (use_reference) {
      message(
        "Reprojecting `points` to the reference grid CRS (",
        crs_raster$input, ")."
      )
    } else {
      warning(
        "CRS of `points` differs from `raster`. ",
        "Reprojecting `points` to raster CRS (",
        crs_raster$input, "). ",
        "Consider whether the raster should have been ",
        "reprojected instead."
      )
    }
  }
  sf::st_transform(points, crs = crs_raster)
}

# End of script ----
