test_that("aggregate_to_grid returns coarsened raster", {
  skip_if_not_installed("terra")
  library(terra)

  r <- rast(nrows = 40, ncols = 40, crs = "EPSG:4326",
            xmin = 0, xmax = 1, ymin = 0, ymax = 1)
  r[] <- runif(ncell(r))

  ref <- rast(nrows = 10, ncols = 10, crs = "EPSG:4326",
              xmin = 0, xmax = 1, ymin = 0, ymax = 1)

  result <- aggregate_to_grid(r, ref)
  expect_s4_class(result, "SpatRaster")
  expect_equal(nrow(result), nrow(ref))
  expect_equal(ncol(result), ncol(ref))
})

test_that("aggregate_to_grid keeps class codes when categorical", {
  skip_if_not_installed("terra")
  library(terra)

  r <- rast(nrows = 40, ncols = 40, crs = "EPSG:4326",
            xmin = 0, xmax = 1, ymin = 0, ymax = 1)
  # Coherent bands so the modal class of each block is unambiguous.
  r <- (init(r, "row") - 1) %/% 10 + 1

  ref <- rast(nrows = 10, ncols = 10, crs = "EPSG:4326",
              xmin = 0, xmax = 1, ymin = 0, ymax = 1)

  result <- aggregate_to_grid(r, ref, categorical = TRUE)
  expect_s4_class(result, "SpatRaster")
  expect_setequal(unique(values(result))[, 1], 1:4)
})

test_that("aggregate_to_grid errors when ref is finer than x", {
  skip_if_not_installed("terra")
  library(terra)

  r   <- rast(nrows = 10, ncols = 10, crs = "EPSG:4326",
              xmin = 0, xmax = 1, ymin = 0, ymax = 1)
  ref <- rast(nrows = 40, ncols = 40, crs = "EPSG:4326",
              xmin = 0, xmax = 1, ymin = 0, ymax = 1)
  r[] <- 1
  expect_error(aggregate_to_grid(r, ref), "coarser")
})
