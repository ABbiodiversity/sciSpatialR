make_ref <- function(res = 1000) {
  r <- terra::rast(
    xmin = 400000, xmax = 410000,
    ymin = 5800000, ymax = 5810000,
    res = res, crs = "EPSG:3400"
  )
  terra::values(r) <- 1
  r
}

# A layer at `res` covering the reference window but sitting off its
# lattice, so alignment has to actually do something.
make_off_lattice <- function(res, categorical = FALSE) {
  r <- terra::rast(
    xmin = 400000 + res / 3, xmax = 410000 + res / 3 + res,
    ymin = 5800000 - res / 3, ymax = 5810000 - res / 3 + res,
    res = res, crs = "EPSG:3400"
  )
  if (categorical) {
    terra::values(r) <- sample(1:4, terra::ncell(r), replace = TRUE)
    levels(r) <- data.frame(
      value = 1:4, class = c("a", "b", "c", "d")
    )
  } else {
    terra::values(r) <- stats::runif(terra::ncell(r), 0, 30)
  }
  r
}

test_that("resample_to_grid returns a raster aligned to ref", {
  ref <- make_ref()
  r   <- make_off_lattice(250)

  result <- resample_to_grid(r, ref, quiet = TRUE)

  expect_s4_class(result, "SpatRaster")
  expect_true(all(check_alignment(result, ref, verbose = FALSE)))
})

test_that("auto picks average when coarsening a continuous layer", {
  ref <- make_ref()
  r   <- make_off_lattice(250)

  expect_equal(resample_method_auto(r, ref)$method, "average")

  # The value is the mean of the fine cells, not a sample of them.
  auto <- resample_to_grid(r, ref, quiet = TRUE)
  avg  <- terra::resample(r, ref, method = "average")
  expect_equal(terra::values(auto), terra::values(avg))

  # and it differs materially from the bilinear it used to default to
  bil <- terra::resample(r, ref, method = "bilinear")
  expect_gt(
    mean(abs(terra::values(auto) - terra::values(bil))), 0
  )
})

test_that("auto picks mode when coarsening a categorical layer", {
  ref <- make_ref()
  r   <- make_off_lattice(250, categorical = TRUE)

  expect_equal(resample_method_auto(r, ref)$method, "mode")

  result <- resample_to_grid(r, ref, quiet = TRUE)
  vals   <- terra::values(result, mat = FALSE)
  vals   <- vals[!is.na(vals)]

  # Class codes stay whole; bilinear would produce fractions.
  expect_true(all(vals == round(vals)))
  expect_true(all(vals %in% 1:4))
})

test_that("auto picks near at equal resolution", {
  ref <- make_ref()
  r   <- make_off_lattice(1000)

  expect_equal(resample_method_auto(r, ref)$method, "near")

  # Nearest carries the input values across rather than blending
  # them, so the spread survives.
  result <- resample_to_grid(r, ref, quiet = TRUE)
  bil    <- terra::resample(r, ref, method = "bilinear")
  sd_in  <- stats::sd(terra::values(r, mat = FALSE), na.rm = TRUE)
  sd_out <- stats::sd(terra::values(result, mat = FALSE), na.rm = TRUE)
  sd_bil <- stats::sd(terra::values(bil, mat = FALSE), na.rm = TRUE)

  expect_equal(sd_out, sd_in, tolerance = 0.05)
  expect_lt(sd_bil, sd_out)
})

test_that("auto picks bilinear when refining a continuous layer", {
  ref <- make_ref()
  r   <- make_off_lattice(4000)

  expect_equal(resample_method_auto(r, ref)$method, "bilinear")
  expect_true(
    all(check_alignment(
      resample_to_grid(r, ref, quiet = TRUE), ref, verbose = FALSE
    ))
  )
})

test_that("auto picks near when refining a categorical layer", {
  ref <- make_ref()
  r   <- make_off_lattice(4000, categorical = TRUE)

  expect_equal(resample_method_auto(r, ref)$method, "near")

  vals <- terra::values(
    resample_to_grid(r, ref, quiet = TRUE), mat = FALSE
  )
  vals <- vals[!is.na(vals)]
  expect_true(all(vals %in% 1:4))
})

