# Tests for download_layer(), run against the synthetic share built
# by helper-catalogue.R and copying into a temporary destination.


#' Copied data files under a destination root, relative and sorted
#'
#' The download log is written beside the data and is not one of the
#' copied files, so it is left out here and tested on its own.
have_files <- function(dest) {
  f <- list.files(dest, recursive = TRUE, all.files = TRUE,
                  include.dirs = FALSE)
  sort(f[basename(f) != "_download_log.txt"])
}

#' Contents of the log written into a layer's destination folder
log_lines <- function(...) {
  readLines(file.path(..., "_download_log.txt"))
}


# 1. An unsplit product copies its whole folder -----------------

test_that("an unsplit product copies every file in its folder", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  plan <- download_layer("fab_dem", dest, quiet = TRUE)

  expect_setequal(
    have_files(dest),
    file.path("fab_dem",
              c("readme.txt", "fab_dem.tif", "fab_dem.tif.aux.xml"))
  )
  expect_equal(nrow(plan), 3)
  expect_true(all(plan$status == "copied"))
  # No product pass: the record is not split, so there is no second
  # readme to fetch.
  expect_true(all(plan$part == "layer"))
})

test_that("the returned manifest has the documented columns", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  plan <- download_layer("fab_dem", dest, quiet = TRUE)

  expect_equal(
    names(plan),
    c("source", "destination", "bytes", "part", "status",
      "verified", "md5")
  )
  expect_type(plan$bytes, "double")
  expect_true(all(plan$bytes > 0))
  expect_equal(attr(plan, "layer"), "elevation/fab_dem")
  expect_false(attr(plan, "dry_run"))
})


test_that("keep_theme reproduces the share's full path", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  download_layer("fab_dem", dest, keep_theme = TRUE, quiet = TRUE)

  expect_setequal(
    have_files(dest),
    file.path("elevation", "fab_dem",
              c("readme.txt", "fab_dem.tif", "fab_dem.tif.aux.xml"))
  )
})

test_that("keep_theme keeps a variant inside its product", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  download_layer("geoscientific/soilgrids/soil1km", dest,
                 keep_theme = TRUE, quiet = TRUE)

  expect_setequal(
    have_files(dest),
    c(
      file.path("geoscientific", "soilgrids", "soil1km",
                c("readme.txt", "soilgrids_soil1km.tif")),
      file.path("geoscientific", "soilgrids", "readme.txt")
    )
  )
})


# 2. A variant brings its parent product's metadata -------------

test_that("a variant copies its product's readme and docs", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  # A product-level document at depth, to prove the sub-path below
  # the product folder is preserved rather than flattened.
  write_fixture(
    file.path(root, "geoscientific", "soilgrids", "docs",
              "licence.txt"),
    "Open Government Licence - Alberta"
  )
  # A file in the undocumented sibling variant, which must not be
  # swept up with the product's own files.
  write_fixture(
    file.path(root, "geoscientific", "soilgrids", "soil90m",
              "notes.txt"),
    "Provider resolution, not yet documented."
  )
  clear_catalogue_cache()

  plan <- download_layer("geoscientific/soilgrids/soil1km", dest,
                         quiet = TRUE)

  expect_setequal(
    have_files(dest),
    c(
      file.path("soilgrids", "soil1km",
                c("readme.txt", "soilgrids_soil1km.tif")),
      file.path("soilgrids", "readme.txt"),
      file.path("soilgrids", "docs", "licence.txt")
    )
  )
  # The product readme lands one level up from the variant, exactly
  # as it sits on the share.
  expect_equal(sum(plan$part == "product"), 2)
  expect_equal(sum(plan$part == "layer"), 2)
})

