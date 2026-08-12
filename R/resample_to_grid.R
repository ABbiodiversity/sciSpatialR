# ---
# title: resample_to_grid — resample to a reference grid
# author: Brendan Casey
# created: 2026-08-12
# inputs:
#   x          - SpatRaster to resample
#   ref        - SpatRaster reference grid; defaults to the ABMI
#                1 km Alberta grid returned by ab_grid()
#   categorical - logical; if TRUE, use nearest-neighbour method
# outputs: SpatRaster aligned to ref
# notes:
#   Wrapper around terra::resample().  When the input layer is
#   categorical the method is forced to "near" to avoid
#   interpolating class codes.  For continuous layers the default
#   method is "bilinear" but can be overridden.
# ---

#' Resample a raster to a reference grid
#'
#' Resamples `x` to match the CRS, extent, and resolution of `ref`.
#' When `categorical = TRUE` (or `method = "near"`) the
#' nearest-neighbour method is enforced so class codes are not
#' interpolated.
#'
#' @param x A `SpatRaster` to resample.
#' @param ref A `SpatRaster` used as the target grid.  Defaults to
#'   the ABMI 1 km Alberta grid, [ab_grid()].
#' @param categorical Logical; if `TRUE`, forces `method = "near"`.
#'   Default `FALSE`.
#' @param method Character; resampling method passed to
#'   [terra::resample()].  Ignored when `categorical = TRUE`.
#'   Default `"bilinear"`.
#' @param ... Additional arguments passed to [terra::resample()].
#'
#' @return A `SpatRaster` with the same CRS, extent, and resolution
#'   as `ref`.
#'
#' @examples
#' \dontrun{
#' library(terra)
#' ref <- rast(nrows = 20, ncols = 20, crs = "EPSG:3400")
#' r   <- rast(nrows = 10, ncols = 10, crs = "EPSG:3400")
#' r[] <- runif(ncell(r))
#' r2  <- resample_to_grid(r, ref)
#'
#' # Onto the default ABMI 1 km Alberta grid
#' r3 <- resample_to_grid(r)
#' }
#'
#' @export
resample_to_grid <- function(x,
                              ref = ab_grid(),
                              categorical = FALSE,
                              method = "bilinear",
                              ...) {
  # 1. Validate inputs ----
  if (!methods::is(x, "SpatRaster")) {
    stop("`x` must be a SpatRaster.")
  }
  if (!methods::is(ref, "SpatRaster")) {
    stop("`ref` must be a SpatRaster.")
  }

  # 2. Enforce nearest-neighbour for categorical layers ----
  if (categorical) {
    method <- "near"
  }

  # 3. Resample ----
  terra::resample(x, ref, method = method, ...)
}

# End of script ----
