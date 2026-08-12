# ---
# title: extract_points — point-in-cell raster extraction
# author: Brendan Casey
# created: 2026-08-12
# inputs:
#   x      - SpatRaster with one or more layers
#   points - sf or SpatVector point locations
# outputs: data.frame with one row per point and one column per
#          raster layer, plus the original point attributes
# notes:
#   Core extraction function.  Reprojects points to the raster CRS
#   if necessary (with a warning), then calls terra::extract() with
#   ID = FALSE so the result can be cbind-ed directly to the input
#   attribute table.
# ---

#' Extract raster values at point locations
#'
#' Extracts cell values from `x` at each location in `points`.
#' Points are reprojected to the raster CRS if needed (a warning is
#' issued when this happens).  The returned `data.frame` has the
#' same number of rows as `points` with one additional column per
#' raster layer.
#'
#' @param x A `SpatRaster` with one or more layers.
#' @param points An `sf` or `SpatVector` of point locations.
#' @param bind Logical; if `TRUE` (default), the extracted values
#'   are column-bound to the attributes of `points`.  If `FALSE`,
#'   only the extracted values are returned.
#' @param ... Additional arguments passed to [terra::extract()].
#'
#' @return A `data.frame`.
#'
#' @examples
#' \dontrun{
#' library(terra)
#' library(sf)
#' r   <- rast(nrows = 10, ncols = 10, crs = "EPSG:4326")
#' r[] <- 1:ncell(r)
#' pts <- st_as_sf(
#'   data.frame(id = 1:3, x = c(-1, 0, 1), y = c(-1, 0, 1)),
#'   coords = c("x", "y"), crs = 4326
#' )
#' extract_points(r, pts)
#' }
#'
#' @export
extract_points <- function(x,
                            points,
                            bind = TRUE,
                            ...) {
  # 1. Validate inputs ----
  if (!methods::is(x, "SpatRaster")) {
    stop("`x` must be a SpatRaster.")
  }
  if (!methods::is(points, "sf") &&
      !methods::is(points, "SpatVector")) {
    stop("`points` must be an sf or SpatVector object.")
  }

  # 2. Convert sf to SpatVector; reproject if needed ----
  if (methods::is(points, "sf")) {
    pts_sv <- terra::vect(points)
  } else {
    pts_sv <- points
  }

  if (!terra::same.crs(x, pts_sv)) {
    warning(
      "CRS mismatch: reprojecting `points` to raster CRS."
    )
    pts_sv <- terra::project(pts_sv, terra::crs(x))
  }

  # 3. Extract ----
  vals <- terra::extract(x, pts_sv, ID = FALSE, ...)

  # 4. Optionally bind to input attributes ----
  if (bind) {
    if (methods::is(points, "sf")) {
      attrs <- sf::st_drop_geometry(points)
    } else {
      attrs <- as.data.frame(points)
    }
    return(cbind(attrs, vals))
  }

  vals
}

# End of script ----
