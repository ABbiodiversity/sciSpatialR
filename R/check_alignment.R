# ---
# title: check_alignment — test layer alignment against a reference
# author: Brendan Casey
# created: 2026-08-12
# inputs:
#   x   - SpatRaster or sf object to check
#   ref - SpatRaster used as the reference grid
# outputs: Named logical vector (invisibly); messages describe any
#          mismatches.
# notes:
#   Tests whether x shares the same CRS, extent, resolution, and
#   origin as ref.  Returns a named logical vector with one element
#   per property checked.  Issues a message for each mismatch so
#   callers can decide whether to harmonise before proceeding.
# ---

#' Check alignment of a spatial layer against a reference grid
#'
#' Tests whether `x` shares the same CRS, extent, resolution, and
#' origin as `ref`.  A named logical vector is returned (invisibly)
#' with one element per property.  Mismatches trigger an informative
#' message so callers can decide whether to harmonise before
#' proceeding.
#'
#' @param x A `SpatRaster` (terra) or `sf` object to check.
#' @param ref A `SpatRaster` used as the reference grid.
#' @param tol Numeric tolerance used for extent, resolution, and
#'   origin comparisons.  Defaults to `1e-6`.
#' @param verbose Logical; if `TRUE` (default), messages are printed
#'   for each property.
#'
#' @return A named logical vector (invisible) with elements `crs`,
#'   `extent`, `resolution`, and `origin`.  `TRUE` indicates
#'   agreement with `ref`.
#'
#' @examples
#' \dontrun{
#' library(terra)
#' ref <- rast(nrows = 10, ncols = 10, crs = "EPSG:3400")
#' r   <- rast(nrows = 10, ncols = 10, crs = "EPSG:4326")
#' check_alignment(r, ref)
#' }
#'
#' @export
check_alignment <- function(x,
                             ref,
                             tol = 1e-6,
                             verbose = TRUE) {
  # 1. Validate inputs ----
  if (!methods::is(ref, "SpatRaster")) {
    stop("`ref` must be a SpatRaster.")
  }
  if (!methods::is(x, "SpatRaster") &&
      !methods::is(x, "sf")) {
    stop("`x` must be a SpatRaster or sf object.")
  }

  results <- logical(0)

  # 2. CRS check ----
  crs_x <- if (methods::is(x, "SpatRaster")) {
    terra::crs(x)
  } else {
    sf::st_crs(x)$wkt
  }
  crs_ref <- terra::crs(ref)
  crs_ok  <- identical(crs_x, crs_ref)
  results["crs"] <- crs_ok
  if (verbose) {
    if (crs_ok) {
      message("CRS: OK")
    } else {
      message("CRS: MISMATCH — x and ref have different CRS.")
    }
  }

  # 3. Extent, resolution, and origin checks (raster only) ----
  if (methods::is(x, "SpatRaster")) {
    ext_x   <- as.vector(terra::ext(x))
    ext_ref <- as.vector(terra::ext(ref))
    ext_ok  <- all(abs(ext_x - ext_ref) <= tol)
    results["extent"] <- ext_ok
    if (verbose) {
      if (ext_ok) {
        message("Extent: OK")
      } else {
        message("Extent: MISMATCH.")
      }
    }

    res_x   <- terra::res(x)
    res_ref <- terra::res(ref)
    res_ok  <- all(abs(res_x - res_ref) <= tol)
    results["resolution"] <- res_ok
    if (verbose) {
      if (res_ok) {
        message("Resolution: OK")
      } else {
        message("Resolution: MISMATCH.")
      }
    }

    # Origin: coordinates of upper-left cell corner
    orig_x   <- terra::origin(x)
    orig_ref <- terra::origin(ref)
    orig_ok  <- all(abs(orig_x - orig_ref) <= tol)
    results["origin"] <- orig_ok
    if (verbose) {
      if (orig_ok) {
        message("Origin: OK")
      } else {
        message("Origin: MISMATCH.")
      }
    }
  } else {
    if (verbose) {
      message(
        "Extent, resolution, and origin checks skipped ",
        "(x is an sf object)."
      )
    }
  }

  invisible(results)
}

# End of script ----
