# ---
# title: raster_stats — summary pixel statistics for raster layers
# author: Brendan Casey
# created: 2026-08-15
# inputs:
#   x         - SpatRaster, raster file path, or directory of
#               GeoTIFFs
#   aoi       - polygon the statistics are restricted to; defaults
#               to "alberta", the boundary the reference grid
#               covers
#   quantiles - optional probabilities to report alongside the
#               summary statistics
# outputs: data.frame with one row per raster layer holding cell
#          counts, missingness, and value summaries within the aoi,
#          preceded by a printed definition of each column unless
#          verbose is FALSE.
# notes:
#   A QA pass over harmonized or exported layers: how many cells
#   carry data, how many are NA, and what range of values they
#   hold.  Counts, min, max, mean, and sd come from terra::global(),
#   which streams the raster rather than loading it, so whole
#   province layers can be summarised.  Quantiles need the values
#   themselves and are therefore optional; layers larger than
#   maxcell are sampled on a regular lattice for them.
#
#   Statistics are computed inside the aoi only.  Exports usually
#   arrive on a rectangular extent that reaches well beyond the
#   study area, and cells outside it would otherwise dominate the
#   NA counts and pull the value summaries around.  Cells the aoi
#   covers are counted from the aoi itself rather than from the
#   layer: once a layer is masked, a cell missing data and a cell
#   outside the polygon are both NA.
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
#' Only cells inside `aoi` are summarised.  The default is the
#' Alberta provincial boundary the reference grid covers, so the
#' counts describe the area a covariate is needed for rather than
#' the rectangular extent an export happens to carry.  `n_total`
#' is the number of cells the `aoi` covers, counted from the `aoi`
#' itself, so `n_na` and `pct_na` report how much of the study area
#' the layer leaves empty.  Pass `aoi = NULL` to summarise every
#' cell of the layer instead.
#'
#' Counts and summaries are computed with [terra::global()], which
#' streams the raster from disk.  Quantiles are computed from the
#' values themselves; layers with more than `maxcell` cells are
#' sampled on a regular lattice, making those columns approximate
#' for large rasters.
#'
#' @param x A `SpatRaster`, or a character vector of raster file
#'   paths and/or directories containing GeoTIFFs.
#' @param aoi Area of interest the statistics are restricted to: a
#'   `SpatVector`, an `sf` polygon, or the character shortcut
#'   `"alberta"` accepted by [mask_to_boundary()].  Defaults to
#'   `"alberta"`, the packaged provincial boundary also returned by
#'   [ab_boundary()] and covered by [ab_grid()].  `NULL` summarises
#'   every cell of the layer.
#' @param quantiles Optional numeric vector of probabilities in
#'   `[0, 1]`.  Each adds a column named for the percentile, e.g.
#'   `c(0.02, 0.98)` gives `q2` and `q98`.  Default `NULL`, no
#'   quantile columns.
#' @param maxcell Numeric; layers with more cells than this are
#'   sampled when computing `quantiles`.  Default `1e6`.
#' @param verbose Logical; if `TRUE` (default), the area the
#'   statistics cover and a definition of each column are printed
#'   above the returned table.  Set to `FALSE` when calling from a
#'   script or another function.
#'
#' @return A `data.frame` with one row per layer and columns
#'   `layer`, `source`, `n_total`, `n_na`, `pct_na`, `n_valid`,
#'   `min`, `max`, `mean`, and `sd`, plus one column per requested
#'   quantile.  Every count and summary describes the cells inside
#'   `aoi`.  `source` is the file the layer was read from, or `NA`
#'   for a raster held in memory; layers of a file that carry no
#'   band name are named for the file.  Layers with no valid cell
#'   in the `aoi` return `NA` for the value summaries.  Unless
#'   `verbose = FALSE`, a definition of each column is printed
#'   first.
#'
#' @seealso [mask_to_boundary()] to clip a layer to the same
#'   boundary; [check_alignment()] to test a layer's geometry
#'   against the reference grid; [plot_hist()] and [plot_raster()]
#'   to inspect the same values visually.
#'
#' @examples
#' \dontrun{
#' library(terra)
#'
#' # Cells inside the Alberta boundary only, the default
#' raster_stats(ab_grid())
#'
#' # Or inside any other polygon
#' raster_stats(ab_grid(), aoi = my_study_area)
#'
#' # A layer that is not an Alberta layer: summarise every cell
#' r   <- rast(nrows = 10, ncols = 10)
#' r[] <- c(rep(NA, 10), 11:100)
#' raster_stats(r, aoi = NULL)
#'
#' # With the quantiles used to stretch a plot's colour scale
#' raster_stats(r, aoi = NULL, quantiles = c(0.02, 0.98))
#'
#' # Every GeoTIFF in a folder of exports
#' raster_stats("2_pipeline/gee_exports")
#'
#' # Just the table, for use downstream
#' raster_stats(r, aoi = NULL, verbose = FALSE)
#' }
#'
#' @export
raster_stats <- function(x,
                         aoi = "alberta",
                         quantiles = NULL,
                         maxcell = 1e6,
                         verbose = TRUE) {
  # 1. Validate inputs ----
  rasters  <- .as_raster_list(x)
  aoi_vect <- .resolve_aoi(aoi)

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
    # Names and source are read before clipping: the clipped
    # raster is held in memory and no longer carries a file.
    layer <- .layer_titles(r)
    src   <- terra::sources(r)
    src   <- if (length(src) == 1 && nzchar(src)) {
      basename(src)
    } else {
      NA_character_
    }

    clip    <- .clip_to_aoi(r, aoi_vect)
    n_total <- clip$n_total
    rc      <- clip$raster

    if (n_total == 0) {
      warning(
        "No cells of '", layer[1], "' fall inside the aoi.",
        call. = FALSE
      )
    }

    # One streamed pass gives counts and value summaries for
    # every layer at once.
    g <- if (is.null(rc)) {
      data.frame(
        notNA = rep(0, terra::nlyr(r)),
        min   = NA_real_,
        max   = NA_real_,
        mean  = NA_real_,
        sd    = NA_real_
      )
    } else {
      terra::global(
        rc,
        fun = c("notNA", "min", "max", "mean", "sd"),
        na.rm = TRUE
      )
    }

    # Missing cells are the aoi cells the layer does not fill,
    # not the NA cells of the clipped rectangle.
    n_na <- pmax(n_total - g$notNA, 0)

    out <- data.frame(
      layer   = layer,
      source  = src,
      n_total = n_total,
      n_na    = n_na,
      pct_na  = 100 * n_na / n_total,
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
        vals <- if (is.null(rc)) {
          numeric(0)
        } else {
          .layer_values(rc[[i]], maxcell = maxcell)
        }
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
    .cat_stats_legend(quantiles, aoi_label = .aoi_label(aoi))
  }

  stats_df
}


