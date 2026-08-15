# ---
# title: plot_raster — quick-look raster map with a boundary
# author: Brendan Casey
# created: 2026-08-15
# inputs:
#   x        - SpatRaster or path to a raster file
#   boundary - polygon drawn over the raster; defaults to the
#              packaged Alberta provincial boundary
# outputs: A ggplot object, plus the theme it is styled with.
# notes:
#   A ggplot2 map for QA looks at harmonized or exported layers.
#   It adds the two things those looks always need: a colour scale
#   clamped to central quantiles, so a handful of extreme cells
#   cannot wash out the pattern, and a boundary overlay to confirm
#   the layer is clipped where it should be.
#
#   Values out of the stretch range are squished to the end
#   colours rather than censored, which is ggplot2's default and
#   would drop them as NA.
#
#   The raster is downsampled to maxcell cells before it is turned
#   into a data frame, so a province-wide layer plots without
#   building a million-row table.  Multi-layer rasters are
#   facetted and therefore share one colour scale; plot a single
#   layer when each needs its own.
#
#   Cells are drawn with geom_tile() sized from the raster's
#   resolution rather than geom_raster(), which infers cell size
#   from the spacing of the cells it is given and shifts them when
#   a masked layer leaves gaps.
#
#   Returns a ggplot object rather than drawing, so figures are
#   saved with ggplot2::ggsave() and can be modified with further
#   ggplot2 layers.
# ---

# 1. plot_raster ------------------------------------------------

