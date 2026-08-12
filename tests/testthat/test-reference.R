test_that("ab_crs returns the Alberta 10-TM Forest CRS", {
  skip_if_not_installed("sf")
  library(sf)

  expect_identical(ab_crs(), "EPSG:3400")
  expect_equal(st_crs(ab_crs())$epsg, 3400L)
})

test_that("ab_boundary returns one polygon in ab_crs", {
  skip_if_not_installed("terra")
  library(terra)

  ab <- ab_boundary()
  expect_s4_class(ab, "SpatVector")
  expect_equal(nrow(ab), 1)
  expect_equal(geomtype(ab), "polygons")
  expect_true(same.crs(ab, ab_crs()))
})

test_that("ab_grid matches the documented grid geometry", {
  skip_if_not_installed("terra")
  library(terra)

  ref <- ab_grid()
  expect_s4_class(ref, "SpatRaster")
  expect_equal(nlyr(ref), 1)
  expect_equal(names(ref), "grid_1km")
  expect_true(same.crs(ref, ab_crs()))

  # Geometry recorded in inst/extdata/README.md; a rebuild that
  # shifts the lattice would silently break every harmonised layer.
  expect_equal(dim(ref)[1:2], c(1234L, 695L))
  expect_equal(res(ref), c(1000, 1000))
  expect_equal(
    as.vector(ext(ref)),
    c(
      xmin = 170616.1822, xmax = 865616.1822,
      ymin = 5425532.4311, ymax = 6659532.4311
    ),
    tolerance = 1e-4
  )
})

test_that("ab_grid covers the 664,762 cells of the source grid", {
  skip_if_not_installed("terra")
  library(terra)

  ref <- ab_grid()
  expect_equal(unname(global(ref, "notNA")[[1]]), 664762)
  expect_setequal(unique(values(ref, na.rm = TRUE)), 1)
})

test_that("ab_grid contains the Alberta boundary", {
  skip_if_not_installed("terra")
  library(terra)

  ref <- ab_grid()
  ab <- ab_boundary()

  # Every part of the province must fall inside the template, or
  # layers masked to Alberta would be clipped by the grid.
  expect_true(
    relate(as.polygons(ext(ref)), as.polygons(ext(ab)), "covers")[1]
  )
})

test_that("harmonisation functions default to the reference grid", {
  skip_if_not_installed("terra")
  library(terra)

  ref <- ab_grid()

  # check_alignment: the reference grid agrees with itself.
  result <- check_alignment(ref, verbose = FALSE)
  expect_true(all(result))

  # resample_to_grid: a coarse Alberta raster lands on the grid.
  r <- rast(
    nrows = 50, ncols = 50, crs = ab_crs(),
    xmin = 3e5, xmax = 5e5, ymin = 58e5, ymax = 60e5
  )
  values(r) <- runif(ncell(r))

  resampled <- resample_to_grid(r)
  expect_equal(as.vector(ext(resampled)), as.vector(ext(ref)))
  expect_equal(res(resampled), res(ref))
})

test_that("mask_to_boundary defaults to the Alberta boundary", {
  skip_if_not_installed("terra")
  library(terra)

  # A raster spanning Alberta and well beyond its eastern edge, so
  # masking must drop cells.
  r <- rast(
    nrows = 40, ncols = 40, crs = ab_crs(),
    xmin = 6e5, xmax = 12e5, ymin = 58e5, ymax = 62e5
  )
  values(r) <- 1

  masked <- mask_to_boundary(r)
  expect_s4_class(masked, "SpatRaster")
  expect_lt(
    global(masked, "notNA")[[1]],
    global(r, "notNA")[[1]]
  )
  expect_gt(global(masked, "notNA")[[1]], 0)
})

test_that("harmonize_crs messages rather than warns on the default", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  library(terra)
  library(sf)

  pts <- st_as_sf(
    data.frame(x = c(-114, -113), y = c(53, 54)),
    coords = c("x", "y"), crs = 4326
  )

  expect_message(
    result <- harmonize_crs(pts),
    "reference grid CRS"
  )
  expect_equal(st_crs(result)$epsg, 3400L)
})