# Internal helpers ------------------------------------------------

#' Resolve an aoi argument to a polygon
#'
#' Accepts the same inputs as the `boundary` argument of
#' [mask_to_boundary()], plus `NULL` for no restriction, so a layer
#' can be summarised over Alberta, over another polygon, or over
#' its whole extent without the caller reading a boundary first.
#'
#' @param aoi A `SpatVector`, an `sf` polygon, the shortcut
#'   `"alberta"`, or `NULL`.
#' @return A `SpatVector`, or `NULL`.
#' @noRd
.resolve_aoi <- function(aoi) {
  if (is.null(aoi)) {
    return(NULL)
  }
  if (is.character(aoi)) {
    return(.load_builtin_boundary(aoi))
  }
  if (methods::is(aoi, "sf")) {
    return(terra::vect(aoi))
  }
  if (!methods::is(aoi, "SpatVector")) {
    stop(
      "`aoi` must be a SpatVector, an sf object, the shortcut ",
      "'alberta', or NULL.",
      call. = FALSE
    )
  }
  aoi
}


#' Name the area a table of statistics covers
#'
#' @param aoi The `aoi` argument as the caller passed it.
#' @return A length-one character label, or `NULL` when every cell
#'   of the layer was summarised.
#' @noRd
.aoi_label <- function(aoi) {
  if (is.null(aoi)) {
    NULL
  } else if (is.character(aoi)) {
    # Capitalised: the label is read as a place name in a
    # sentence, not as the shortcut that was typed.
    sub("^(.)", "\\U\\1", tolower(trimws(aoi[1])), perl = TRUE)
  } else {
    "the supplied polygon"
  }
}


