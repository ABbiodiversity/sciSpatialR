# ---
# title: raster_stats — summary pixel statistics for raster layers
# author: Brendan Casey
# created: 2026-08-15
# inputs:
#   x         - SpatRaster, raster file path, or directory of
#               GeoTIFFs
#   quantiles - optional probabilities to report alongside the
#               summary statistics
# outputs: data.frame with one row per raster layer holding cell
#          counts, missingness, and value summaries, preceded by a
#          printed definition of each column unless verbose is
#          FALSE.
# notes:
#   A QA pass over harmonized or exported layers: how many cells
#   carry data, how many are NA, and what range of values they
#   hold.  Counts, min, max, mean, and sd come from terra::global(),
#   which streams the raster rather than loading it, so whole
#   province layers can be summarised.  Quantiles need the values
#   themselves and are therefore optional; layers larger than
#   maxcell are sampled on a regular lattice for them.
#
#   Statistics describe cell values, not area: for a categorical
#   layer they summarise the underlying class codes, which is
#   rarely meaningful.  Use extract_proportion() for class
#   composition instead.
# ---

#' Summarise raster cell values
#'
#' Computes per-layer pixel statistics for one or more rasters:
#' total cells, missing cells, and the range, mean, and standard
#' deviation of the valid values.  Useful as a QA pass over
#' harmonized or newly exported layers before they are used as
#' covariates.
#'
#' `x` may be a `SpatRaster`, the path to a raster file, or a
#' directory of GeoTIFFs, so a folder of exports can be checked in
#' one call.  Every layer of every raster contributes one row.
#'
#' Counts and summaries are computed with [terra::global()], which
#' streams the raster from disk.  Quantiles are computed from the
#' values themselves; layers with more than `maxcell` cells are
#' sampled on a regular lattice, making those columns approximate
#' for large rasters.
#'
#' @param x A `SpatRaster`, or a character vector of raster file
#'   paths and/or directories containing GeoTIFFs.
#' @param quantiles Optional numeric vector of probabilities in
#'   `[0, 1]`.  Each adds a column named for the percentile, e.g.
#'   `c(0.02, 0.98)` gives `q2` and `q98`.  Default `NULL`, no
#'   quantile columns.
#' @param maxcell Numeric; layers with more cells than this are
#'   sampled when computing `quantiles`.  Default `1e6`.
#' @param verbose Logical; if `TRUE` (default), a definition of
#'   each column is printed above the returned table.  Set to
#'   `FALSE` when calling from a script or another function.
#'
#' @return A `data.frame` with one row per layer and columns
#'   `layer`, `source`, `n_total`, `n_na`, `pct_na`, `n_valid`,
#'   `min`, `max`, `mean`, and `sd`, plus one column per requested
#'   quantile.  `source` is the file the layer was read from, or
#'   `NA` for a raster held in memory; layers of a file that carry
#'   no band name are named for the file.  All-`NA` layers return
#'   `NA` for the value summaries.  Unless `verbose = FALSE`, a
#'   definition of each column is printed first.
#'
#' @seealso [check_alignment()] to test a layer's geometry against
#'   the reference grid; [plot_hist()] and [plot_raster()] to
#'   inspect the same values visually.
#'
#' @examples
#' \dontrun{
#' library(terra)
#' r   <- rast(nrows = 10, ncols = 10)
#' r[] <- c(rep(NA, 10), 11:100)
#' raster_stats(r)
#'
#' # With the quantiles used to stretch a plot's colour scale
#' raster_stats(r, quantiles = c(0.02, 0.98))
#'
#' # Every GeoTIFF in a folder of exports
#' raster_stats("2_pipeline/gee_exports")
#'
#' # Just the table, for use downstream
#' raster_stats(r, verbose = FALSE)
#' }
#'
#' @export
raster_stats <- function(x,
                         quantiles = NULL,
                         maxcell = 1e6,
                         verbose = TRUE) {
  # 1. Validate inputs ----
  rasters <- .as_raster_list(x)

  if (!is.null(quantiles)) {
    if (!is.numeric(quantiles) || length(quantiles) == 0 ||
        anyNA(quantiles) ||
        any(quantiles < 0 | quantiles > 1)) {
      stop(
        "`quantiles` must be numeric probabilities between 0 ",
        "and 1."
      )
    }
  }
  if (!is.numeric(maxcell) || length(maxcell) != 1 ||
      is.na(maxcell) || maxcell < 1) {
    stop("`maxcell` must be a single positive number.")
  }

  # 2. Summarise each raster ----
  rows <- lapply(rasters, function(r) {
    # One streamed pass gives counts and value summaries for
    # every layer at once.
    g <- terra::global(
      r,
      fun = c("isNA", "notNA", "min", "max", "mean", "sd"),
      na.rm = TRUE
    )
    n_total <- terra::ncell(r)

    src <- terra::sources(r)
    src <- if (length(src) == 1 && nzchar(src)) {
      basename(src)
    } else {
      NA_character_
    }

    out <- data.frame(
      layer   = .layer_titles(r),
      source  = src,
      n_total = n_total,
      n_na    = g$isNA,
      pct_na  = 100 * g$isNA / n_total,
      n_valid = g$notNA,
      min     = g$min,
      max     = g$max,
      mean    = g$mean,
      sd      = g$sd,
      row.names = NULL,
      stringsAsFactors = FALSE
    )

    # global() reports NaN where a layer has no valid cells;
    # report those as NA so the column stays interpretable.
    is_num <- vapply(out, is.numeric, logical(1))
    out[is_num] <- lapply(out[is_num], function(v) {
      v[is.nan(v)] <- NA_real_
      v
    })

    # 3. Optional quantile columns ----
    if (!is.null(quantiles)) {
      qs <- lapply(seq_len(terra::nlyr(r)), function(i) {
        vals <- .layer_values(r[[i]], maxcell = maxcell)
        if (length(vals) == 0) {
          rep(NA_real_, length(quantiles))
        } else {
          stats::quantile(
            vals,
            probs = quantiles,
            na.rm = TRUE,
            names = FALSE
          )
        }
      })
      qs <- as.data.frame(do.call(rbind, qs))
      names(qs) <- paste0("q", quantiles * 100)
      out <- cbind(out, qs)
    }

    out
  })

  # 4. Combine into one table ----
  stats_df <- do.call(rbind, rows)
  rownames(stats_df) <- NULL

  # 5. Define the columns for the reader ----
  if (verbose) {
    .cat_stats_legend(quantiles)
  }

  stats_df
}


