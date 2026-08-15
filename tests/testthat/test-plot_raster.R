# plot_raster() returns a ggplot rather than drawing, so the tests
# build the plot to force ggplot2 to evaluate the layers.

test_that("plot_raster returns a ggplot that builds", {
  skip_if_not_installed("terra")
  library(terra)
  r <- rast(nrows = 10, ncols = 10, crs = "EPSG:3400",
            xmin = 0, xmax = 1e4, ymin = 0, ymax = 1e4)
  values(r) <- 1:100
  names(r) <- "test_layer"

  p <- plot_raster(r, boundary = NULL)
  expect_s3_class(p, "ggplot")
  expect_silent(ggplot2::ggplot_build(p))
  # The layer name becomes the title of a single-layer map.
  expect_equal(p$labels$title, "test_layer")
})

test_that("plot_raster clamps the scale to the stretch quantiles", {
  skip_if_not_installed("terra")
  library(terra)
  r <- rast(nrows = 10, ncols = 10)
  values(r) <- 1:100

  p <- plot_raster(r, stretch = c(0.1, 0.9), boundary = NULL)
  built <- ggplot2::ggplot_build(p)
  expect_equal(
    built$plot$scales$get_scales("fill")$limits,
    stats::quantile(1:100, c(0.1, 0.9), names = FALSE)
  )

  # Out-of-range cells are squished to the end colours, not
  # dropped as NA.
  fills <- built$data[[1]]$fill
  expect_false(any(is.na(fills)))
})

test_that("plot_raster draws masked cells as gaps, not shifts", {
  skip_if_not_installed("terra")
  library(terra)
  # Interior columns masked, as any clipped layer has. geom_raster
  # reads the gap as uneven spacing and shifts pixels to close it;
  # tiles sized from the resolution stay put.
  r <- rast(nrows = 40, ncols = 40, xmin = 0, xmax = 4e4,
            ymin = 0, ymax = 4e4, crs = "EPSG:3400")
  values(r) <- 1:1600
  r[, 18:23] <- NA

  p <- plot_raster(r, boundary = NULL)
  expect_s3_class(p$layers[[1]]$geom, "GeomTile")

  drawn <- ggplot2::ggplot_build(p)$data[[1]]
  expect_equal(unique(drawn$xmax - drawn$xmin), terra::res(r)[1])
  # The masked columns leave a hole rather than being papered over.
  expect_equal(length(unique(drawn$x)), 34)

  # The shifting geom_raster warns about happens when the plot is
  # drawn, not built, so this has to print. A null device keeps it
  # from leaving an Rplots.pdf behind.
  grDevices::pdf(NULL)
  withr::defer(grDevices::dev.off())
  expect_silent(print(p))
})

test_that("plot_raster corrects the aspect of lonlat rasters", {
  skip_if_not_installed("terra")
  library(terra)
  proj <- rast(nrows = 5, ncols = 5, xmin = 0, xmax = 5e3,
               ymin = 0, ymax = 5e3, crs = "EPSG:3400")
  values(proj) <- 1:25
  lonlat <- rast(nrows = 5, ncols = 5, xmin = -120, xmax = -110,
                 ymin = 49, ymax = 60, crs = "EPSG:4326")
  values(lonlat) <- 1:25

  expect_equal(
    plot_raster(proj, boundary = NULL)$coordinates$ratio, 1
  )
  expect_equal(
    plot_raster(lonlat, boundary = NULL)$coordinates$ratio,
    1 / cos(54.5 * pi / 180)
  )
})

test_that("plot_raster handles flat and all-NA layers", {
  skip_if_not_installed("terra")
  library(terra)
  flat <- rast(nrows = 5, ncols = 5)
  values(flat) <- 7
  empty <- rast(nrows = 5, ncols = 5)
  values(empty) <- NA

  expect_silent(ggplot2::ggplot_build(
    plot_raster(flat, boundary = NULL)
  ))
  expect_silent(ggplot2::ggplot_build(
    plot_raster(empty, boundary = NULL)
  ))
})

test_that("plot_raster facets a multi-layer raster", {
  skip_if_not_installed("terra")
  library(terra)
  a <- rast(nrows = 5, ncols = 5)
  values(a) <- 1:25
  names(a) <- "a"
  b <- a * 2
  names(b) <- "b"

  p <- plot_raster(c(a, b), boundary = NULL)
  built <- ggplot2::ggplot_build(p)
  expect_s3_class(p$facet, "FacetWrap")
  expect_equal(nlevels(built$plot$data$layer), 2)
})

test_that("plot_raster draws the boundary overlay", {
  skip_if_not_installed("terra")
  library(terra)
  r <- ab_grid()

  p <- plot_raster(r)
  # Raster first, boundary polygon second.
  expect_length(p$layers, 2)
  expect_s3_class(p$layers[[2]]$geom, "GeomPolygon")
})

test_that("plot_raster validates its inputs", {
  skip_if_not_installed("terra")
  library(terra)
  r <- rast(nrows = 5, ncols = 5)
  values(r) <- 1:25

  expect_error(
    plot_raster(r, stretch = c(0.9, 0.1)),
    "increasing probabilities"
  )
  expect_error(
    plot_raster(r, boundary = 42),
    "must be a SpatVector"
  )
  expect_error(
    plot_raster(r, boundary = "atlantis"),
    "Unknown boundary shortcut"
  )
})
