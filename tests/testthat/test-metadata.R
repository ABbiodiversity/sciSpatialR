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
    meta_path(root, "biota", "grassland")
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
      meta_path(root, "biota", "grassland")
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

test_that("a field new to the template needs no code change to read", {
  root <- local_fixture_share()
  md   <- read_metadata(
    meta_path(root, "biota", "grassland")
  )

  # The reference-system block is written as a parent label with
  # indented sub-fields, so each one is namespaced under it.
  expect_equal(
    md$coordinate_reference_system_authority_code, "EPSG:3400"
  )
  expect_equal(
    md$coordinate_reference_system_name,
    "NAD83 / Alberta 10-TM (Forest)"
  )
  expect_equal(
    md$coordinate_reference_system_projection, "Transverse Mercator"
  )
  # Sub-field labels that repeat elsewhere stay distinct, because
  # each is prefixed by its own parent.
  expect_equal(md$point_of_contact_name, "Brendan Casey")
})

test_that("the CRS block populates the manifest columns", {
  root <- local_fixture_share()
  row  <- as_metadata_row(
    read_metadata(meta_path(root, "biota", "grassland"))
  )

  expect_equal(row$crs, "EPSG:3400")
  expect_equal(row$crs_name, "NAD83 / Alberta 10-TM (Forest)")
  expect_equal(row$datum, "North American Datum 1983")
  expect_equal(row$vertical_crs, "CGVD2013")

  # A readme with no reference-system block leaves them blank
  # rather than erroring.
  fab <- as_metadata_row(
    read_metadata(meta_path(root, "elevation", "fab_dem"))
  )
  expect_true(is.na(fab$crs))
  expect_true(is.na(fab$crs_name))
})

test_that("markdown emphasis and trailing spaces are stripped", {
  root <- local_fixture_share()
  md   <- read_metadata(
    meta_path(root, "biota", "grassland")
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
    meta_path(root, "biota", "grassland")
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
    read_metadata(meta_path(root, "biota", "grassland"))
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

  expect_true("misc/orphan" %in% chk$id)
  expect_equal(chk$missing[chk$id == "misc/orphan"], "readme")
  # The _temp scratch folder is skipped, so its readme-less data is
  # not held against the share.
  expect_false(any(startsWith(chk$id, "_temp/")))
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

test_that("check_metadata takes verbose without colliding on it", {
  root <- local_fixture_share()

  # verbose is a formal of check_metadata(), not something `...`
  # forwards: forwarding it used to collide with the internal
  # list_layers(verbose = FALSE) call and error out.
  plain <- expect_no_error(check_metadata(verbose = FALSE))
  expect_s3_class(plain, "data.frame")
  expect_false(inherits(plain, "sciSpatial_audit"))
  # The plain table keeps every column, including the one the
  # compact printer drops.
  expect_true("name" %in% names(plain))
  expect_equal(plain$id, check_metadata()$id)

  # It combines with the other arguments and with build_catalogue's.
  expect_no_error(check_metadata(detail = TRUE, verbose = FALSE))
  expect_no_error(check_metadata(verbose = FALSE, refresh = TRUE))
})

test_that("check_metadata prints a compact view", {
  root <- local_fixture_share()

  chk <- check_metadata()
  expect_s3_class(chk, "sciSpatial_audit")
  expect_s3_class(chk, "data.frame")

  out <- capture.output(print(chk))
  expect_match(out[1], "layers audited, [0-9]+ with no readme")
  # name is dropped from the printout as a prefix of id.
  expect_true(any(grepl("n_missing", out)))
  expect_false(any(grepl("\\bname\\b", out)))

  # The detail form reports fields rather than scores.
  det <- capture.output(print(check_metadata(detail = TRUE)))
  expect_match(det[1], "missing fields? across [0-9]+ layers?")
  expect_true(any(grepl("field", det)))
})

test_that("long ids are truncated from the left when printed", {
  # The tail identifies the layer, so the front is what gets cut.
  short <- strrep("a", 10)
  expect_identical(sciSpatialR:::.truncate_id(short, 55), short)

  long <- paste0(strrep("theme/", 12), "Year_2000")
  cut  <- sciSpatialR:::.truncate_id(long, 55)
  expect_equal(nchar(cut), 55)
  expect_true(startsWith(cut, "…"))
  expect_true(endsWith(cut, "Year_2000"))

  expect_true(is.na(sciSpatialR:::.truncate_id(NA_character_, 55)))
  expect_true(is.na(sciSpatialR:::.truncate(NA_character_, 45)))
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


# 6. File encoding ----------------------------------------------

# Readmes reach the share as UTF-8, as UTF-8 with a BOM, and as
# Windows-1252, depending on the editor that wrote them, and the
# punctuation that separates them - en dashes, curly quotes, the
# plus-minus sign - is exactly what the template asks authors to
# type.  All three must parse identically.

# Writes `txt` (UTF-8) to a temp file in the requested encoding.
encoded_readme <- function(to = "UTF-8", bom = FALSE, eol = "\n") {
  txt <- paste(
    "Title: FABDEM – Forest And Buildings Removed DEM",
    "Abstract: Alberta’s bare-earth elevation model.",
    "Positional Accuracy: ±500 m",
    sep = eol
  )
  bytes <- iconv(txt, from = "UTF-8", to = to, toRaw = TRUE)[[1]]
  if (bom) {
    bytes <- c(as.raw(c(0xef, 0xbb, 0xbf)), bytes)
  }
  path <- tempfile(fileext = ".txt")
  writeBin(bytes, path)
  path
}

test_that("readmes parse the same in UTF-8, with a BOM, and in cp1252", {
  utf8   <- read_metadata(encoded_readme())
  bom    <- read_metadata(encoded_readme(bom = TRUE, eol = "\r\n"))
  cp1252 <- read_metadata(encoded_readme(to = "windows-1252"))

  expect_equal(
    utf8$title, "FABDEM – Forest And Buildings Removed DEM"
  )
  # A BOM must not be swallowed by the first label.
  expect_equal(bom$title, utf8$title)
  expect_equal(cp1252$title, utf8$title)

  expect_equal(cp1252$abstract, utf8$abstract)
  expect_equal(cp1252$positional_accuracy, "±500 m")
})

test_that("parsing does not depend on the session's encoding option", {
  path <- encoded_readme()
  old  <- options(encoding = "UTF-8")
  on.exit(options(old), add = TRUE)

  md <- read_metadata(path)
  expect_equal(md$title, "FABDEM – Forest And Buildings Removed DEM")
  expect_true(all(validUTF8(unlist(md[!is.na(md)]))))
})
