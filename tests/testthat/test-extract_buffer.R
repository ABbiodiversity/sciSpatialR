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

test_that("extract_buffer summarises the buffer, not the cell", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  library(terra)
  library(sf)

  # A west-to-east ramp: the mean over a buffer equals the value at
  # the centre, but the sum and the range do not, so a buffer that
  # was silently ignored would show up here.
  r <- rast(nrows = 100, ncols = 100, crs = "EPSG:32632",
            xmin = 0, xmax = 10000,
            ymin = 0, ymax = 10000)
  r[] <- seq_len(ncell(r))
  names(r) <- "cov"

  pts <- st_as_sf(
    data.frame(id = 1:2, x = c(2500, 7500), y = c(5000, 5000)),
    coords = c("x", "y"), crs = 32632
  )

  point_val <- extract_points(r, pts, bind = FALSE)$cov
  summed    <- extract_buffer(r, pts, radii = 500, fun = sum,
                              bind = FALSE)

  # 500 m buffer on a 100 m grid covers many cells, so the sum is a
  # large multiple of any single value.
  expect_true(all(summed$cov_r500_sum > 10 * point_val))

  # Growing the radius must change the answer.
  wide <- extract_buffer(r, pts, radii = c(500, 2000), fun = sum,
                         bind = FALSE)
  expect_true(all(wide$cov_r2000_sum > wide$cov_r500_sum))
})

test_that("extract_buffer means match a manual buffer extraction", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  library(terra)
  library(sf)

  r <- rast(nrows = 100, ncols = 100, crs = "EPSG:32632",
            xmin = 0, xmax = 10000,
            ymin = 0, ymax = 10000)
  set.seed(1)
  r[] <- runif(ncell(r))
  names(r) <- "cov"

  pts <- st_as_sf(
    data.frame(id = 1:3, x = c(2500, 5000, 7500),
               y = c(5000, 2500, 5000)),
    coords = c("x", "y"), crs = 32632
  )

  got      <- extract_buffer(r, pts, radii = 1000, bind = FALSE)
  expected <- terra::extract(
    r, terra::buffer(terra::vect(pts), width = 1000),
    fun = mean, ID = FALSE
  )

  expect_equal(got$cov_r1000_mean, expected$cov)
})

test_that("extract_buffer passes na.rm through to fun", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  library(terra)
  library(sf)

  r <- rast(nrows = 100, ncols = 100, crs = "EPSG:32632",
            xmin = 0, xmax = 10000,
            ymin = 0, ymax = 10000)
  r[] <- 1
  r[1:2000] <- NA                       # a hole in the north
  names(r) <- "cov"

  pts <- st_as_sf(
    data.frame(id = 1, x = 5000, y = 8100),
    coords = c("x", "y"), crs = 32632
  )

  bare <- extract_buffer(r, pts, radii = 1000, bind = FALSE)
  kept <- extract_buffer(r, pts, radii = 1000, bind = FALSE,
                         na.rm = TRUE)

  expect_true(is.na(bare$cov_r1000_mean))
  expect_equal(kept$cov_r1000_mean, 1)
})

test_that("extract_buffer accepts a non-default summary function", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  library(terra)
  library(sf)

  r <- rast(nrows = 100, ncols = 100, crs = "EPSG:32632",
            xmin = 0, xmax = 10000,
            ymin = 0, ymax = 10000)
  r[] <- seq_len(ncell(r))
  names(r) <- "cov"

  pts <- st_as_sf(
    data.frame(id = 1, x = 5000, y = 5000),
    coords = c("x", "y"), crs = 32632
  )

  # Named function: label taken from the call.
  spread <- extract_buffer(r, pts, radii = 1000, fun = sd,
                           bind = FALSE)
  expect_equal(names(spread), "cov_r1000_sd")
  expect_true(spread$cov_r1000_sd > 0)

  # Inline function: unusable as a suffix, so `fun_name` supplies it.
  rng <- extract_buffer(
    r, pts, radii = 1000,
    fun = function(v, ...) max(v, ...) - min(v, ...),
    fun_name = "range", bind = FALSE
  )
  expect_equal(names(rng), "cov_r1000_range")
  expect_true(rng$cov_r1000_range > 0)

  # ...and without one, falls back to a neutral label rather than
  # deparsing the whole body into the column name.
  anon <- extract_buffer(
    r, pts, radii = 1000,
    fun = function(v, ...) max(v, ...) - min(v, ...),
    bind = FALSE
  )
  expect_equal(names(anon), "cov_r1000_stat")
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
