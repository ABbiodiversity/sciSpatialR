test_that("raster_stats summarises a single layer", {
  skip_if_not_installed("terra")
  library(terra)
  r <- rast(nrows = 10, ncols = 10, crs = "EPSG:4326")
  values(r) <- c(rep(NA, 10), 11:100)
  names(r) <- "test_layer"

  res <- raster_stats(r, aoi = NULL, verbose = FALSE)
  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), 1)
  expect_equal(res$layer, "test_layer")
  expect_equal(res$n_total, 100)
  expect_equal(res$n_na, 10)
  expect_equal(res$n_valid, 90)
  expect_equal(res$pct_na, 10)
  expect_equal(res$min, 11)
  expect_equal(res$max, 100)
  expect_equal(res$mean, mean(11:100))
})

test_that("raster_stats returns one row per layer", {
  skip_if_not_installed("terra")
  library(terra)
  a <- rast(nrows = 5, ncols = 5)
  values(a) <- 1:25
  names(a) <- "a"
  b <- a * 2
  names(b) <- "b"

  res <- raster_stats(c(a, b), aoi = NULL, verbose = FALSE)
  expect_equal(nrow(res), 2)
  expect_equal(res$layer, c("a", "b"))
  expect_equal(res$max, c(25, 50))
})

test_that("raster_stats reports NA for all-NA layers", {
  skip_if_not_installed("terra")
  library(terra)
  r <- rast(nrows = 5, ncols = 5)
  values(r) <- NA

  res <- raster_stats(r, aoi = NULL, verbose = FALSE)
  expect_equal(res$n_valid, 0)
  expect_equal(res$pct_na, 100)
  expect_true(is.na(res$min))
  expect_true(is.na(res$mean))
  expect_false(is.nan(res$mean))
})

test_that("raster_stats adds requested quantile columns", {
  skip_if_not_installed("terra")
  library(terra)
  r <- rast(nrows = 10, ncols = 10)
  values(r) <- 1:100

  res <- raster_stats(
    r,
    aoi = NULL,
    quantiles = c(0.02, 0.5, 0.98),
    verbose = FALSE
  )
  expect_true(all(c("q2", "q50", "q98") %in% names(res)))
  expect_equal(
    res$q50,
    stats::quantile(1:100, 0.5, names = FALSE)
  )
})

test_that("raster_stats reads rasters from a directory", {
  skip_if_not_installed("terra")
  library(terra)
  dir <- withr::local_tempdir()
  r <- rast(nrows = 5, ncols = 5)
  values(r) <- 1:25
  writeRaster(r, file.path(dir, "layer_one.tif"))
  writeRaster(r * 2, file.path(dir, "layer_two.tif"))

  res <- raster_stats(dir, aoi = NULL, verbose = FALSE)
  expect_equal(nrow(res), 2)
  # Bands written without a name take the file's name instead of
  # terra's "lyr.1".
  expect_setequal(res$layer, c("layer_one", "layer_two"))
  expect_setequal(
    res$source,
    c("layer_one.tif", "layer_two.tif")
  )
  expect_equal(sort(res$max), c(25, 50))
})

test_that("raster_stats prints a definition of each column", {
  skip_if_not_installed("terra")
  library(terra)
  r <- rast(nrows = 5, ncols = 5)
  values(r) <- 1:25

  out <- capture_output(raster_stats(r, aoi = NULL, quantiles = 0.5))
  expect_match(out, "Columns:")
  expect_match(out, "n_valid\\s+Cells carrying a value")
  expect_match(out, "q50\\s+Value below which 50% of valid cells")

  # Quantile definitions appear only when quantiles were asked for
  out_plain <- capture_output(raster_stats(r, aoi = NULL))
  expect_false(grepl("q50", out_plain))

  expect_silent(raster_stats(r, aoi = NULL, verbose = FALSE))
})

test_that("raster_stats validates its inputs", {
  skip_if_not_installed("terra")
  library(terra)
  r <- rast(nrows = 5, ncols = 5)
  values(r) <- 1:25

  expect_error(raster_stats(1), "must be a SpatRaster")
  expect_error(
    raster_stats("no_such_path_here"),
    "does not exist"
  )
  expect_error(
    raster_stats(r, aoi = NULL, quantiles = c(0.5, 2)),
    "probabilities"
  )
  expect_error(raster_stats(r, aoi = NULL, maxcell = 0), "positive")
})

