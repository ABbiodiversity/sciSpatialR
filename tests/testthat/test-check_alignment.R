test_that("check_alignment returns named logical vector", {
  skip_if_not_installed("terra")
  library(terra)
  ref <- rast(nrows = 10, ncols = 10, crs = "EPSG:4326",
              xmin = 0, xmax = 1, ymin = 0, ymax = 1)
  r   <- rast(nrows = 10, ncols = 10, crs = "EPSG:4326",
              xmin = 0, xmax = 1, ymin = 0, ymax = 1)

  result <- check_alignment(r, ref, verbose = FALSE)
  expect_true(is.logical(result))
  expect_true(all(result))
  expect_named(result, c("crs", "extent", "resolution", "origin"))
})

test_that("check_alignment detects CRS mismatch", {
  skip_if_not_installed("terra")
  library(terra)
  ref <- rast(nrows = 10, ncols = 10, crs = "EPSG:4326",
              xmin = 0, xmax = 1, ymin = 0, ymax = 1)
  r   <- rast(nrows = 10, ncols = 10, crs = "EPSG:32632",
              xmin = 0, xmax = 1e5, ymin = 0, ymax = 1e5)

  result <- check_alignment(r, ref, verbose = FALSE)
  expect_false(result["crs"])
})

test_that("check_alignment errors on bad ref", {
  skip_if_not_installed("terra")
  expect_error(check_alignment(1, 2), "`ref` must be a SpatRaster")
})
