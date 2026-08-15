test_that("extract_proportion returns one column per class", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  library(terra)
  library(sf)

  r <- rast(nrows = 100, ncols = 100, crs = "EPSG:32632",
            xmin = 0, xmax = 10000,
            ymin = 0, ymax = 10000)
  set.seed(1)
  r[] <- sample(1:3, ncell(r), replace = TRUE)
  names(r) <- "cover"

  pts <- st_as_sf(
    data.frame(id = 1:2, x = c(2500, 7500), y = c(5000, 5000)),
    coords = c("x", "y"), crs = 32632
  )

  result <- extract_proportion(r, pts, radius = 1000)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2L)
  expect_true(all(c("cover_1", "cover_2", "cover_3") %in%
                    names(result)))
})

test_that("extract_proportion summarises the buffer, not the cell", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  library(terra)
  library(sf)

  # Half the raster is class 1, half class 2, split at x = 5000.
  # A point on the divide sees both classes; a buffer that was
  # silently ignored would return a one-hot row instead.
  r <- rast(nrows = 100, ncols = 100, crs = "EPSG:32632",
            xmin = 0, xmax = 10000,
            ymin = 0, ymax = 10000)
  r   <- init(r, "x")
  r   <- ifel(r < 5000, 1, 2)
  names(r) <- "cover"

  pts <- st_as_sf(
    data.frame(id = 1, x = 5000, y = 5000),
    coords = c("x", "y"), crs = 32632
  )

  props <- extract_proportion(r, pts, radius = 2000, bind = FALSE)
  expect_equal(unname(unlist(props)), c(0.5, 0.5), tolerance = 0.05)
})

test_that("extract_proportion rows sum to one and zero-fill", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  library(terra)
  library(sf)

  # Three horizontal bands; two points far enough apart that each
  # buffer sees only its own band.
  r <- rast(nrows = 90, ncols = 90, crs = "EPSG:32632",
            xmin = 0, xmax = 9000,
            ymin = 0, ymax = 9000)
  r <- init(r, "y")
  r <- classify(
    r,
    matrix(c(-Inf, 3000, 1,
             3000, 6000, 2,
             6000, Inf, 3),
           ncol = 3, byrow = TRUE)
  )
  names(r) <- "cover"

  pts <- st_as_sf(
    data.frame(id = 1:2, x = c(4500, 4500), y = c(1500, 7500)),
    coords = c("x", "y"), crs = 32632
  )

  props <- extract_proportion(r, pts, radius = 1000, bind = FALSE)
  expect_equal(unname(rowSums(props)), c(1, 1))

  # Class 2 is never seen, so its column is absent; the classes that
  # are seen are zero in the buffer that does not contain them.
  expect_equal(sort(names(props)), c("cover_1", "cover_3"))
  expect_equal(props$cover_3[1], 0)
  expect_equal(props$cover_1[2], 0)
})

test_that("extract_proportion ignores NA cells in the buffer", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  library(terra)
  library(sf)

  # Half the buffer is masked; proportions are of the valid cells,
  # so they still sum to one.
  r <- rast(nrows = 100, ncols = 100, crs = "EPSG:32632",
            xmin = 0, xmax = 10000,
            ymin = 0, ymax = 10000)
  r <- init(r, "x")
  r <- ifel(r < 5000, 1, NA)
  names(r) <- "cover"

  pts <- st_as_sf(
    data.frame(id = 1, x = 5000, y = 5000),
    coords = c("x", "y"), crs = 32632
  )

  props <- extract_proportion(r, pts, radius = 2000, bind = FALSE)
  expect_equal(names(props), "cover_1")
  expect_equal(props$cover_1, 1)
})

test_that("extract_proportion validates its inputs", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  library(terra)
  library(sf)

  r <- rast(nrows = 10, ncols = 10, crs = "EPSG:32632",
            xmin = 0, xmax = 1000, ymin = 0, ymax = 1000)
  r[] <- 1
  names(r) <- "cover"

  pts <- st_as_sf(data.frame(x = 500, y = 500),
                  coords = c("x", "y"), crs = 32632)

  expect_error(extract_proportion(c(r, r), pts, radius = 100),
               "single-layer")
  expect_error(extract_proportion(r, pts, radius = -1),
               "positive")
  expect_error(extract_proportion(r, pts, radius = c(100, 200)),
               "positive")
})
