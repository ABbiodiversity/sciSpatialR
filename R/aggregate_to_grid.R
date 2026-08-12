# ---
# title: aggregate_to_grid — coarsen a raster to a reference grid
# author: Brendan Casey
# created: 2026-08-12
# inputs:
#   x          - SpatRaster to coarsen
#   ref        - SpatRaster reference grid (lower resolution)
#   fun        - aggregation function for continuous layers
#   categorical - logical; if TRUE use modal for aggregation
# outputs: SpatRaster aggregated to ref resolution
# notes:
#   Computes the integer aggregation factor from the resolution
#   ratio between ref and x, then calls terra::aggregate().
#   For categorical layers the aggregation function is forced to
#   terra::modal() to preserve the dominant class code.
#   If the factor is not an integer multiple a warning is issued
#   and the nearest integer factor is used.
# ---

#' Coarsen a raster to a reference grid
#'
#' Aggregates `x` to the (coarser) resolution of `ref` using an
#' integer factor derived from the resolution ratio.  For continuous
#' layers the aggregation function defaults to the mean; for
#' categorical layers it is forced to [terra::modal()].
#'
#' @param x A `SpatRaster` to aggregate.
#' @param ref A `SpatRaster` defining the target (coarser) grid.
#' @param fun Character or function; aggregation function for
#'   continuous layers.  One of `"mean"`, `"sum"`, `"max"`,
#'   `"min"`, or any function accepted by [terra::aggregate()].
#'   Ignored when `categorical = TRUE`.  Default `"mean"`.
#' @param categorical Logical; if `TRUE`, forces `fun = "modal"`.
#'   Default `FALSE`.
#' @param ... Additional arguments passed to [terra::aggregate()].
#'
#' @return A `SpatRaster` with approximately the same resolution as
#'   `ref`.
#'
#' @examples
#' \dontrun{
#' library(terra)
#' ref <- rast(res = 1000, crs = "EPSG:3400",
#'             xmin = 0, xmax = 10000,
#'             ymin = 0, ymax = 10000)
#' r   <- rast(res = 250,  crs = "EPSG:3400",
#'             xmin = 0, xmax = 10000,
#'             ymin = 0, ymax = 10000)
#' r[] <- runif(ncell(r))
#' r_agg <- aggregate_to_grid(r, ref)
#' }
#'
#' @export
aggregate_to_grid <- function(x,
                               ref,
                               fun = "mean",
                               categorical = FALSE,
                               ...) {
  # 1. Validate inputs ----
  if (!methods::is(x, "SpatRaster")) {
    stop("`x` must be a SpatRaster.")
  }
  if (!methods::is(ref, "SpatRaster")) {
    stop("`ref` must be a SpatRaster.")
  }

  # 2. Compute aggregation factor ----
  res_x   <- terra::res(x)
  res_ref <- terra::res(ref)

  if (any(res_ref < res_x)) {
    stop(
      "`ref` must have a coarser (or equal) resolution than `x`."
    )
  }

  agg_factor <- round(res_ref / res_x)

  if (any(abs(res_ref / res_x - agg_factor) > 0.01)) {
    warning(
      "Resolution ratio is not an exact integer multiple. ",
      "Using factor = ", paste(agg_factor, collapse = " x "),
      ". Results may not align perfectly with `ref`."
    )
  }

  # 3. Use modal for categorical layers ----
  if (categorical) {
    fun <- terra::modal
  }

  # 4. Aggregate ----
  terra::aggregate(x, fact = agg_factor, fun = fun, ...)
}

# End of script ----
