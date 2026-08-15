# ---
# title: utils_raster — internal helpers for raster inspection
# author: Brendan Casey
# created: 2026-08-15
# inputs:
#   x       - SpatRaster, raster file path, or directory of GeoTIFFs
#   maxcell - cell budget above which values are sampled
# outputs: Internal helpers returning a list of SpatRasters, a
#          vector of valid cell values, a colour ramp, and the
#          data frames the ggplot2 figures are built from.
# notes:
#   Shared internals behind raster_stats(), plot_raster(), and
#   plot_hist().  None are exported.  They are grouped here rather
#   than duplicated across the three files so the three functions
#   accept the same inputs, sample values the same way, and share
#   one default palette.
# ---

# 1. .as_raster_list --------------------------------------------

#' Coerce a raster input to a list of SpatRasters
#'
#' Accepts a `SpatRaster` directly, or character paths that may be
#' raster files, directories of GeoTIFFs, or a mix of both.  Paths
#' let the raster QA functions be pointed straight at a folder of
#' exports without the caller reading each file first.
#'
#' @param x A `SpatRaster` or character vector of paths.
#' @param arg Name of the calling argument, used in error messages.
#' @return A list of `SpatRaster` objects, one per input raster.
#' @noRd
.as_raster_list <- function(x, arg = "x") {
  if (methods::is(x, "SpatRaster")) {
    return(list(x))
  }
  if (!is.character(x) || length(x) == 0) {
    stop(
      "`", arg, "` must be a SpatRaster, a raster file path, or ",
      "a directory of GeoTIFFs.",
      call. = FALSE
    )
  }

  # Expand each element: a directory contributes every GeoTIFF it
  # holds, a file contributes itself.
  paths <- unlist(
    lapply(x, function(p) {
      if (dir.exists(p)) {
        files <- list.files(
          p,
          pattern = "\\.tif{1,2}$",
          full.names = TRUE,
          ignore.case = TRUE
        )
        if (length(files) == 0) {
          stop(
            "No GeoTIFFs found in directory: ", p,
            call. = FALSE
          )
        }
        files
      } else if (file.exists(p)) {
        p
      } else {
        stop("Path does not exist: ", p, call. = FALSE)
      }
    }),
    use.names = FALSE
  )

  lapply(paths, terra::rast)
}


# 2. .layer_values ----------------------------------------------

#' Valid cell values of a single raster layer
#'
#' Returns the finite, non-`NA` values of one layer.  Layers with
#' more than `maxcell` cells are sampled on a regular lattice rather
#' than read in full, so histograms and quantiles stay usable on
#' province-wide rasters.
#'
#' @param x A single-layer `SpatRaster`.
#' @param maxcell Numeric; cell budget above which values are
#'   sampled.
#' @return A numeric vector, possibly of length zero.
#' @noRd
.layer_values <- function(x, maxcell = 1e6) {
  if (terra::ncell(x) > maxcell) {
    vals <- terra::spatSample(
      x,
      size = maxcell,
      method = "regular",
      na.rm = TRUE,
      values = TRUE
    )[[1]]
  } else {
    vals <- terra::values(x, mat = FALSE)
  }

  # Drop NA, NaN, and Inf: hist() and quantile() cannot use them,
  # and they are counted separately by raster_stats().
  vals[is.finite(vals)]
}


# 3. .layer_titles ----------------------------------------------

#' Readable names for the layers of a raster
#'
#' terra names an unnamed band `lyr.N`, which tells the reader
#' nothing about a raster read from a file.  Those defaults are
#' replaced with the file's stem, so a folder of exports plots and
#' tabulates under names that identify the file.
#'
#' @param x A `SpatRaster`.
#' @return A character vector, one name per layer.
#' @noRd
.layer_titles <- function(x) {
  nms <- names(x)
  src <- terra::sources(x)
  is_default <- grepl("^lyr\\.[0-9]+$", nms)

  if (any(is_default) && length(src) == 1 && nzchar(src)) {
    stem <- tools::file_path_sans_ext(basename(src))
    nms[is_default] <- if (length(nms) == 1) {
      stem
    } else {
      paste0(stem, ": ", nms[is_default])
    }
  }
  nms
}


# 4. .sci_palette -----------------------------------------------

