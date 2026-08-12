test_that("extract_buffer returns data.frame with radius columns", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  library(terra)
  library(sf)

  r <- rast(nrows = 100, ncols = 100, crs = "EPSG:32632",
            xmin = 0, xmax = 10000,
            ymin = 0, ymax = 10000)
  r[] <- runif(ncell(r))
  names(r) <- "cov"

  pts <- st_as_sf(
    data.frame(id = 1:2, x = c(2500, 7500), y = c(5000, 5000)),
    coords = c("x", "y"), crs = 32632
  )

  result <- extract_buffer(r, pts, radii = c(200, 500))
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2L)
  expect_true("cov_r200_mean" %in% names(result))
  expect_true("cov_r500_mean" %in% names(result))
})

test_that("extract_buffer errors on non-positive radii", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  library(terra)
  library(sf)

  r   <- rast(nrows = 10, ncols = 10)
  r[] <- 1
  pts <- st_as_sf(data.frame(x = 0, y = 0),
                  coords = c("x", "y"), crs = 4326)
  expect_error(
    extract_buffer(r, pts, radii = -1),
    "positive"
  )
})