test_that("an explicit method overrides the automatic choice", {
  ref <- make_ref()
  r   <- make_off_lattice(250)

  auto <- resample_to_grid(r, ref, quiet = TRUE)
  near <- resample_to_grid(r, ref, method = "near", quiet = TRUE)

  expect_false(isTRUE(all.equal(
    terra::values(auto), terra::values(near)
  )))
  expect_equal(
    terra::values(near),
    terra::values(terra::resample(r, ref, method = "near"))
  )
})

test_that("a non-integer resolution ratio still aligns", {
  # 300 m does not divide 1 km; this is the case the old
  # aggregate_to_grid() rounded to a 900 m result.
  ref <- make_ref()
  r   <- make_off_lattice(300)

  result <- resample_to_grid(r, ref, quiet = TRUE)

  expect_equal(terra::res(result), c(1000, 1000))
  expect_true(all(check_alignment(result, ref, verbose = FALSE)))
})

test_that("the chosen method is reported unless quiet", {
  ref <- make_ref()
  r   <- make_off_lattice(250)

  expect_message(resample_to_grid(r, ref), "average")
  expect_message(resample_to_grid(r, ref), "input cells")
  expect_message(
    resample_to_grid(r, ref, method = "near"), "supplied"
  )
  expect_silent(resample_to_grid(r, ref, quiet = TRUE))
})

test_that("counts in the message are pluralised correctly", {
  expect_equal(fmt_count(1, "input cell"), "1 input cell")
  expect_equal(fmt_count(16, "input cell"), "16 input cells")
  expect_equal(fmt_count(1111.1, "input cell"), "1,111 input cells")
  # A ratio just over 1 keeps its decimal rather than collapsing to
  # a bare "1", which would hide the difference entirely.
  expect_equal(fmt_count(1.02, "input cell"), "1 input cell")
  expect_equal(fmt_count(1.2, "input cell"), "1.2 input cells")

  expect_equal(fmt_res(c(1000, 1000)), "1,000")
  expect_equal(fmt_res(c(30, 60)), "30 x 60")
})

test_that("a CRS mismatch is refused rather than resampled", {
  ref <- make_ref()
  geo <- terra::rast(
    xmin = -114, xmax = -110, ymin = 52, ymax = 55,
    nrows = 30, ncols = 40, crs = "EPSG:4326"
  )
  terra::values(geo) <- stats::runif(terra::ncell(geo), 0, 30)

  expect_error(resample_to_grid(geo, ref), "CRS mismatch")
  expect_error(resample_to_grid(geo, ref), "WGS 84")
  expect_error(resample_to_grid(geo, ref), "project")

  # It is refused before the method is chosen, so no message about
  # degrees being compared against metres escapes first.
  expect_error(resample_to_grid(geo, ref, quiet = FALSE), "CRS")

  # terra alone would have returned an empty raster, not an error.
  silent <- terra::resample(geo, ref, method = "bilinear")
  expect_true(all(is.na(terra::values(silent))))
})

test_that("an unset CRS is refused with its own message", {
  ref    <- make_ref()
  no_crs <- make_off_lattice(250)
  terra::crs(no_crs) <- ""

  expect_error(resample_to_grid(no_crs, ref), "no CRS set")
  expect_error(resample_to_grid(no_crs, ref), "terra::crs")

  no_ref <- ref
  terra::crs(no_ref) <- ""
  expect_error(
    resample_to_grid(make_off_lattice(250), no_ref),
    "`ref` has no CRS set"
  )

  # Both unset is not a mismatch: terra::same.crs() calls it a
  # match, and resampling within one unspecified coordinate space
  # is a valid geometric operation.
  expect_s4_class(
    resample_to_grid(no_crs, no_ref, quiet = TRUE), "SpatRaster"
  )
})

test_that("equivalent CRS spellings are accepted", {
  ref <- make_ref()
  r   <- make_off_lattice(250)

  # ref is built from "EPSG:3400"; give x the same CRS as full WKT
  terra::crs(r) <- terra::crs(ref)
  expect_s4_class(resample_to_grid(r, ref, quiet = TRUE), "SpatRaster")

  terra::crs(r) <- "EPSG:3400"
  expect_s4_class(resample_to_grid(r, ref, quiet = TRUE), "SpatRaster")
})

test_that("resample_to_grid validates its arguments", {
  ref <- make_ref()
  r   <- make_off_lattice(250)

  expect_error(resample_to_grid("not a raster", ref), "SpatRaster")
  expect_error(resample_to_grid(r, "not a raster"), "SpatRaster")
  expect_error(
    resample_to_grid(r, ref, method = c("near", "average")),
    "single character string"
  )
})
