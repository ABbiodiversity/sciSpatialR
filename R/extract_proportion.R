# ---
# title: extract_proportion — class proportions within buffer
# author: Brendan Casey
# created: 2026-08-12
# inputs:
#   x       - SpatRaster (categorical)
#   points  - sf or SpatVector of point locations
#   radius  - numeric buffer radius in the CRS units of x
# outputs: data.frame with one row per point and one column per
#          class (zero-filled for absent classes)
# notes:
#   For each point, a circular buffer of the specified radius is
#   drawn, the categorical raster is extracted within that buffer,
#   and the proportion of each class is computed.  Classes absent
#   within a given buffer are zero-filled so all points share the
#   same column set.  The column names follow the pattern
#   <layer_name>_<class_value>.
# ---

#' Extract class proportions within a buffer for categorical layers
#'
#' For each point location, draws a circular buffer of `radius`
#' (in CRS units) and computes the proportion of each class in a
#' categorical `SpatRaster`.  All points share the same set of
#' class columns; classes absent within a buffer are filled with
#' zero.
#'
#' @param x A categorical `SpatRaster` (single layer).
#' @param points An `sf` or `SpatVector` of point locations.
#' @param radius Numeric; buffer radius in the CRS units of `x`.
#' @param bind Logical; if `TRUE` (default), the proportions are
#'   column-bound to the attributes of `points`.
#' @param ... Additional arguments passed to [terra::extract()].
#'
#' @return A `data.frame` with one row per point and one proportion
#'   column per class.
#'
#' @examples
#' \dontrun{
#' library(terra)
#' library(sf)
#' r   <- rast(nrows = 100, ncols = 100, crs = "EPSG:3400",
#'             xmin = 0, xmax = 10000,
#'             ymin = 0, ymax = 10000)
#' r[] <- sample(1:3, ncell(r), replace = TRUE)
#' pts <- st_as_sf(
#'   data.frame(id = 1:2, x = c(2500, 7500), y = c(5000, 5000)),
#'   coords = c("x", "y"), crs = 3400
#' )
#' extract_proportion(r, pts, radius = 500)
#' }
#'
#' @export
extract_proportion <- function(x,
                                points,
                                radius,
                                bind = TRUE,
                                ...) {
  # 1. Validate inputs ----
  if (!methods::is(x, "SpatRaster")) {
    stop("`x` must be a SpatRaster.")
  }
  if (terra::nlyr(x) > 1) {
    stop("`x` must be a single-layer SpatRaster.")
  }
  if (!methods::is(points, "sf") &&
      !methods::is(points, "SpatVector")) {
    stop("`points` must be an sf or SpatVector object.")
  }
  if (!is.numeric(radius) || length(radius) != 1 || radius <= 0) {
    stop("`radius` must be a single positive number.")
  }

  # 2. Convert / reproject points ----
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

  # 3. Extract values within buffer ----
  # terra::extract with a numeric `buffer` argument returns all
  # cell values within the radius, with an ID column.
  extracted <- terra::extract(
    x, pts_sv,
    buffer = radius,
    ID     = TRUE,
    ...
  )

  lyr_name <- names(x)[1]

  # 4. Compute proportions per point ----
  all_classes <- sort(unique(stats::na.omit(extracted[[lyr_name]])))
  n_pts       <- nrow(pts_sv)

  prop_list <- lapply(seq_len(n_pts), function(i) {
    vals <- extracted[[lyr_name]][extracted$ID == i]
    vals <- vals[!is.na(vals)]
    if (length(vals) == 0) {
      props <- stats::setNames(
        rep(NA_real_, length(all_classes)),
        all_classes
      )
    } else {
      tab   <- table(factor(vals, levels = all_classes))
      props <- as.numeric(tab) / length(vals)
    }
    stats::setNames(as.list(props), paste0(lyr_name, "_", all_classes))
  })

  prop_df <- do.call(rbind, lapply(prop_list, as.data.frame))

  # 5. Optionally bind to input attributes ----
  if (bind) {
    if (methods::is(points, "sf")) {
      attrs <- sf::st_drop_geometry(points)
    } else {
      attrs <- as.data.frame(points)
    }
    return(cbind(attrs, prop_df))
  }

  prop_df
}

# End of script ----
