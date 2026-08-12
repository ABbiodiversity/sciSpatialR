test_that("resample_to_grid returns SpatRaster matching ref", {
  skip_if_not_installed("terra")
  library(terra)

  ref <- rast(nrows = 20, ncols = 20, crs = "EPSG:4326",
              xmin = 0, xmax = 1, ymin = 0, ymax = 1)
  r   <- rast(nrows = 10, ncols = 10, crs = "EPSG:4326",
              xmin = 0, xmax = 1, ymin = 0, ymax = 1)
  r[] <- runif(ncell(r))

  result <- resample_to_grid(r, ref)
  expect_s4_class(result, "SpatRaster")
  expect_equal(nrow(result), nrow(ref))
  expect_equal(ncol(result), ncol(ref))
})

test_that("resample_to_grid uses near for categorical", {
  skip_if_not_installed("terra")
  library(terra)

  ref <- rast(nrows = 20, ncols = 20, crs = "EPSG:4326",
              xmin = 0, xmax = 1, ymin = 0, ymax = 1)
  r   <- rast(nrows = 10, ncols = 10, crs = "EPSG:4326",
              xmin = 0, xmax = 1, ymin = 0, ymax = 1)
  r[] <- sample(1:3, ncell(r), replace = TRUE)

  # Should complete without error; near is silent
  result <- resample_to_grid(r, ref, categorical = TRUE)
  expect_s4_class(result, "SpatRaster")
  expect_true(all(values(result) %in% c(1:3, NA)))
})