test_that("a variant does not drag its siblings along", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()
  write_fixture(
    file.path(root, "geoscientific", "soilgrids", "soil90m",
              "notes.txt"), "x"
  )
  clear_catalogue_cache()

  download_layer("geoscientific/soilgrids/soil1km", dest,
                 quiet = TRUE)

  files <- have_files(dest)
  # A documented sibling variant, subtracted via the manifest.
  expect_false(any(grepl("soil250m", files)))
  # An undocumented one, subtracted via the `undocumented`
  # attribute; the text file is the real test, since the raster
  # would be dropped by the data filter anyway.
  expect_false(any(grepl("soil90m", files)))
})

test_that("an unsplit product runs no product pass", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  plan <- download_layer("grassland", dest, quiet = TRUE)
  expect_equal(sum(plan$part == "product"), 0)
})


# 3. Geodatabases are copied as one bundle ----------------------

test_that("a geodatabase is copied whole and sized by contents", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  plan <- download_layer("grid", dest, quiet = TRUE)
  gdb  <- file.path(dest, "grid", "GRID1SQKM.gdb")

  expect_true(dir.exists(gdb))
  expect_setequal(
    list.files(gdb),
    c("a00000001.gdbtable", "a00000001.gdbtablx",
      "a00000004.spx", "gdb", "timestamps")
  )

  # One row for the bundle, not one per internal table.
  bundle <- plan[grepl("GRID1SQKM\\.gdb$", plan$source), ]
  expect_equal(nrow(bundle), 1)
  expect_gt(bundle$bytes, 0)
})

test_that("a copied geodatabase is skipped on the next run", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  download_layer("grid", dest, quiet = TRUE)
  again <- download_layer("grid", dest, quiet = TRUE)

  # Fails if copy.date = TRUE did not reach the bundle's internals.
  bundle <- again[grepl("GRID1SQKM\\.gdb$", again$source), ]
  expect_equal(bundle$status, "skipped")
})

test_that("a stale geodatabase is replaced, not merged", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  download_layer("grid", dest, quiet = TRUE)
  gdb <- file.path(dest, "grid", "GRID1SQKM.gdb")
  writeLines("x", file.path(gdb, "a00000099.gdbtable"))

  download_layer("grid", dest, overwrite = TRUE, quiet = TRUE)

  # A merge would leave the stale table behind, which is a corrupt
  # geodatabase rather than an out-of-date one.
  expect_false(file.exists(file.path(gdb, "a00000099.gdbtable")))
  expect_true(file.exists(file.path(gdb, "a00000001.gdbtable")))
})


# 4. Shapefile sidecars come down -------------------------------

test_that("a shapefile arrives with its sidecars", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  download_layer("access_layers", dest, quiet = TRUE)

  expect_setequal(
    have_files(dest),
    file.path("access_layers",
              c("_readme.txt", "roads.shp", "roads.dbf",
                "roads.shx", "roads.prj"))
  )
  # layer_files() hides the sidecars so a shapefile is listed once;
  # a download must not, or the copy will not open.
  expect_equal(basename(layer_files("access_layers")), "roads.shp")
})


# 5. Nested layers are not dragged along ------------------------

test_that("a layer nested inside another is left behind", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  download_layer("imagery/scanfi", dest, quiet = TRUE)

  expect_setequal(
    have_files(dest),
    file.path("scanfi", c("_readme.txt", "scanfi_index.tif"))
  )
  expect_false(dir.exists(file.path(dest, "scanfi", "2020")))
})


# 6. Unchanged files are skipped, changed ones are not ----------

test_that("a second run skips everything it already copied", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  first <- download_layer("fab_dem", dest, quiet = TRUE)
  expect_true(all(first$status == "copied"))

  again <- download_layer("fab_dem", dest, quiet = TRUE)
  expect_true(all(again$status == "skipped"))
})

test_that("a changed source is copied again", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()
  download_layer("fab_dem", dest, quiet = TRUE)

  tif <- file.path(root, "elevation", "fab_dem", "fab_dem.tif")
  writeLines(c("x", "much longer than before"), tif)
  Sys.setFileTime(tif, Sys.time() + 60)

  plan    <- download_layer("fab_dem", dest, quiet = TRUE)
  changed <- plan[basename(plan$source) == "fab_dem.tif", ]
  expect_equal(changed$status, "copied")
  expect_equal(sum(plan$status == "skipped"), 2)
})

