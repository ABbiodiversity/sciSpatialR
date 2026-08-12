# ---
# title: extract_vector — point-in-polygon attribute join
# author: Brendan Casey
# created: 2026-08-12
# inputs:
#   points  - sf object of point locations
#   polygons - sf polygon layer with attributes to join
#   cols     - character vector of column names to join (NULL = all)
# outputs: sf object with polygon attributes joined to points
# notes:
#   Performs a spatial left join (sf::st_join) so that each point
#   receives attributes from the polygon it falls within.  Commonly
#   used to attach natural subregion, LUF zone, land ownership, or
#   watershed identifiers to survey points.  Points that fall
#   outside all polygons receive NA for the joined columns.
# ---

#' Point-in-polygon attribute join
#'
#' Joins attributes from a polygon layer to point locations by
#' spatial overlay.  Each point receives the attributes of the
#' polygon it falls within.  Points outside all polygons receive
#' `NA` for the joined columns.  Commonly used to attach natural
#' subregion, LUF zone, ownership, or watershed identifiers.
#'
#' @param points An `sf` object (point geometry).
#' @param polygons An `sf` polygon layer with attributes to join.
#' @param cols Character vector of column names from `polygons` to
#'   retain.  `NULL` (default) retains all non-geometry columns.
#' @param ... Additional arguments passed to [sf::st_join()].
#'
#' @return An `sf` object with the same geometry as `points` and
#'   additional columns from `polygons`.
#'
#' @examples
#' \dontrun{
#' library(sf)
#' pts  <- st_as_sf(data.frame(id = 1, x = -114, y = 53),
#'                  coords = c("x", "y"), crs = 4326)
#' poly <- st_read("natural_subregions.gpkg")
#' pts_joined <- extract_vector(pts, poly, cols = "NRNAME")
#' }
#'
#' @export
extract_vector <- function(points,
                            polygons,
                            cols = NULL,
                            ...) {
  # 1. Validate inputs ----
  if (!methods::is(points, "sf")) {
    stop("`points` must be an sf object.")
  }
  if (!methods::is(polygons, "sf")) {
    stop("`polygons` must be an sf object.")
  }

  # 2. Subset polygon columns if requested ----
  if (!is.null(cols)) {
    geom_col  <- attr(polygons, "sf_column")
    keep_cols <- union(cols, geom_col)
    polygons  <- polygons[, intersect(keep_cols,
                                      names(polygons)),
                          drop = FALSE]
  }

  # 3. Reproject polygons to point CRS if needed ----
  if (sf::st_crs(points) != sf::st_crs(polygons)) {
    polygons <- sf::st_transform(polygons,
                                  crs = sf::st_crs(points))
  }

  # 4. Spatial join ----
  sf::st_join(points, polygons, ...)
}

# End of script ----
