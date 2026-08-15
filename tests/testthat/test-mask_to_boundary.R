make_ab_raster <- function() {
  r <- terra::rast(ab_grid())
  terra::values(r) <- 1
  r
}

test_that("the default boundary masks to Alberta", {
  r      <- make_ab_raster()
  masked <- mask_to_boundary(r)

  expect_s4_class(masked, "SpatRaster")

  n_all <- terra::global(r, "notNA")[1, 1]
  n_ab  <- terra::global(masked, "notNA")[1, 1]
  expect_lt(n_ab, n_all)

  # "alberta" is the documented default, so naming it explicitly
  # must give the same answer.
  expect_equal(
    terra::global(mask_to_boundary(r, "alberta"), "notNA")[1, 1],
    n_ab
  )
})

test_that("inverse keeps the complement", {
  r <- make_ab_raster()

  inside  <- terra::global(mask_to_boundary(r), "notNA")[1, 1]
  outside <- terra::global(
    mask_to_boundary(r, inverse = TRUE), "notNA"
  )[1, 1]

  expect_equal(inside + outside, terra::global(r, "notNA")[1, 1])
})

test_that("alberta is the only character shortcut", {
  r <- make_ab_raster()

  # "natural_regions" was accepted as a shortcut but resolved to a
  # file that does not ship with the package, so it always failed.
  # It is now rejected as an unknown shortcut instead.
  expect_error(
    mask_to_boundary(r, "natural_regions"), "Unknown boundary"
  )
  expect_error(
    mask_to_boundary(r, "natural_regions"), "only shortcut"
  )
  expect_error(mask_to_boundary(r, "anything"), "Unknown boundary")

  # No shortcut should point at a missing extdata file any more.
  expect_error(mask_to_boundary(r, "alberta"), NA)
})

test_that("shortcuts are matched case- and space-insensitively", {
  r <- make_ab_raster()
  expect_error(mask_to_boundary(r, "  Alberta "), NA)
  expect_error(mask_to_boundary(r, "ALBERTA"), NA)
})

test_that("a polygon can be supplied directly", {
  r <- make_ab_raster()

  poly <- terra::vect(
    terra::ext(400000, 500000, 5800000, 5900000),
    crs = ab_crs()
  )
  from_vect <- mask_to_boundary(r, poly)
  expect_gt(terra::global(from_vect, "notNA")[1, 1], 0)

  # sf polygons are accepted too, and reprojected when needed.
  poly_sf <- sf::st_as_sf(poly)
  expect_equal(
    terra::global(mask_to_boundary(r, poly_sf), "notNA")[1, 1],
    terra::global(from_vect, "notNA")[1, 1]
  )

  poly_ll <- sf::st_transform(poly_sf, 4326)
  expect_equal(
    terra::global(mask_to_boundary(r, poly_ll), "notNA")[1, 1],
    terra::global(from_vect, "notNA")[1, 1],
    tolerance = 0.01
  )
})

test_that("mask_to_boundary validates its arguments", {
  r <- make_ab_raster()

  expect_error(mask_to_boundary("not a raster"), "SpatRaster")
  expect_error(mask_to_boundary(r, 42), "SpatVector")
})
