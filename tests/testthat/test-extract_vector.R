# Square helper: a closed polygon from its bounds, so the fixtures
# below read as coordinates rather than as ring construction.
sq <- function(xmin, xmax, ymin, ymax) {
  sf::st_polygon(list(cbind(
    c(xmin, xmax, xmax, xmin, xmin),
    c(ymin, ymin, ymax, ymax, ymin)
  )))
}

test_that("extract_vector joins polygon attributes to points", {
  skip_if_not_installed("sf")
  library(sf)

  pts <- st_as_sf(
    data.frame(id = 1:2, x = c(2, 8), y = c(2, 8)),
    coords = c("x", "y"), crs = 3400
  )
  poly <- st_sf(
    zone  = c("west", "east"),
    crew  = c("A", "B"),
    geometry = st_sfc(sq(0, 5, 0, 10), sq(5, 10, 0, 10), crs = 3400)
  )

  result <- extract_vector(pts, poly)
  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 2L)
  expect_equal(result$zone, c("west", "east"))
  expect_equal(result$crew, c("A", "B"))
  expect_equal(result$id, 1:2)
})

test_that("extract_vector returns NA outside every polygon", {
  skip_if_not_installed("sf")
  library(sf)

  pts <- st_as_sf(
    data.frame(id = 1:2, x = c(2, 50), y = c(2, 50)),
    coords = c("x", "y"), crs = 3400
  )
  poly <- st_sf(
    zone = "west",
    geometry = st_sfc(sq(0, 10, 0, 10), crs = 3400)
  )

  result <- extract_vector(pts, poly)
  expect_equal(nrow(result), 2L)
  expect_equal(result$zone, c("west", NA))
})

test_that("extract_vector cols keeps the requested columns", {
  skip_if_not_installed("sf")
  library(sf)

  pts <- st_as_sf(
    data.frame(id = 1, x = 2, y = 2),
    coords = c("x", "y"), crs = 3400
  )
  poly <- st_sf(
    zone  = "west",
    crew  = "A",
    notes = "drop me",
    geometry = st_sfc(sq(0, 10, 0, 10), crs = 3400)
  )

  result <- extract_vector(pts, poly, cols = "zone")
  expect_true("zone" %in% names(result))
  expect_false(any(c("crew", "notes") %in% names(result)))
  # The geometry column survives the subset even though `cols` does
  # not name it.
  expect_s3_class(result, "sf")

  # A name that is not in `polygons` is dropped silently rather
  # than erroring, so a typo costs a column without a warning.
  typo <- extract_vector(pts, poly, cols = c("zone", "zoen"))
  expect_equal(setdiff(names(typo), names(pts)), "zone")
})

test_that("extract_vector reprojects polygons to the point CRS", {
  skip_if_not_installed("sf")
  library(sf)

  pts <- st_as_sf(
    data.frame(id = 1, x = -114.07, y = 51.05),
    coords = c("x", "y"), crs = 4326
  )
  poly_ll <- st_sf(
    zone = "calgary_area",
    geometry = st_sfc(sq(-115, -113, 50, 52), crs = 4326)
  )
  poly_ab <- st_transform(poly_ll, 3400)

  result <- extract_vector(pts, poly_ab)

  # Same join as when both sides already agree, and the output keeps
  # the CRS the points arrived in rather than the polygons'.
  expect_equal(result$zone, "calgary_area")
  expect_equal(st_crs(result), st_crs(pts))
  expect_equal(
    st_coordinates(result),
    st_coordinates(pts)
  )
})

test_that("extract_vector repeats a point in overlapping polygons", {
  skip_if_not_installed("sf")
  library(sf)

  pts <- st_as_sf(
    data.frame(id = 1, x = 5, y = 5),
    coords = c("x", "y"), crs = 3400
  )
  # A smaller polygon nested inside a larger one: the point matches
  # both, so a left join returns it twice.
  poly <- st_sf(
    zone = c("outer", "inner"),
    geometry = st_sfc(sq(0, 10, 0, 10), sq(3, 8, 3, 8), crs = 3400)
  )

  result <- extract_vector(pts, poly)
  expect_equal(nrow(result), 2L)
  expect_setequal(result$zone, c("outer", "inner"))
})

test_that("extract_vector passes arguments through to st_join", {
  skip_if_not_installed("sf")
  library(sf)

  pts <- st_as_sf(
    data.frame(id = 1:2, x = c(2, 50), y = c(2, 50)),
    coords = c("x", "y"), crs = 3400
  )
  poly <- st_sf(
    zone = "west",
    geometry = st_sfc(sq(0, 10, 0, 10), crs = 3400)
  )

  # left = FALSE turns the default left join into an inner join, so
  # the unmatched point is dropped instead of carried as NA.
  result <- extract_vector(pts, poly, left = FALSE)
  expect_equal(nrow(result), 1L)
  expect_equal(result$id, 1L)
})

test_that("extract_vector validates its inputs", {
  skip_if_not_installed("sf")
  library(sf)

  pts <- st_as_sf(
    data.frame(id = 1, x = 2, y = 2),
    coords = c("x", "y"), crs = 3400
  )
  poly <- st_sf(
    zone = "west",
    geometry = st_sfc(sq(0, 10, 0, 10), crs = 3400)
  )

  expect_error(extract_vector(st_drop_geometry(pts), poly),
               "`points` must be an sf object")
  expect_error(extract_vector(pts, st_drop_geometry(poly)),
               "`polygons` must be an sf object")
})