#' Default continuous palette for raster and histogram plots
#'
#' Interpolates the "Hiroshige" palette (after Utagawa Hiroshige)
#' from MetBrewer, \url{https://github.com/BlakeRMills/MetBrewer},
#' which records it as colourblind-friendly.  The ten hex values
#' are reproduced here so plots match the wider ABMI scripts
#' without depending on MetBrewer for a colour vector.
#'
#' `direction` follows the `met.brewer()` convention: `1` keeps the
#' order MetBrewer lists (red through cream to dark blue) and `-1`
#' reverses it, so low values are dark blue and high values red.
#' The reversed ramp is the default here.
#'
#' @param n Integer; number of colours to return.
#' @param direction `1` for the listed order, `-1` to reverse.
#' @return A character vector of `n` hex colours, low to high.
#' @noRd
.sci_palette <- function(n = 256, direction = -1) {
  hiroshige <- c(
    "#e76254", "#ef8a47", "#f7aa58", "#ffd06f", "#ffe6b7",
    "#aadce0", "#72bcd5", "#528fad", "#376795", "#1e466e"
  )
  if (direction < 0) {
    hiroshige <- rev(hiroshige)
  }
  grDevices::colorRampPalette(hiroshige)(n)
}


#' Clamp out-of-range values to the scale limits
#'
#' Stands in for `scales::squish()` as the `oob` handler of a fill
#' scale, so cells outside the stretch limits are painted with the
#' end colours instead of dropped as `NA`.  Written out to keep
#' `scales` out of the package's dependencies.  Named for its role
#' rather than `.squish()`, which `metadata.R` already uses for
#' collapsing whitespace.
#'
#' @param x Numeric vector of values.
#' @param range Numeric length-two scale limits.
#' @param only.finite Ignored; present for the `oob` interface.
#' @return `x` with values outside `range` pulled to its ends.
#' @noRd
.oob_squish <- function(x, range = c(0, 1), only.finite = TRUE) {
  finite <- is.finite(x)
  x[finite & x < range[1]] <- range[1]
  x[finite & x > range[2]] <- range[2]
  x
}


#' Position of a value within its facet panel, on 0 to 1
#'
#' A single fill scale is shared by every panel of a facetted plot,
#' so panels covering different value ranges would each come out a
#' flat colour.  Rescaling within the panel lets every panel ramp
#' through the whole palette; the fill then reads as position in
#' the layer's own range rather than as an absolute value.
#'
#' @param v Numeric vector of values.
#' @param panel Grouping vector, the `PANEL` column of stat data.
#' @return A numeric vector on `[0, 1]`; a panel with no spread
#'   takes the middle of the ramp.
#' @noRd
.rescale_panel <- function(v, panel) {
  stats::ave(v, panel, FUN = function(z) {
    rng <- range(z, na.rm = TRUE)
    if (isTRUE(diff(rng) > 0)) {
      (z - rng[1]) / diff(rng)
    } else {
      rep(0.5, length(z))
    }
  })
}


#' Raster cells as a long data frame for ggplot2
#'
#' Downsamples a raster to at most `maxcell` cells and returns one
#' row per cell per layer.  `NA` cells are kept so the fill scale
#' can paint them, and layers are labelled with `.layer_titles()`
#' before sampling, which drops the file name a sampled raster no
#' longer carries.
#'
#' @param x A `SpatRaster`.
#' @param maxcell Numeric; cell budget for the plotted raster.
#' @return A `data.frame` with columns `x`, `y`, `layer` (a factor
#'   in layer order), and `value`, carrying the cell size of the
#'   returned (possibly downsampled) raster in a `"res"` attribute.
#' @noRd
.raster_long <- function(x, maxcell = 5e5) {
  labels <- .layer_titles(x)

  if (terra::ncell(x) > maxcell) {
    x <- terra::spatSample(
      x,
      size = maxcell,
      method = "regular",
      as.raster = TRUE
    )
  }

  # Columns are taken by position: a layer named "x" would
  # otherwise collide with the coordinate columns.
  df <- terra::as.data.frame(x, xy = TRUE, na.rm = FALSE)
  long <- do.call(rbind, lapply(seq_along(labels), function(i) {
    data.frame(
      x = df[[1]],
      y = df[[2]],
      layer = labels[i],
      value = df[[i + 2]],
      stringsAsFactors = FALSE
    )
  }))
  long$layer <- factor(long$layer, levels = labels)

  # Carried so the caller can size tiles explicitly: a masked layer
  # leaves gaps in the cell centres, and a geom that infers cell
  # size from their spacing gets it wrong.
  attr(long, "res") <- terra::res(x)
  long
}


#' Polygon rings of a SpatVector as a data frame
#'
#' @param x A `SpatVector`.
#' @return A `data.frame` with columns `x`, `y`, and `ring`, one
#'   group per polygon ring so outlines are drawn separately.
#' @noRd
.vector_rings <- function(x) {
  g <- as.data.frame(terra::geom(x))
  data.frame(
    x = g$x,
    y = g$y,
    ring = paste(g$geom, g$part, g$hole, sep = "_"),
    stringsAsFactors = FALSE
  )
}

# End of script ----