test_that("a stale destination is replaced even without overwrite", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()
  download_layer("fab_dem", dest, quiet = TRUE)

  # `overwrite` means "skip identical", not "never replace".  If the
  # internal file.copy() were given overwrite = FALSE this row would
  # come back "failed" and blame the user's permissions.
  copy <- file.path(dest, "fab_dem", "fab_dem.tif")
  writeLines("something else entirely", copy)

  plan <- download_layer("fab_dem", dest, quiet = TRUE)
  row  <- plan[basename(plan$destination) == "fab_dem.tif", ]
  expect_equal(row$status, "copied")
  expect_equal(
    readLines(copy),
    readLines(file.path(root, "elevation", "fab_dem", "fab_dem.tif"))
  )
})

test_that("overwrite = TRUE copies everything again", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()
  download_layer("fab_dem", dest, quiet = TRUE)

  plan <- download_layer("fab_dem", dest, overwrite = TRUE,
                         quiet = TRUE)
  expect_true(all(plan$status == "copied"))
})


# 7. A dry run writes nothing -----------------------------------

test_that("a dry run reports the copy without making it", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  plan <- download_layer("fab_dem", dest, dry_run = TRUE,
                         quiet = TRUE)

  expect_false(dir.exists(file.path(dest, "fab_dem")))
  expect_equal(have_files(dest), character(0))
  expect_true(all(plan$status == "would copy"))
  expect_true(all(plan$bytes > 0))
  expect_true(attr(plan, "dry_run"))
})

test_that("a dry run after a download reports skips", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()
  download_layer("fab_dem", dest, quiet = TRUE)

  plan <- download_layer("fab_dem", dest, dry_run = TRUE,
                         quiet = TRUE)
  expect_true(all(plan$status == "would skip"))
})

test_that("a dry run reports the total it would copy", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  expect_message(
    download_layer("fab_dem", dest, dry_run = TRUE),
    "Dry run"
  )
})


# 8. Failures are reported, not thrown --------------------------

test_that("a file that cannot be copied warns and is recorded", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  # A directory where the file must go.  file.copy() would treat it
  # as a folder to copy into and report success, so the copy is
  # refused rather than written one level too deep.
  blocked <- file.path(dest, "fab_dem", "fab_dem.tif")
  dir.create(blocked, recursive = TRUE)

  expect_warning(
    plan <- download_layer("fab_dem", dest, quiet = TRUE),
    "could not be copied"
  )
  row <- plan[basename(plan$destination) == "fab_dem.tif", ]
  expect_equal(row$status, "failed")
  # The rest of the layer still lands, and the manifest says so.
  expect_equal(sum(plan$status == "copied"), 2)
  # The file was not written inside the directory in the way.
  expect_equal(list.files(blocked), character(0))
})


# 9. The copy log ----------------------------------------------

test_that("a copy leaves a log beside the data", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  download_layer("fab_dem", dest, quiet = TRUE)
  txt <- log_lines(dest, "fab_dem")

  expect_true(any(grepl("sciSpatialR download log", txt)))
  expect_true(any(grepl("^Layer:\\s+elevation/fab_dem", txt)))
  expect_true(any(grepl("^Downloaded:", txt)))
  expect_true(any(grepl("^Elapsed:", txt)))
  # Every copied file is named, and the data files carry a checksum.
  expect_true(any(grepl("fab_dem\\.tif", txt)))
  expect_true(any(grepl("[0-9a-f]{32}", txt)))
  expect_true(any(grepl("match their source", txt)))
})

test_that("the log records the md5 of each copied file", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  plan <- download_layer("fab_dem", dest, quiet = TRUE)

  expect_true(all(plan$verified == "ok"))
  expect_true(all(grepl("^[0-9a-f]{32}$", plan$md5)))
  # The checksum in the manifest is the source's, and the copy
  # matches it.
  tif <- plan$destination[basename(plan$destination) ==
                            "fab_dem.tif"]
  expect_equal(
    unname(tools::md5sum(tif)),
    plan$md5[basename(plan$destination) == "fab_dem.tif"]
  )
  expect_true(any(grepl(unname(tools::md5sum(tif)),
                        log_lines(dest, "fab_dem"), fixed = TRUE)))
})

