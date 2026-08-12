test_that("harmonize_crs returns sf with target CRS", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  library(terra)
  library(sf)

  ref <- rast(nrows = 10, ncols = 10, crs = "EPSG:3400",
              xmin = 0, xmax = 1e5, ymin = 0, ymax = 1e5)
  pts <- st_as_sf(
    data.frame(x = c(-114, -113), y = c(53, 54)),
    coords = c("x", "y"), crs = 4326
  )

  result <- suppressWarnings(harmonize_crs(pts, ref))
  expect_s3_class(result, "sf")
  # Compare the EPSG code, not the whole st_crs object: the CRS is
  # round-tripped through terra::crs() as WKT, so $input carries the
  # CRS name rather than the "EPSG:3400" string.
  expect_equal(st_crs(result)$epsg, 3400L)
})

test_that("harmonize_crs returns unchanged points when CRS matches", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  library(terra)
  library(sf)

  ref <- rast(nrows = 10, ncols = 10, crs = "EPSG:4326",
              xmin = -120, xmax = -110, ymin = 49, ymax = 60)
  pts <- st_as_sf(
    data.frame(x = c(-114, -113), y = c(53, 54)),
    coords = c("x", "y"), crs = 4326
  )

  result <- harmonize_crs(pts, ref, warn = FALSE)
  expect_equal(result, pts)
})

test_that("harmonize_crs errors on non-sf input", {
  skip_if_not_installed("terra")
  library(terra)
  ref <- rast(nrows = 5, ncols = 5, crs = "EPSG:4326",
              xmin = 0, xmax = 1, ymin = 0, ymax = 1)
  expect_error(harmonize_crs(list(), ref), "`points` must be an sf")
})
