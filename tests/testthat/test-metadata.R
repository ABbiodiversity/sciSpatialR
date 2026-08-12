# Tests for the readme metadata parser.  The fixture readmes in
# helper-catalogue.R reproduce the ways real readmes on the share
# depart from the template, so most of these tests are regression
# tests against a specific kind of drift.

meta_path <- function(root, ...) file.path(root, ..., "readme.txt")


# 1. Field parsing ----------------------------------------------

test_that("inline and block values both parse", {
  root <- local_fixture_share()

  block  <- read_metadata(meta_path(root, "elevation", "fab_dem"))
  inline <- read_metadata(
    meta_path(root, "biota", "vegetation", "grassland")
  )

  expect_equal(block$title, "FABDEM - Forest And Buildings Removed DEM")
  expect_equal(
    block$abstract,
    paste("A global bare-earth digital elevation model derived from",
          "the Copernicus GLO-30 DEM.")
  )
  expect_equal(inline$title, "Prairie Grassland Inventory")
  expect_equal(
    inline$abstract,
    paste("Grassland classification for the prairie provinces",
          "derived from Sentinel-2.")
  )
})

test_that("indented sub-fields are namespaced by their parent", {
  root <- local_fixture_share()
  md   <- read_metadata(meta_path(root, "elevation", "fab_dem"))

  expect_equal(md$extent_west_bounding_coordinate, "-179.9999")
  expect_equal(md$temporal_extent_start_date, "2010-01-01")
  expect_equal(md$point_of_contact_name, "Laurence Hawker")
  expect_equal(md$contact_email, "hawker@example.org")
})

test_that("wrapped URLs continue the value instead of opening a field", {
  root <- local_fixture_share()
  md   <- read_metadata(meta_path(root, "elevation", "fab_dem"))

  # Rejoined without the space the line wrap introduced.
  expect_equal(
    md$online_resource, "https://doi.org/10.1088/1748-9326/ac4d4f"
  )
  expect_null(md[["https"]])
})

test_that("the first value wins when a label repeats", {
  root <- local_fixture_share()
  md   <- read_metadata(
    file.path(root, "transportation", "access_layers", "_readme.txt")
  )

  expect_equal(md$description, "Line features representing roads.")
  expect_equal(md$layer_1, "Road")
  expect_equal(md$layer_2, "Railway")
})

test_that("a short field takes a wrap but not an indented blurb", {
  root <- local_fixture_share()

  # Flush-left wrap.
  expect_equal(
    read_metadata(
      meta_path(root, "biota", "vegetation", "grassland")
    )$title,
    "Prairie Grassland Inventory"
  )
  # Hanging indent aligned to the value column.
  expect_equal(
    read_metadata(
      file.path(root, "imagery", "scanfi", "_readme.txt")
    )$title,
    "SCANFI - Spatialized Canadian National Forest Inventory"
  )
  # An indented block of its own is a separate blurb, not a wrap.
  expect_equal(
    read_metadata(
      file.path(root, "transportation", "access_layers",
                "_readme.txt")
    )$title,
    "Government of Alberta Access Layers"
  )
})

test_that("markdown emphasis and trailing spaces are stripped", {
  root <- local_fixture_share()
  md   <- read_metadata(
    meta_path(root, "biota", "vegetation", "grassland")
  )

  expect_equal(md$credits, "Mousavi et al.")
  expect_equal(md$resolution, "30 m")
})

test_that("section banners and headings are not read as data", {
  root <- local_fixture_share()
  md   <- read_metadata(meta_path(root, "elevation", "fab_dem"))

  expect_true("GEOGRAPHIC INFORMATION" %in% attr(md, "sections"))
  expect_false(
    grepl("TEMPORAL", md$positional_accuracy, fixed = TRUE)
  )
  expect_equal(md$lineage, "Derived from the Copernicus GLO-30 DEM.")
})


# 2. Missing values ---------------------------------------------

test_that("placeholders and non-values become NA", {
  root <- local_fixture_share()

  unedited <- read_metadata(meta_path(root, "imagery", "unedited"))
  expect_true(is.na(unedited$title))
  expect_true(is.na(unedited$abstract))
  expect_true(is.na(unedited$resolution))

  grass <- read_metadata(
    meta_path(root, "biota", "vegetation", "grassland")
  )
  expect_true(is.na(grass$positional_accuracy))

  access <- read_metadata(
    file.path(root, "transportation", "access_layers", "_readme.txt")
  )
  expect_true(is.na(access$resolution))
})

