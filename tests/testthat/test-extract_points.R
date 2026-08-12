test_that("extract_points returns data.frame with correct rows", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  library(terra)
  library(sf)

  r <- rast(nrows = 10, ncols = 10, crs = "EPSG:4326",
            xmin = -5, xmax = 5, ymin = -5, ymax = 5)
  r[] <- seq_len(ncell(r))
  names(r) <- "val"

  pts <- st_as_sf(
    data.frame(id = 1:3, x = c(-4, 0, 4), y = c(-4, 0, 4)),
    coords = c("x", "y"), crs = 4326
  )

  result <- extract_points(r, pts)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3L)
  expect_true("val" %in% names(result))
  expect_true("id"  %in% names(result))
})

test_that("extract_points bind = FALSE returns only raster values", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  library(terra)
  library(sf)

  r <- rast(nrows = 10, ncols = 10, crs = "EPSG:4326",
            xmin = -5, xmax = 5, ymin = -5, ymax = 5)
  r[] <- 1
  names(r) <- "val"

  pts <- st_as_sf(
    data.frame(x = 0, y = 0),
    coords = c("x", "y"), crs = 4326
  )

  result <- extract_points(r, pts, bind = FALSE)
  expect_equal(names(result), "val")
})
