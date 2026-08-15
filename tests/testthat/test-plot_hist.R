# plot_hist() returns a ggplot rather than drawing, so the tests
# build the plot to force ggplot2 to compute the bins.

test_that("plot_hist returns a ggplot that builds", {
  skip_if_not_installed("terra")
  library(terra)
  r <- rast(nrows = 10, ncols = 10)
  values(r) <- c(rep(NA, 10), 11:100)
  names(r) <- "test_layer"

  p <- plot_hist(r)
  expect_s3_class(p, "ggplot")
  built <- ggplot2::ggplot_build(p)
  # NA cells are dropped before the histogram is computed.
  expect_equal(sum(built$data[[1]]$count), 90)
  expect_equal(p$labels$title, "test_layer")
})

test_that("plot_hist honours the requested bin count", {
  skip_if_not_installed("terra")
  library(terra)
  r <- rast(nrows = 10, ncols = 10)
  values(r) <- 1:100

  built <- ggplot2::ggplot_build(plot_hist(r, bins = 20))
  expect_equal(nrow(built$data[[1]]), 20)
})

test_that("plot_hist facets a multi-layer raster", {
  skip_if_not_installed("terra")
  library(terra)
  a <- rast(nrows = 5, ncols = 5)
  values(a) <- 1:25
  names(a) <- "a"
  b <- a * 2
  names(b) <- "b"

  p <- plot_hist(c(a, b))
  expect_s3_class(p$facet, "FacetWrap")
  expect_equal(nlevels(p$data$layer), 2)
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("plot_hist warns on an all-NA layer", {
  skip_if_not_installed("terra")
  library(terra)
  r <- rast(nrows = 5, ncols = 5)
  values(r) <- NA

  expect_warning(p <- plot_hist(r), "No valid cells")
  expect_s3_class(p, "ggplot")
  expect_equal(nrow(p$data), 0)
})

test_that("plot_hist validates its inputs", {
  skip_if_not_installed("terra")
  library(terra)
  r <- rast(nrows = 5, ncols = 5)
  values(r) <- 1:25

  expect_error(plot_hist(r, bins = 0), "positive")
  expect_error(plot_hist(1), "must be a SpatRaster")
})