test_that("template fields absent from a readme are returned as NA", {
  root <- local_fixture_share()
  md   <- read_metadata(meta_path(root, "imagery", "scanfi", "2020"))

  expect_true(all(names(sciSpatialR:::.meta_field_map) %in% names(md)))
  expect_true(is.na(md$use_constraints))
  expect_true(is.na(md$doi))
})

test_that("read_metadata validates its input", {
  expect_error(read_metadata(1), "single non-empty character")
  expect_error(read_metadata(character(0)), "single non-empty")
  expect_error(
    read_metadata(file.path(tempdir(), "no_such_readme.txt")),
    "Metadata file not found"
  )
})


# 3. Value coercion ---------------------------------------------

test_that("resolution is converted to metres", {
  res <- sciSpatialR:::.res_metres

  expect_equal(res("30 m"), 30)
  expect_equal(res("30 meters"), 30)
  expect_equal(res("92.77 m"), 92.77)
  expect_equal(res("1 km"), 1000)
  expect_equal(res("1 kilometre"), 1000)
  # The metric equivalent, not the arc-second figure in front of it.
  expect_equal(res("1 arc-second (~30 m at the equator)"), 30)
  expect_equal(res("3.23 arc-seconds (~100 m at the equator)"), 100)
  expect_true(is.na(res(NA_character_)))
  expect_true(is.na(res("varies")))
})

test_that("only the leading number of a coordinate is trusted", {
  # The template's trailing note is appended to the last
  # coordinate, so parsing must not be confused by "WGS 84".
  expect_equal(
    sciSpatialR:::.first_number(
      "24.00029 Geographic extent in decimal degrees (WGS 84)."
    ),
    24.00029
  )
  expect_equal(sciSpatialR:::.first_number("-179.9999"), -179.9999)
  expect_true(is.na(sciSpatialR:::.first_number("Canada")))
})

test_that("as_metadata_row prefers the end of the temporal extent", {
  root <- local_fixture_share()

  fab <- as_metadata_row(
    read_metadata(meta_path(root, "elevation", "fab_dem"))
  )
  expect_equal(fab$year, 2018)
  expect_equal(fab$resolution_m, 100)
  expect_equal(fab$xmin, -179.9999)
  expect_equal(fab$ymin, 24.00029)

  # "Ongoing" is not a year, so the start date is used instead.
  grass <- as_metadata_row(
    read_metadata(meta_path(root, "biota", "vegetation", "grassland"))
  )
  expect_equal(grass$year, 2023)

  # No temporal extent at all falls back to the publication date.
  scanfi <- as_metadata_row(
    read_metadata(meta_path(root, "imagery", "scanfi", "2020"))
  )
  expect_equal(scanfi$year, 2024)
})

test_that("as_metadata_row rejects objects it did not parse", {
  expect_error(as_metadata_row(list(title = "x")),
               "sciSpatial_metadata")
})


# 4. check_metadata ---------------------------------------------

test_that("check_metadata scores completeness per layer", {
  root <- local_fixture_share()
  chk  <- check_metadata()

  expect_true(all(
    c("id", "n_missing", "complete", "missing") %in% names(chk)
  ))

  fab <- chk[chk$id == "elevation/fab_dem", ]
  expect_equal(fab$n_missing, 0)
  expect_equal(fab$complete, 1)

  unedited <- chk[chk$id == "imagery/unedited", ]
  expect_true(unedited$n_missing > 10)
  expect_true(grepl("title", unedited$missing, fixed = TRUE))
})

test_that("check_metadata reports folders with no readme", {
  root <- local_fixture_share()
  chk  <- check_metadata()

  expect_true("temp/orphan" %in% chk$id)
  expect_equal(chk$missing[chk$id == "temp/orphan"], "readme")
})

test_that("check_metadata(detail = TRUE) returns one row per field", {
  root <- local_fixture_share()
  chk  <- check_metadata(detail = TRUE)

  expect_equal(names(chk), c("id", "name", "theme", "field"))
  expect_true(all(
    c("title", "abstract") %in%
      chk$field[chk$id == "imagery/unedited"]
  ))
  expect_false("elevation/fab_dem" %in% chk$id)
})


# 5. layer_meta -------------------------------------------------

test_that("layer_meta reads a layer's readme by name", {
  root <- local_fixture_share()

  md <- layer_meta("fab_dem", print = FALSE)
  expect_s3_class(md, "sciSpatial_metadata")
  expect_equal(md$use_constraints, "CC BY-NC-SA 4.0.")

  expect_output(layer_meta("fab_dem"), "FABDEM")
  expect_error(layer_meta(123), "single non-empty")
})