test_that("statistics cover only the cells inside the aoi", {
  skip_if_not_installed("terra")
  library(terra)

  # A full-extent layer on the reference grid: every cell of the
  # rectangle carries a value, but only the Alberta cells count.
  r <- rast(ab_grid())
  values(r) <- 1
  names(r) <- "ones"

  res <- raster_stats(r, verbose = FALSE)
  n_ab <- global(mask_to_boundary(r), "notNA")[1, 1]

  expect_equal(res$n_total, n_ab)
  expect_equal(res$n_valid, n_ab)
  expect_equal(res$n_na, 0)
  expect_equal(res$pct_na, 0)
  expect_lt(res$n_total, ncell(r))

  # aoi = NULL summarises the rectangle instead.
  all_cells <- raster_stats(r, aoi = NULL, verbose = FALSE)
  expect_equal(all_cells$n_total, ncell(r))
  expect_gt(all_cells$n_valid, res$n_valid)
})

test_that("values outside the aoi do not reach the summaries", {
  skip_if_not_installed("terra")
  library(terra)

  # Everything inside Alberta is 1; a corner well outside it is
  # given an absurd value that must not appear in the summaries.
  r <- rast(ab_grid())
  values(r) <- 1
  r[1, 1] <- 1000

  res <- raster_stats(r, verbose = FALSE)
  expect_equal(res$max, 1)
  expect_equal(res$mean, 1)

  outside <- raster_stats(r, aoi = NULL, verbose = FALSE)
  expect_equal(outside$max, 1000)
})

test_that("n_na counts aoi cells the layer leaves empty", {
  skip_if_not_installed("terra")
  library(terra)

  ref <- ab_grid()
  r   <- rast(ref)
  values(r) <- 1
  r <- mask(r, ref)

  # A hole punched inside the province, and the whole surround
  # left NA, which the aoi excludes.
  r[300:360, 180:240] <- NA

  res <- raster_stats(r, verbose = FALSE)
  expect_gt(res$n_na, 0)
  expect_equal(res$n_total, res$n_na + res$n_valid)
  expect_equal(res$pct_na, 100 * res$n_na / res$n_total)
  expect_lt(res$pct_na, 100)
})

test_that("the aoi accepts a polygon and reports it in the legend", {
  skip_if_not_installed("terra")
  library(terra)

  r <- rast(ab_grid())
  values(r) <- 1

  poly <- vect(
    ext(400000, 500000, 5800000, 5900000),
    crs = ab_crs()
  )
  from_vect <- raster_stats(r, aoi = poly, verbose = FALSE)

  # The same cells mask_to_boundary() keeps: a 100 km square that
  # reaches into one more row and column because it does not sit
  # on the grid lattice.
  n_poly <- global(mask_to_boundary(r, poly), "notNA")[1, 1]
  expect_equal(from_vect$n_total, n_poly)
  expect_equal(from_vect$n_valid, n_poly)
  expect_equal(from_vect$n_total, 101 * 101)

  # sf polygons are accepted too, and reprojected when needed.
  poly_sf <- sf::st_as_sf(poly)
  expect_equal(
    raster_stats(r, aoi = poly_sf, verbose = FALSE)$n_total,
    from_vect$n_total
  )

  out <- capture_output(raster_stats(r, aoi = poly))
  expect_match(out, "Cells within the supplied polygon only")

  out_ab <- capture_output(raster_stats(r))
  expect_match(out_ab, "Cells within Alberta only")
  expect_match(out_ab, "n_total\\s+Cells the aoi covers")
})

test_that("a layer outside the aoi returns empty counts", {
  skip_if_not_installed("terra")
  library(terra)

  # Somewhere in the Pacific: no cell falls inside Alberta.
  r <- rast(
    nrows = 5, ncols = 5,
    xmin = -160, xmax = -150, ymin = 10, ymax = 20,
    crs = "EPSG:4326"
  )
  values(r) <- 1:25
  names(r) <- "far_away"

  expect_warning(
    res <- raster_stats(r, verbose = FALSE),
    "far_away"
  )
  expect_equal(res$n_total, 0)
  expect_equal(res$n_valid, 0)
  expect_true(is.na(res$pct_na))
  expect_true(is.na(res$mean))
})

test_that("raster_stats validates the aoi", {
  skip_if_not_installed("terra")
  library(terra)
  r <- rast(nrows = 5, ncols = 5)
  values(r) <- 1:25

  expect_error(raster_stats(r, aoi = 42), "SpatVector")
  expect_error(raster_stats(r, aoi = "nowhere"), "Unknown boundary")
})
