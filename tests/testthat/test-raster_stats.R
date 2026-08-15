test_that("raster_stats summarises a single layer", {
  skip_if_not_installed("terra")
  library(terra)
  r <- rast(nrows = 10, ncols = 10, crs = "EPSG:4326")
  values(r) <- c(rep(NA, 10), 11:100)
  names(r) <- "test_layer"

  res <- raster_stats(r, verbose = FALSE)
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

  res <- raster_stats(c(a, b), verbose = FALSE)
  expect_equal(nrow(res), 2)
  expect_equal(res$layer, c("a", "b"))
  expect_equal(res$max, c(25, 50))
})

test_that("raster_stats reports NA for all-NA layers", {
  skip_if_not_installed("terra")
  library(terra)
  r <- rast(nrows = 5, ncols = 5)
  values(r) <- NA

  res <- raster_stats(r, verbose = FALSE)
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

  res <- raster_stats(dir, verbose = FALSE)
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

  out <- capture_output(raster_stats(r, quantiles = 0.5))
  expect_match(out, "Columns:")
  expect_match(out, "n_valid\\s+Cells carrying a value")
  expect_match(out, "q50\\s+Value below which 50% of valid cells")

  # Quantile definitions appear only when quantiles were asked for
  out_plain <- capture_output(raster_stats(r))
  expect_false(grepl("q50", out_plain))

  expect_silent(raster_stats(r, verbose = FALSE))
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
    raster_stats(r, quantiles = c(0.5, 2)),
    "probabilities"
  )
  expect_error(raster_stats(r, maxcell = 0), "positive")
})