#' Plot a raster with a stretched colour scale and boundary
#'
#' Maps `x` with ggplot2, clamping the colour scale to central
#' quantiles of the values and overlaying a boundary polygon.
#' Intended as a quick visual check of a harmonized or exported
#' layer: whether the spatial pattern looks right, and whether the
#' layer is clipped to the boundary it should be.
#'
#' The raster is downsampled to at most `maxcell` cells before
#' plotting, so stretch limits and the drawn surface are
#' approximations for large layers.  Cells are drawn as tiles sized
#' from the raster's own resolution, so a masked layer's gaps stay
#' gaps.  Multi-layer rasters are drawn as facets sharing one
#' colour scale, stretched on the pooled values; pass a single
#' layer (`x[[1]]`) when each layer needs its own scale.
#'
#' Unprojected (longitude/latitude) rasters are given a
#' latitude-corrected aspect ratio; projected rasters are drawn
#' with equal axes.
#'
#' The default colours are the "Hiroshige" palette from MetBrewer,
#' reversed so low values are dark blue and high values red, and
#' the default theme is [theme_science_map()].  Both are ordinary
#' ggplot2 components, so either can be replaced by adding a new
#' `scale_fill_*()` or theme to the returned plot.
#'
#' @param x A `SpatRaster`, or the path to a single raster file.
#' @param stretch Numeric vector of two probabilities giving the
#'   quantiles the colour scale is clamped to.  Default
#'   `c(0.02, 0.98)`; values beyond them take the end colours.
#'   `NULL` uses the full value range, as does a layer whose two
#'   quantiles coincide.
#' @param col Character vector of colours for the value scale.
#'   Defaults to a 256-step reversed "Hiroshige" ramp.
#' @param boundary Polygon drawn over the raster: a `SpatVector`,
#'   an `sf` object, or one of the shortcuts accepted by
#'   [mask_to_boundary()].  Defaults to `"alberta"`, the packaged
#'   provincial boundary; `NULL` draws no overlay.
#' @param boundary_col Colour of the boundary outline.  Default
#'   `"grey20"`.
#' @param boundary_lwd Width of the boundary outline, as ggplot2
#'   `linewidth`.  Default `0.4`.
#' @param na_col Fill for `NA` cells.  Default `NA`, leaving them
#'   unpainted.  Set to e.g. `"firebrick2"` to see which cells are
#'   missing.
#' @param main Plot title.  Defaults to the layer name for a
#'   single-layer raster, and to none for a facetted one, where the
#'   strips carry the names.
#' @param legend_title Title for the fill legend.  Default `NULL`,
#'   no title.
#' @param axes Logical; draw coordinate axes.  Default `FALSE`.
#' @param maxcell Numeric; the raster is downsampled to this many
#'   cells before plotting.  Default `5e5`.
#' @param ... Additional arguments passed to
#'   [ggplot2::geom_tile()], e.g. `alpha`.
#'
#' @return A `ggplot` object.
#'
#' @seealso [plot_hist()] for the value distribution behind the
#'   map; [raster_stats()] for the same values as a table;
#'   [theme_science_map()] for the theme applied.
#'
#' @examples
#' \dontrun{
#' library(terra)
#' r <- get_layer("fab_dem")
#'
#' plot_raster(r)                       # stretched, Alberta outline
#' plot_raster(r, stretch = NULL)       # full value range
#' plot_raster(r, na_col = "firebrick2")  # highlight missing cells
#' plot_raster(r, boundary = my_study_area)
#'
#' # A ggplot object, so it composes and saves as one
#' p <- plot_raster(r, main = "FABDEM") +
#'   ggplot2::labs(caption = "1 km, EPSG:3400")
#' ggplot2::ggsave("2_pipeline/fab_dem.png", p,
#'                 width = 9, height = 6, dpi = 200)
#' }
#'
#' @export
plot_raster <- function(
  x,
  stretch = c(0.02, 0.98),
  col = NULL,
  boundary = "alberta",
  boundary_col = "grey20",
  boundary_lwd = 0.4,
  na_col = NA,
  main = NULL,
  legend_title = NULL,
  axes = FALSE,
  maxcell = 5e5,
  ...
) {
  # 1. Validate inputs ----
  rasters <- .as_raster_list(x)
  if (length(rasters) != 1) {
    stop(
      "`x` must be a single raster; ",
      length(rasters),
      " were found. Plot them one at a time."
    )
  }
  r <- rasters[[1]]

  if (!is.null(stretch)) {
    if (
      !is.numeric(stretch) ||
        length(stretch) != 2 ||
        anyNA(stretch) ||
        any(stretch < 0 | stretch > 1) ||
        stretch[1] >= stretch[2]
    ) {
      stop(
        "`stretch` must be two increasing probabilities between ",
        "0 and 1, or NULL."
      )
    }
  }

  if (is.null(col)) {
    col <- .sci_palette(256)
  }

  # 2. Resolve the boundary overlay ----
  if (!is.null(boundary)) {
    if (is.character(boundary)) {
      boundary <- .load_builtin_boundary(boundary)
    } else if (methods::is(boundary, "sf")) {
      boundary <- terra::vect(boundary)
    } else if (!methods::is(boundary, "SpatVector")) {
      stop(
        "`boundary` must be a SpatVector, sf object, boundary ",
        "shortcut, or NULL."
      )
    }
    if (!terra::same.crs(r, boundary)) {
      boundary <- terra::project(boundary, terra::crs(r))
    }
  }

  # 3. Cells as a plottable table ----
  n_lyr <- terra::nlyr(r)
  long <- .raster_long(r, maxcell = maxcell)
  cell_res <- attr(long, "res")

  # Unpainted NA cells contribute nothing but a "removed rows"
  # warning, so drop them unless they are being given a colour.
  # An all-NA layer keeps its rows, leaving the panel its extent.
  if (is.na(na_col) && any(!is.na(long$value))) {
    long <- long[!is.na(long$value), , drop = FALSE]
  }

  if (is.null(main) && n_lyr == 1) {
    main <- levels(long$layer)[1]
  }

  # 4. Stretch limits ----
  # Clamp the scale to central quantiles so extreme cells do not
  # flatten the pattern; fall back to the full range when those
  # quantiles coincide (a constant or near-constant layer).
  limits <- NULL
  if (!is.null(stretch)) {
    vals <- long$value[is.finite(long$value)]
    if (length(vals) > 0) {
      limits <- stats::quantile(
        vals,
        probs = stretch,
        na.rm = TRUE,
        names = FALSE
      )
      if (diff(limits) <= 0) {
        limits <- range(vals)
      }
      if (diff(limits) <= 0) {
        limits <- NULL
      }
    }
  }

  # 5. Aspect ratio ----
  # Degrees of longitude shorten towards the poles, so an unequal
  # ratio is what keeps an unprojected raster from looking
  # stretched.  Projected rasters are already in equal units.
  ratio <- 1
  if (isTRUE(terra::is.lonlat(r))) {
    mid_lat <- mean(c(terra::ymin(r), terra::ymax(r)))
    ratio <- 1 / max(cos(mid_lat * pi / 180), 0.1)
  }

  # 6. Build the map ----
  # geom_tile, not geom_raster: a masked layer leaves gaps between
  # the cells that remain, and geom_raster reads those as uneven
  # spacing and shifts pixels to close them.  Sizing tiles from the
  # raster's own resolution places every cell exactly.
  p <- ggplot2::ggplot(
    long,
    ggplot2::aes(
      x = .data$x,
      y = .data$y,
      fill = .data$value
    )
  ) +
    ggplot2::geom_tile(
      width = cell_res[1],
      height = cell_res[2],
      ...
    ) +
    ggplot2::scale_fill_gradientn(
      colours = col,
      limits = limits,
      oob = .oob_squish,
      na.value = na_col
    ) +
    ggplot2::coord_fixed(ratio = ratio) +
    ggplot2::labs(
      title = main,
      x = NULL,
      y = NULL,
      fill = legend_title
    ) +
    theme_science_map()

  if (n_lyr > 1) {
    p <- p + ggplot2::facet_wrap(ggplot2::vars(.data$layer))
  }

  if (!is.null(boundary)) {
    p <- p +
      ggplot2::geom_polygon(
        data = .vector_rings(boundary),
        mapping = ggplot2::aes(
          x = .data$x,
          y = .data$y,
          group = .data$ring
        ),
        inherit.aes = FALSE,
        fill = NA,
        colour = boundary_col,
        linewidth = boundary_lwd
      )
  }

  if (!axes) {
    p <- p +
      ggplot2::theme(
        axis.text = ggplot2::element_blank(),
        axis.ticks = ggplot2::element_blank(),
        axis.line = ggplot2::element_blank()
      )
  }

  p
}