test_that("a geodatabase is verified as one bundle", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  plan <- download_layer("grid", dest, quiet = TRUE)
  gdb  <- plan[grepl("GRID1SQKM\\.gdb$", plan$source), ]

  expect_equal(gdb$verified, "ok")
  expect_match(gdb$md5, "^[0-9a-f]{32}$")
})

test_that("verify = FALSE skips the checksums but still logs", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  plan <- download_layer("fab_dem", dest, verify = FALSE,
                         quiet = TRUE)

  expect_true(all(plan$verified == "not checked"))
  expect_true(all(is.na(plan$md5)))
  expect_true(any(grepl("not checked",
                        log_lines(dest, "fab_dem"))))
})

test_that("a second copy appends to the log rather than clobbering", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  download_layer("fab_dem", dest, quiet = TRUE)
  one <- sum(grepl("sciSpatialR download log",
                   log_lines(dest, "fab_dem")))

  download_layer("fab_dem", dest, overwrite = TRUE, quiet = TRUE)
  two <- sum(grepl("sciSpatialR download log",
                   log_lines(dest, "fab_dem")))

  expect_equal(one, 1)
  expect_equal(two, 2)
})

test_that("a run that copies nothing leaves the log untouched", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  download_layer("fab_dem", dest, quiet = TRUE)
  before <- log_lines(dest, "fab_dem")

  download_layer("fab_dem", dest, quiet = TRUE)
  expect_equal(log_lines(dest, "fab_dem"), before)
})

test_that("a dry run writes no log", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  plan <- download_layer("fab_dem", dest, dry_run = TRUE,
                         quiet = TRUE)

  expect_false(
    file.exists(file.path(dest, "fab_dem", "_download_log.txt"))
  )
  # The columns are still there, so the shape does not change.
  expect_true(all(c("verified", "md5") %in% names(plan)))
})

test_that("a corrupted copy is caught and reported as failed", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  # Stand in for a file that copied to the right length with the
  # wrong contents, which only a checksum catches.  .verify_copy()
  # takes the source first and the copy second, so alternating the
  # answer makes every pair disagree -- and unlike comparing paths,
  # it does not care how Windows spells the temp directory.
  nth <- 0
  local_mocked_bindings(
    .md5_of = function(path, bundle) {
      nth <<- nth + 1
      if (nth %% 2 == 1) strrep("a", 32) else strrep("b", 32)
    }
  )

  expect_warning(
    plan <- download_layer("fab_dem", dest, quiet = TRUE),
    "could not be copied"
  )
  expect_true(all(plan$status == "failed"))
  expect_true(all(plan$verified == "checksum mismatch"))
  expect_true(any(grepl("did NOT copy cleanly",
                        log_lines(dest, "fab_dem"))))
})


# 10. Errors ----------------------------------------------------

test_that("download_layer errors on a bad layer or destination", {
  root <- local_fixture_share()
  dest <- withr::local_tempdir()

  expect_error(download_layer("not_a_layer", dest),
               "No catalogued layer")
  expect_error(download_layer("fab_dem", 1),
               "single non-empty character")
  expect_error(download_layer("fab_dem", c("a", "b")),
               "single non-empty character")

  file_dest <- file.path(dest, "a_file.txt")
  writeLines("x", file_dest)
  expect_error(download_layer("fab_dem", file_dest),
               "not a directory")
})

test_that("download_layer refuses to copy the share onto itself", {
  root <- local_fixture_share()

  expect_error(download_layer("fab_dem", root),
               "inside the data share")
  expect_error(
    download_layer("fab_dem", file.path(root, "elevation")),
    "inside the data share"
  )
})

# End of script ----
