# ---
# title: extract_buffer — summary statistics within buffer radii
# author: Brendan Casey
# created: 2026-08-12
# inputs:
#   x       - SpatRaster (one or more layers)
#   points  - sf or SpatVector point locations
#   radii   - numeric vector of buffer radii (CRS units)
#   fun     - summary function applied within each buffer
# outputs: data.frame with one row per point; columns named
#          <layer>_<radius>_<fun_name>
# notes:
#   Vectorised over radii.  For each radius, circular buffers are
#   built with terra::buffer() and terra::extract() summarises the
#   cell values within them with fun.  Columns are suffixed with the
#   radius value so multiple radii can coexist in the same output.
#   The buffers are built explicitly because terra::extract() has no
#   `buffer` argument (that was raster::extract()); passing one is
#   silently ignored and yields point-in-cell values instead.
# ---

#' Extract a summary statistic within one or more buffer radii
#'
#' For each combination of point, raster layer, and buffer radius,
#' computes a summary statistic over the cell values within the
#' circular buffer.  Vectorised over `radii` so all results are
#' returned in a single `data.frame`.  Output columns are named
#' `<layer>_r<radius>_<fun_name>` (where radius is in CRS units).
#' Cells are included when their centre falls inside the buffer;
#' a buffer smaller than one cell falls back to the cells it
#' touches, so every point always gets a value.
#'
#' @param x A `SpatRaster` with one or more layers.
#' @param points An `sf` or `SpatVector` of point locations.
#' @param radii Numeric vector of buffer radii in CRS units.
#' @param fun Summary function; passed to [terra::extract()] via
#'   the `fun` argument.  Default `mean`.
#' @param fun_name Character label appended to column names.  If
#'   `NULL` (default), the name of `fun` is used when `fun` is a
#'   named function, or `"stat"` otherwise.
#' @param bind Logical; if `TRUE` (default), columns are
#'   bound to the attributes of `points`.
#' @param ... Additional arguments passed to [terra::extract()],
#'   and on to `fun` — `na.rm = TRUE` is the usual one, needed
#'   whenever a buffer can overlap `NA` cells.
#'
#' @return A `data.frame` with one row per point.  Extracted
#'   columns are named `<layer>_r<radius>_<fun_name>`.
#'
#' @examples
#' \dontrun{
#' library(terra)
#' library(sf)
#' r   <- rast(nrows = 100, ncols = 100, crs = "EPSG:3400",
#'             xmin = 0, xmax = 10000,
#'             ymin = 0, ymax = 10000)
#' r[] <- runif(ncell(r))
#' pts <- st_as_sf(
#'   data.frame(id = 1:2, x = c(2500, 7500), y = c(5000, 5000)),
#'   coords = c("x", "y"), crs = 3400
#' )
#' extract_buffer(r, pts, radii = c(250, 500, 1000))
#' }
#'
#' @export
extract_buffer <- function(x,
                            points,
                            radii,
                            fun = mean,
                            fun_name = NULL,
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
  if (!is.numeric(radii) || any(radii <= 0)) {
    stop("`radii` must be a numeric vector of positive values.")
  }

  # 2. Derive function label ----
  if (is.null(fun_name)) {
    fn_label <- tryCatch(
      paste(deparse(substitute(fun)), collapse = ""),
      error = function(e) "stat"
    )
    # Tidy up common patterns like "base::mean" -> "mean"
    fn_label <- gsub(".*::", "", fn_label)
    fn_label <- gsub("[^A-Za-z0-9_]", "", fn_label)
    # An inline function deparses to its whole body, which makes an
    # unusable column suffix; fall back to a neutral label.
    if (nchar(fn_label) == 0 || nchar(fn_label) > 12) {
      fn_label <- "stat"
    }
  } else {
    fn_label <- fun_name
  }

  # 3. Convert / reproject points ----
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

  # 4. Extract for each radius ----
  # Buffers are built as polygons because terra::extract() takes no
  # `buffer` argument; one call per radius keeps the summary
  # function and the column suffix in step.
  lyr_names <- names(x)

  radius_results <- lapply(radii, function(r) {
    buf  <- terra::buffer(pts_sv, width = r)
    vals <- terra::extract(
      x, buf,
      fun = fun,
      ID  = FALSE,
      ...
    )
    # Rename columns: <layer>_r<radius>_<fun_label>
    suffix      <- paste0("_r", r, "_", fn_label)
    names(vals) <- paste0(lyr_names, suffix)
    vals
  })

  result <- do.call(cbind, radius_results)

  # 5. Optionally bind input attributes ----
  if (bind) {
    if (methods::is(points, "sf")) {
      attrs <- sf::st_drop_geometry(points)
    } else {
      attrs <- as.data.frame(points)
    }
    return(cbind(attrs, result))
  }

  result
}

# End of script ----
