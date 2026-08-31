# Tests for list_variables() and the band-block parser, run against
# the synthetic share built by helper-catalogue.R.


# 1. Reading the band blocks ------------------------------------

test_that("repeated band blocks are all read, not just the first", {
  root <- local_fixture_share()

  v <- list_variables(product = "soilgrids", verbose = FALSE)

  # read_metadata() keeps only the first value for a repeated key,
  # which is why this needs its own parser.
  expect_equal(nrow(v), 3)
  expect_equal(
    v$band,
    c("bdod_0-5cm_mean", "phh2o_0-5cm_mean", "clay_0-5cm_mean")
  )
  expect_equal(v$measure[2], "Soil pH")
  expect_equal(v$units[2], "pH")
  expect_equal(v$scale[2], "continuous")
  expect_equal(v$valid_range[2], "30 to 90")
})

test_that("a wrapped description continues onto the band", {
  root <- local_fixture_share()

  v <- list_variables(product = "soilgrids", verbose = FALSE)
  expect_equal(
    v$description[2],
    "Mean prediction for the 0-5 cm interval, wrapped onto a second line."
  )
})

test_that("an unedited placeholder reads as NA, not as a range", {
  root <- local_fixture_share()

  v <- list_variables(product = "soilgrids", verbose = FALSE)
  expect_true(is.na(v$valid_range[1]))
  # The band either side is unaffected.
  expect_equal(v$valid_range[2], "30 to 90")
})

test_that("a field left of the block closes it", {
  root <- local_fixture_share()

  v <- list_variables(product = "soilgrids", verbose = FALSE)
  # `Class Definitions: None` is flush left and belongs to the
  # section, so it must not land on the last band.
  last <- v[v$band == "clay_0-5cm_mean", ]
  expect_equal(last$description,
               "Mean prediction for the 0-5 cm interval.")
  expect_false(any(grepl("Class Definitions", unlist(v))))
})

test_that("the `Band n: name` style is read", {
  root <- local_fixture_share()

  v <- list_variables(product = "fab_dem", verbose = FALSE)
  expect_equal(v$band, c("elevation", "mask"))
  expect_equal(v$units[1], "m")
  expect_equal(
    v$description[1],
    "Bare-earth elevation above the EGM2008 geoid."
  )
})

test_that("a `Layer n:` block takes its name from the Name field", {
  root <- local_fixture_share()

  v <- list_variables(product = "grid", verbose = FALSE)
  expect_equal(v$band, c("Grid_1KM_revAB2020", "linkid_1km_to_10km"))
  expect_equal(v$measure[1], "Multi Polygon")
  expect_match(v$description[1], "clipped to the boundary")
})


# 2. Scope and filtering ----------------------------------------

test_that("bands are listed once per product, not once per variant", {
  root <- local_fixture_share()

  cat_df <- build_catalogue(quiet = TRUE)
  # The product has two variants ...
  expect_equal(sum(cat_df$product_id == "geoscientific/soilgrids"), 2)

  v <- list_variables(product = "soilgrids", verbose = FALSE)
  # ... and three bands, not six.
  expect_equal(nrow(v), 3)
  expect_equal(unique(v$product), "geoscientific/soilgrids")
  expect_equal(unique(v$name), "soilgrids")
})

test_that("every product appears, undocumented ones with band NA", {
  root <- local_fixture_share()

  v <- list_variables(verbose = FALSE)
  cat_df <- build_catalogue(quiet = TRUE)

  expect_setequal(unique(v$product), unique(cat_df$product_id))
  # `unedited` is an unfilled template copy, so it documents no
  # bands and shows as a visible gap rather than dropping out.
  gap <- v[v$name == "unedited", ]
  expect_equal(nrow(gap), 1)
  expect_true(is.na(gap$band))

  # access_layers documents its layers, so it is not a gap.
  access <- v[v$name == "access_layers", ]
  expect_equal(access$band, c("Road", "Railway"))
})

test_that("theme narrows the listing", {
  root <- local_fixture_share()

  v <- list_variables(theme = "Elevation", verbose = FALSE)
  expect_equal(unique(v$theme), "elevation")
  expect_equal(v$band, c("elevation", "mask"))

  expect_equal(nrow(list_variables(theme = "nope", verbose = FALSE)), 0)
})

test_that("product matches a name, an id, or a fragment of one", {
  root <- local_fixture_share()

  by_name <- list_variables(product = "soilgrids", verbose = FALSE)
  by_id <- list_variables(product = "geoscientific/soilgrids/soil1km",
                          verbose = FALSE)
  by_frag <- list_variables(product = "soilgr", verbose = FALSE)

  expect_equal(by_name$band, by_id$band)
  expect_equal(by_name$band, by_frag$band)

  # Matching is case-insensitive.
  expect_equal(
    list_variables(product = "SOILGRIDS", verbose = FALSE)$band,
    by_name$band
  )
})

test_that("an exact product name is not widened by a substring match", {
  root <- local_fixture_share()

  # "grid" is the whole name of one product and a fragment of
  # "soilgrids"; the exact match must win.
  v <- list_variables(product = "grid", verbose = FALSE)
  expect_equal(unique(v$name), "grid")
})

test_that("filters validate their arguments", {
  root <- local_fixture_share()

  expect_error(list_variables(theme = 1), "character vector")
  expect_error(list_variables(product = 1), "character vector")
})


# 3. Printing ---------------------------------------------------

test_that("the printed view summarises and returns invisibly", {
  root <- local_fixture_share()

  expect_output(list_variables(product = "soilgrids"), "3 variables")
  expect_output(list_variables(product = "soilgrids"), "bdod_0-5cm_mean")
  expect_output(list_variables(), "no bands documented")
  expect_invisible(list_variables(product = "soilgrids"))

  # verbose = FALSE returns a plain data.frame, so the compact
  # view is reached through the verbose path.
  expect_output(list_variables(theme = "nope"), "No variables matched")
})


# 4. Parser edge cases ------------------------------------------

test_that("a readme with no band block yields no records", {
  root <- local_fixture_share()
  parse <- sciSpatialR:::.parse_bands

  expect_equal(
    parse(file.path(root, "imagery", "unedited", "readme.txt")),
    list()
  )
  # A missing or NA path is not an error.
  expect_equal(parse(NA_character_), list())
  expect_equal(parse(file.path(root, "no_such_readme.txt")), list())
})
