# ---
# title: resample_to_grid — align a raster to a reference grid
# author: Brendan Casey
# created: 2026-08-12
# inputs:
#   x      - SpatRaster to align
#   ref    - SpatRaster reference grid; defaults to the ABMI 1 km
#            Alberta grid returned by ab_grid()
#   method - resampling method, or "auto" to choose one from the
#            resolution ratio and whether the layer is categorical
#   quiet  - logical; suppress the message naming the method
# outputs: SpatRaster aligned to ref
# notes:
#   Wrapper around terra::resample().  terra always returns a layer
#   on ref's geometry; `method` only decides what value each output
#   cell gets.  The right choice depends on which way the
#   resolution changes, which is why "auto" reads res(x) against
#   res(ref) rather than defaulting to one method for everything:
#
#     coarsening   continuous "average" | categorical "mode"
#     same res     continuous "near"    | categorical "near"
#     refining     continuous "bilinear"| categorical "near"
#
#   Coarsening is the case that goes wrong silently.  A 30 m layer
#   has ~1,111 cells inside every 1 km cell; "average" reads all of
#   them, "bilinear" reads four, "near" reads one.
#
#   "average" and "mode" are used rather than the "mean" and
#   "modal" spellings in current terra documentation: only the
#   former are accepted by both terra 1.8.x and 1.9.x.
#
#   A CRS mismatch is an error rather than a warning.
#   terra::resample() does not reproject: handed a layer in another
#   CRS it returns a raster of NA, which looks like a successful
#   call.  Refusing also protects the method choice, which compares
#   res(x) against res(ref) and would otherwise be reading degrees
#   against metres.  Comparison is by terra::same.crs(), which
#   treats equivalent spellings (an EPSG code and its WKT) as
#   equal.
#
#   This function replaces aggregate_to_grid(), removed because
#   terra::aggregate() coarsens in integer blocks laid out from the
#   input's own corner, so it could not both summarise and align.
#   For a summary terra::resample() does not offer (sd, IQR, a
#   custom function), call terra::aggregate() directly and then
#   resample the result.
# ---