#' Clip a raster to an aoi and count the cells the aoi covers
#'
#' Crops to the aoi's extent and masks with the aoi rasterized onto
#' that extent.  One rasterized cover supplies both the mask and
#' `n_total`, so the cells counted are exactly the cells the
#' summaries are computed over.
#'
#' @param r A `SpatRaster`.
#' @param aoi A `SpatVector`, or `NULL` for the whole layer.
#' @return A list with `raster`, the clipped `SpatRaster` (`NULL`
#'   when layer and aoi do not overlap), and `n_total`, the number
#'   of cells the aoi covers.
#' @noRd
.clip_to_aoi <- function(r, aoi) {
  if (is.null(aoi)) {
    return(list(raster = r, n_total = terra::ncell(r)))
  }

  if (!terra::same.crs(r, aoi)) {
    aoi <- terra::project(aoi, terra::crs(r))
  }

  # crop() errors on disjoint extents, so the miss is caught here
  # and reported as a layer with nothing inside the aoi.
  if (!.ext_overlaps(r, aoi)) {
    return(list(raster = NULL, n_total = 0))
  }

  # touches = TRUE keeps every cell the polygon reaches into,
  # matching what mask_to_boundary() keeps and what the reference
  # grid holds along the provincial edge.
  r_crop  <- terra::crop(r, aoi, snap = "out")
  cover   <- terra::rasterize(aoi, r_crop[[1]], touches = TRUE)
  n_total <- as.numeric(terra::global(cover, "notNA")[1, 1])

  list(raster = terra::mask(r_crop, cover), n_total = n_total)
}


#' Do two spatial objects' extents overlap?
#'
#' @param a,b Objects [terra::ext()] accepts.
#' @return `TRUE` if the extents share any area.
#' @noRd
.ext_overlaps <- function(a, b) {
  ea <- as.vector(terra::ext(a))
  eb <- as.vector(terra::ext(b))
  ea[1] < eb[2] && eb[1] < ea[2] &&
    ea[3] < eb[4] && eb[3] < ea[4]
}


#' Print a definition of each raster_stats() column
#'
#' The column names are terse, and several distinctions they draw
#' (cells versus valid cells, counts versus percentages) are easy
#' to misread in a QA table.  Printing what each one means beside
#' the table saves a trip to the help page.
#'
#' @param quantiles Numeric probabilities passed to
#'   [raster_stats()], or `NULL`.
#' @param aoi_label Character name of the area summarised, or
#'   `NULL` when every cell of the layer was summarised.
#' @return `NULL`, invisibly; called for the printed output.
#' @noRd
.cat_stats_legend <- function(quantiles = NULL, aoi_label = NULL) {
  in_aoi <- !is.null(aoi_label)

  defs <- c(
    layer   = "Layer name; the file name when the band is unnamed",
    source  = "File read from; NA for a raster held in memory",
    n_total = if (in_aoi) {
      "Cells the aoi covers"
    } else {
      "Cells in the layer"
    },
    n_na    = if (in_aoi) {
      "Aoi cells the layer leaves empty (NA)"
    } else {
      "Cells with no value (NA)"
    },
    pct_na  = if (in_aoi) {
      "Percentage of aoi cells with no value"
    } else {
      "Percentage of cells with no value"
    },
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

  if (in_aoi) {
    cat("Cells within ", aoi_label, " only.\n\n", sep = "")
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