# 2. theme_science_map ------------------------------------------

#' Minimal ggplot2 theme for scientific map figures
#'
#' A minimalist theme for maps and scientific plots: gridlines
#' removed, axis formatting simplified, and clean bold titles.
#' Applied by [plot_raster()] and [plot_hist()], and exported so
#' other figures in a project can share the same look.
#'
#' @return A `ggplot2` theme object, added to a plot with `+`.
#'
#' @seealso [plot_raster()] and [plot_hist()], which apply this
#'   theme by default.
#'
#' @examples
#' \dontrun{
#' library(ggplot2)
#' p <- ggplot(mtcars, aes(x = wt, y = mpg)) +
#'   geom_point() +
#'   labs(title = "Example Plot", x = "Weight", y = "mpg") +
#'   theme_science_map()
#' print(p)
#' }
#'
#' @export
theme_science_map <- function() {
  ggplot2::theme_minimal(base_size = 12, base_family = "sans") +
    ggplot2::theme(
      # Remove gridlines for simplicity
      panel.grid.major = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),

      # Add clean axis lines
      axis.line = ggplot2::element_line(
        color = "black",
        linewidth = 0.5
      ),

      # Simplify axis text and titles
      axis.text = ggplot2::element_text(
        size = 10,
        color = "black"
      ),
      axis.title = ggplot2::element_text(
        size = 12,
        face = "bold"
      ),

      # Customize legend appearance
      legend.background = ggplot2::element_blank(),
      legend.key = ggplot2::element_blank(),
      legend.title = ggplot2::element_text(
        size = 10,
        face = "bold"
      ),
      legend.text = ggplot2::element_text(size = 9),

      # Remove panel background for a clean look
      panel.background = ggplot2::element_rect(
        fill = "transparent",
        color = "black"
      ),

      # Align titles and subtitles for clarity
      plot.title = ggplot2::element_text(
        size = 14,
        face = "bold",
        hjust = 0.5
      ),
      plot.subtitle = ggplot2::element_text(
        size = 12,
        hjust = 0.5
      ),
      plot.caption = ggplot2::element_text(
        size = 9,
        hjust = 1
      )
    )
}

# End of script ----