#' Align a raster to a reference grid
#'
#' Resamples `x` onto the CRS, extent, resolution, and origin of
#' `ref`.  By default the resampling method is chosen from the
#' resolution ratio and whether `x` is categorical, and reported on
#' the console; pass `method` to override.
#'
#' @details
#' `terra::resample()` always returns a layer on `ref`'s geometry.
#' The `method` argument decides only what value each output cell
#' takes, and the appropriate choice depends on the direction of
#' the resolution change:
#'
#' \tabular{lll}{
#'   \strong{Direction} \tab \strong{Continuous} \tab
#'     \strong{Categorical} \cr
#'   Coarsening (fine to coarse) \tab `"average"` \tab `"mode"` \cr
#'   Same resolution \tab `"near"` \tab `"near"` \cr
#'   Refining (coarse to fine) \tab `"bilinear"` \tab `"near"`
#' }
#'
#' Coarsening is the case worth care.  Going from 30 m to 1 km each
#' output cell covers roughly 1,111 input cells; `"average"`
#' summarises all of them, whereas `"bilinear"` blends four and
#' `"near"` takes one.  At equal resolution there is nothing to
#' summarise, and `"near"` moves values to the nearest cell without
#' the variance loss interpolation would cause.
#'
#' `"auto"` treats `x` as categorical when
#' `terra::is.factor(x)[1]` is `TRUE`.  A layer holding class codes
#' as plain numbers is not detectable as categorical, so pass
#' `method = "mode"` or `method = "near"` for those.
#'
#' This function does not reproject.  A CRS mismatch between `x`
#' and `ref` is an error, because [terra::resample()] handed a
#' layer in another CRS returns a raster of `NA` rather than
#' failing.  Reproject first with [terra::project()].
#'
#' @param x A `SpatRaster` to align.
#' @param ref A `SpatRaster` used as the target grid.  Defaults to
#'   the ABMI 1 km Alberta grid, [ab_grid()].
#' @param method Character; resampling method passed to
#'   [terra::resample()].  `"auto"` (the default) selects one as
#'   described above.  Any value [terra::resample()] accepts may be
#'   given instead: `"near"`, `"bilinear"`, `"cubic"`,
#'   `"cubicspline"`, `"lanczos"`, `"average"`, `"sum"`, `"mode"`,
#'   `"min"`, `"q1"`, `"median"`, `"q3"`, `"max"`, or `"rms"`.
#' @param quiet Logical; if `TRUE`, suppress the message reporting
#'   the method used.  Default `FALSE`.
#' @param ... Additional arguments passed to [terra::resample()].
#'
#' @return A `SpatRaster` with the same CRS, extent, resolution,
#'   and origin as `ref`.
#'
#' @seealso [check_alignment()] to confirm the result;
#'   [terra::aggregate()] for summaries [terra::resample()] does
#'   not provide, such as `sd` or a custom function.
#'
#' @examples
#' \dontrun{
#' library(terra)
#'
#' # Coarsening: chooses "average"
#' fine <- rast(res = 30, crs = "EPSG:3400",
#'              xmin = 0, xmax = 9000, ymin = 0, ymax = 9000)
#' fine[] <- runif(ncell(fine))
#' ref <- rast(res = 1000, crs = "EPSG:3400",
#'             xmin = 0, xmax = 9000, ymin = 0, ymax = 9000)
#' out <- resample_to_grid(fine, ref)
#'
#' # Override when the default is not what you want
#' totals <- resample_to_grid(fine, ref, method = "sum")
#'
#' # Onto the default ABMI 1 km Alberta grid
#' out2 <- resample_to_grid(fine)
#' }
#'
#' @export
resample_to_grid <- function(x,
                             ref = ab_grid(),
                             method = "auto",
                             quiet = FALSE,
                             ...) {
  # 1. Validate inputs ----
  if (!methods::is(x, "SpatRaster")) {
    stop("`x` must be a SpatRaster.")
  }
  if (!methods::is(ref, "SpatRaster")) {
    stop("`ref` must be a SpatRaster.")
  }
  if (!is.character(method) || length(method) != 1L) {
    stop("`method` must be a single character string.")
  }

  # 2. Refuse a CRS mismatch ----
  # terra::resample() would return an all-NA raster instead of
  # failing, so this is caught here rather than passed through.
  if (!terra::same.crs(x, ref)) {
    stop(crs_mismatch_message(x, ref), call. = FALSE)
  }

  # 3. Resolve the method ----
  if (identical(method, "auto")) {
    chosen <- resample_method_auto(x, ref)
    method <- chosen$method
    if (!quiet) {
      message(
        "resample_to_grid(): method = \"", method, "\" — ",
        chosen$reason
      )
    }
  } else if (!quiet) {
    message(
      "resample_to_grid(): method = \"", method, "\" (supplied)."
    )
  }

  # 4. Resample ----
  terra::resample(x, ref, method = method, ...)
}

#' Build the error text for a CRS mismatch
#'
#' An unset CRS and a genuinely different one need different
#' fixes — assign the right one, or reproject — so they get
#' different messages.  Note that terra::same.crs() reports two
#' rasters that both lack a CRS as matching, so that case never
#' reaches here: resampling within one unspecified coordinate
#' space is a valid geometric operation.
#'
#' @keywords internal
#' @noRd
crs_mismatch_message <- function(x, ref) {
  name_of <- function(r) {
    if (!nzchar(terra::crs(r))) {
      return(NA_character_)
    }
    nm <- terra::crs(r, describe = TRUE)$name
    if (length(nm) != 1L || is.na(nm) || !nzchar(nm)) {
      "unnamed CRS"
    } else {
      nm
    }
  }

  nm_x   <- name_of(x)
  nm_ref <- name_of(ref)

  if (is.na(nm_x)) {
    return(paste0(
      "`x` has no CRS set, so it cannot be aligned to `ref` (",
      nm_ref, "). If you know what `x` is in, assign it with ",
      "terra::crs(x) <- ; if it is already in the reference CRS, ",
      "terra::crs(x) <- terra::crs(ref) is enough."
    ))
  }
  if (is.na(nm_ref)) {
    return(paste0(
      "`ref` has no CRS set, so `x` (", nm_x, ") cannot be ",
      "aligned to it. Assign one with terra::crs(ref) <- ."
    ))
  }

  paste0(
    "CRS mismatch: `x` is ", nm_x, " and `ref` is ", nm_ref,
    ". resample_to_grid() does not reproject, and resampling ",
    "across a CRS boundary returns an empty raster rather than ",
    "an error. Reproject first:\n",
    "  x <- terra::project(x, terra::crs(ref))"
  )
}