# Internal helper -------------------------------------------------

#' Print a definition of each raster_stats() column
#'
#' The column names are terse, and several distinctions they draw
#' (cells versus valid cells, counts versus percentages) are easy
#' to misread in a QA table.  Printing what each one means beside
#' the table saves a trip to the help page.
#'
#' @param quantiles Numeric probabilities passed to
#'   [raster_stats()], or `NULL`.
#' @return `NULL`, invisibly; called for the printed output.
#' @noRd
.cat_stats_legend <- function(quantiles = NULL) {
  defs <- c(
    layer   = "Layer name; the file name when the band is unnamed",
    source  = "File read from; NA for a raster held in memory",
    n_total = "Cells in the layer",
    n_na    = "Cells with no value (NA)",
    pct_na  = "Percentage of cells with no value",
    n_valid = "Cells carrying a value",
    min     = "Smallest valid value",
    max     = "Largest valid value",
    mean    = "Mean of the valid values",
    sd      = "Standard deviation of the valid values"
  )

  if (!is.null(quantiles)) {
    pct <- quantiles * 100
    qdefs <- paste0(
      "Value below which ", pct, "% of valid cells fall"
    )
    names(qdefs) <- paste0("q", pct)
    defs <- c(defs, qdefs)
  }

  cat("Columns:\n")
  cat(
    paste0(
      "  ", formatC(names(defs), width = -8), "  ", defs, "\n"
    ),
    sep = ""
  )
  cat("\n")
  invisible(NULL)
}

# End of script ----
