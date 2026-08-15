# ---
# title: plot_hist — histogram of raster cell values
# author: Brendan Casey
# created: 2026-08-15
# inputs:
#   x    - SpatRaster or path to a raster file
#   bins - number of histogram bins
# outputs: A ggplot object.
# notes:
#   The distribution behind plot_raster(): where the values pile
#   up, whether a layer is bimodal, and whether the tails that the
#   map's stretch clips are long.  Bars are filled along the same
#   ramp plot_raster() colours cells with, so the two figures read
#   together, and theme_science_map() is applied to both.
#
#   The raster is downsampled to maxcell cells first, so the
#   histogram is a sample of a large layer rather than a census of
#   it.  Multi-layer rasters are facetted with free scales, since
#   bands rarely share a value range or a count range.
#
#   Returns a ggplot object rather than drawing, so figures are
#   saved with ggplot2::ggsave() and can be modified with further
#   ggplot2 layers.
# ---

#' Plot a histogram of raster cell values
#'
#' Draws the distribution of valid (non-`NA`) cell values in `x`
#' with ggplot2, bars filled along the same value ramp used by
#' [plot_raster()].  Multi-layer rasters are facetted, each panel
#' scaled to its own layer.
#'
#' The raster is downsampled to at most `maxcell` cells before the
#' histogram is computed, so it approximates the distribution of a
#' large layer.
#'
#' The default colours are the "Hiroshige" palette from MetBrewer,
#' reversed so low values are dark blue and high values red, and
#' the default theme is [theme_science_map()].  Both are ordinary
#' ggplot2 components, so either can be replaced by adding a new
#' `scale_fill_*()` or theme to the returned plot.
#'
#' @param x A `SpatRaster`, or the path to a single raster file.
#' @param bins Number of bins.  Default `50`.
#' @param col Character vector of colours the bar fill ramps
#'   through, low value to high.  Defaults to a reversed
#'   "Hiroshige" ramp.  Bars are filled by where their bin sits in
#'   the layer's own range, so each facet ramps through the whole
#'   palette.
#' @param border Colour of the bar outlines.  Default `NA`, no
#'   outline.
#' @param main Plot title.  Defaults to the layer name for a
#'   single-layer raster, and to none for a facetted one, where the
#'   strips carry the names.
#' @param xlab,ylab Axis labels.  Default `"Pixel value"` and
#'   `"Count"`.
#' @param legend Logical; draw the fill legend.  Default `FALSE`,
#'   since the fill repeats what the x axis already shows.  When
#'   drawn it is labelled on 0 to 1, the bin's relative position in
#'   its layer's range.
#' @param maxcell Numeric; the raster is downsampled to this many
#'   cells before the histogram is computed.  Default `1e6`.
#' @param ... Additional arguments passed to
#'   [ggplot2::geom_histogram()], e.g. `boundary` or `alpha`.
#'
#' @return A `ggplot` object.
#'
#' @seealso [plot_raster()] for the spatial view of the same
#'   values; [raster_stats()] for them as a table;
#'   [theme_science_map()] for the theme applied.
#'
#' @examples
#' \dontrun{
#' library(terra)
#' r <- get_layer("fab_dem")
#'
#' plot_hist(r)
#' plot_hist(r, bins = 100)
#'
#' # A ggplot object, so it composes and saves as one
#' p <- plot_hist(r) + ggplot2::scale_x_log10()
#' ggplot2::ggsave("2_pipeline/fab_dem_hist.png", p,
#'                 width = 8, height = 5, dpi = 200)
#' }
#'
#' @export
plot_hist <- function(
  x,
  bins = 50,
  col = NULL,
  border = NA,
  main = NULL,
  xlab = "Pixel value",
  ylab = "Count",
  legend = FALSE,
  maxcell = 1e6,
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

  if (!is.numeric(bins) || length(bins) != 1 || is.na(bins) || bins < 1) {
    stop("`bins` must be a single positive number.")
  }

  if (is.null(col)) {
    col <- .sci_palette(256)
  }

  # 2. Valid cell values as a plottable table ----
  n_lyr <- terra::nlyr(r)
  long <- .raster_long(r, maxcell = maxcell)
  long <- long[is.finite(long$value), , drop = FALSE]

  # A layer left with no rows has no panel to draw, so say so
  # rather than let it vanish from a facetted figure.
  empty <- setdiff(
    levels(long$layer),
    unique(as.character(long$layer))
  )
  if (length(empty) > 0) {
    warning(
      "No valid cells in layer(s): ",
      paste(empty, collapse = ", "),
      "."
    )
  }

  if (is.null(main) && n_lyr == 1) {
    main <- levels(long$layer)[1]
  }

  # 3. Build the histogram ----
  # after_stat(x) is the bin midpoint; rescaling it within the
  # panel makes each facet ramp through the whole palette, the way
  # a single histogram does, instead of taking one flat colour
  # from a scale shared with a layer of a different magnitude.
  p <- ggplot2::ggplot(
    long,
    ggplot2::aes(
      x = .data$value,
      fill = ggplot2::after_stat(
        .rescale_panel(.data$x, .data$PANEL)
      )
    )
  ) +
    ggplot2::geom_histogram(
      bins = bins,
      colour = border,
      ...
    ) +
    ggplot2::scale_fill_gradientn(colours = col) +
    ggplot2::labs(
      title = main,
      x = xlab,
      y = ylab,
      fill = "Relative\nvalue"
    ) +
    # Namespaced because a package imports ggplot2 rather than
    # attaching it: unqualified theme_minimal() and friends are not
    # in scope here, even though they resolve in a session that has
    # run library(ggplot2).
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
      axis.text = ggplot2::element_text(size = 10, color = "black"),
      axis.title = ggplot2::element_text(size = 12, face = "bold"),

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
        color = NA
      ),

      # Align titles and subtitles for clarity
      plot.title = ggplot2::element_text(
        size = 14,
        face = "bold",
        hjust = 0.5
      ),
      plot.subtitle = ggplot2::element_text(size = 12, hjust = 0.5),
      plot.caption = ggplot2::element_text(size = 9, hjust = 1)
    )

  if (n_lyr > 1) {
    p <- p +
      ggplot2::facet_wrap(
        ggplot2::vars(.data$layer),
        scales = "free"
      )
  }

  if (!legend) {
    p <- p + ggplot2::guides(fill = "none")
  }

  p
}

# End of script ----