# ---
# title: resample_method_auto — pick a resampling method
# notes:
#   Internal.  Classifies the resolution change by comparing cell
#   areas, so a layer with unequal x and y resolutions is still
#   placed on one side or the other.  Returns the method and the
#   reason, which the caller reports.
# ---

#' @keywords internal
#' @noRd
resample_method_auto <- function(x, ref, tol = 1e-6) {
  ratio  <- prod(terra::res(ref)) / prod(terra::res(x))
  is_cat <- isTRUE(terra::is.factor(x)[1])

  direction <- if (ratio > 1 + tol) {
    "coarsening"
  } else if (ratio < 1 - tol) {
    "refining"
  } else {
    "same"
  }

  # Resolutions carry the message on their own when the cell counts
  # are near 1; the counts carry it when they are large.  Report
  # both.  Units are left off because `ref` need not be projected.
  res_txt <- paste0(
    fmt_res(terra::res(x)), " → ", fmt_res(terra::res(ref))
  )
  cells_in  <- fmt_count(ratio, "input cell")
  cells_out <- fmt_count(1 / ratio, "output cell")

  switch(
    direction,
    coarsening = if (is_cat) {
      list(
        method = "mode",
        reason = paste0(
          "categorical layer, coarsening (res ", res_txt, ", ~",
          cells_in, " per output cell); keeping the dominant class."
        )
      )
    } else {
      list(
        method = "average",
        reason = paste0(
          "continuous layer, coarsening (res ", res_txt, ", ~",
          cells_in, " per output cell); averaging all of them."
        )
      )
    },
    same = list(
      method = "near",
      reason = paste0(
        if (is_cat) "categorical layer" else "continuous layer",
        ", same resolution (", fmt_res(terra::res(ref)), "); ",
        "nearest keeps the original values (interpolating would ",
        "smooth them for no gain)."
      )
    ),
    refining = if (is_cat) {
      list(
        method = "near",
        reason = paste0(
          "categorical layer, refining (res ", res_txt,
          ", each input cell spans ~", cells_out, "); ",
          "nearest keeps the class codes intact."
        )
      )
    } else {
      list(
        method = "bilinear",
        reason = paste0(
          "continuous layer, refining (res ", res_txt,
          ", each input cell spans ~", cells_out, "); ",
          "interpolating between input cell centres. Pass ",
          "method = \"near\" to keep the values blocky."
        )
      )
    }
  )
}

#' Format a resolution for the method message
#'
#' @keywords internal
#' @noRd
fmt_res <- function(r) {
  one <- function(v) {
    format(
      round(v, if (abs(v) < 10) 3 else 0),
      big.mark = ",", trim = TRUE, scientific = FALSE
    )
  }
  if (isTRUE(all.equal(r[1], r[2]))) {
    one(r[1])
  } else {
    paste0(one(r[1]), " x ", one(r[2]))
  }
}

#' Format a cell count with a correctly pluralised noun
#'
#' Counts below ten keep a decimal, so a ratio near 1 reads as
#' "~1.2 input cells" rather than a bare "~1" that hides the
#' difference.
#'
#' @keywords internal
#' @noRd
fmt_count <- function(n, noun) {
  rounded <- if (n < 10) round(n, 1) else round(n)
  txt <- format(
    rounded, big.mark = ",", trim = TRUE, scientific = FALSE
  )
  paste0(txt, " ", noun, if (!isTRUE(all.equal(rounded, 1))) "s")
}

# End of script ----
