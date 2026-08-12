# Tests for the catalogue scan and its query functions, run
# against the synthetic share built by helper-catalogue.R.


# 1. spatial_root -----------------------------------------------

test_that("spatial_root honours the option and the env var", {
  root <- local_fixture_share()
  expect_equal(spatial_root(), root)

  withr::local_options(sciSpatialR.spatial_root = NULL)
  withr::local_envvar(SCISPATIALR_SPATIAL_ROOT = root)
  expect_equal(spatial_root(), root)
})

test_that("spatial_root errors when the share is unreachable", {
  withr::local_options(
    sciSpatialR.spatial_root = file.path(tempdir(), "no_such_share")
  )
  expect_error(spatial_root(), "not reachable")
  expect_no_error(spatial_root(check = FALSE))
})


# 2. build_catalogue --------------------------------------------

test_that("the scan catalogues dataset readmes, not theme readmes", {
  root <- local_fixture_share()
  cat_df <- build_catalogue(quiet = TRUE)

  expect_setequal(
    cat_df$id,
    c("elevation/fab_dem", "biota/vegetation/grassland",
      "transportation/access_layers", "imagery/unedited",
      "imagery/scanfi", "imagery/scanfi/2020")
  )
  # Theme readmes have no Title, so they are not layers.
  expect_false("elevation" %in% cat_df$id)
  expect_false("biota" %in% cat_df$id)
})

test_that("theme and sub_theme come from the folder path", {
  root <- local_fixture_share()
  cat_df <- build_catalogue(quiet = TRUE)

  fab <- cat_df[cat_df$id == "elevation/fab_dem", ]
  expect_equal(fab$theme, "elevation")
  expect_true(is.na(fab$sub_theme))

  grass <- cat_df[cat_df$id == "biota/vegetation/grassland", ]
  expect_equal(grass$theme, "biota")
  expect_equal(grass$sub_theme, "vegetation")
  expect_equal(grass$name, "grassland")
})

test_that("the file inventory classifies and sizes each layer", {
  root <- local_fixture_share()
  cat_df <- build_catalogue(quiet = TRUE)

  fab <- cat_df[cat_df$id == "elevation/fab_dem", ]
  expect_equal(fab$n_files, 1)          # the .aux.xml is not data
  expect_equal(fab$data_type, "raster")

  access <- cat_df[cat_df$id == "transportation/access_layers", ]
  expect_equal(access$data_type, "vector")

  grass <- cat_df[cat_df$id == "biota/vegetation/grassland", ]
  expect_equal(grass$n_files, 2)
  expect_true(grass$size_mb >= 0)
})

test_that("a nested layer's files are not credited to its parent", {
  root <- local_fixture_share()
  cat_df <- build_catalogue(quiet = TRUE)

  parent <- cat_df[cat_df$id == "imagery/scanfi", ]
  child  <- cat_df[cat_df$id == "imagery/scanfi/2020", ]
  expect_equal(parent$n_files, 1)
  expect_equal(child$n_files, 1)
})

test_that("data folders with no readme are recorded separately", {
  root <- local_fixture_share()
  cat_df <- build_catalogue(quiet = TRUE)
  undoc  <- attr(cat_df, "undocumented")

  expect_equal(undoc$id, "temp/orphan")
  expect_equal(undoc$theme, "temp")
})

test_that("the manifest is cached until refreshed", {
  root <- local_fixture_share()
  build_catalogue(quiet = TRUE)

  # A layer added after the scan is invisible to the cache.
  write_fixture(
    file.path(root, "elevation", "late", "readme.txt"),
    c("Title: Added After The Scan", "Spatial Resolution: 10 m")
  )
  expect_false("elevation/late" %in% build_catalogue(quiet = TRUE)$id)
  expect_true(
    "elevation/late" %in%
      build_catalogue(quiet = TRUE, refresh = TRUE)$id
  )
})

test_that("UNC paths keep their prefix when the parent is taken", {
  # dirname() would return "\\\\srv/share/a", which then fails to
  # match the forward-slash paths list.files() returns, leaving
  # every layer on the share with an empty file inventory.
  expect_equal(
    sciSpatialR:::.parent_dir("//srv/share/layer/readme.txt"),
    "//srv/share/layer"
  )
  expect_equal(
    sciSpatialR:::.parent_dir("\\\\srv\\share\\layer\\readme.txt"),
    "//srv/share/layer"
  )
})

test_that("build_catalogue errors on an unreachable root", {
  expect_error(
    build_catalogue(root = file.path(tempdir(), "nope"),
                    quiet = TRUE),
    "not reachable"
  )
})


# 3. list_layers and list_themes --------------------------------

test_that("list_layers filters by theme and prints a summary", {
  root <- local_fixture_share()

  all_layers <- list_layers(verbose = FALSE)
  expect_equal(nrow(all_layers), 6)

  elev <- list_layers(theme = "Elevation", verbose = FALSE)
  expect_equal(elev$id, "elevation/fab_dem")

  expect_output(list_layers(theme = "elevation"), "FABDEM")
  expect_output(list_layers(theme = "nothing_here"), "No layers")
  expect_error(list_layers(theme = 1), "character vector")
})

test_that("list_themes reports theme readmes and layer counts", {
  root <- local_fixture_share()
  themes <- list_themes()

  expect_true(all(
    c("elevation", "biota", "imagery", "temp") %in% themes$theme
  ))
  expect_equal(
    themes$description[themes$theme == "biota"],
    "Flora and/or fauna in natural environments."
  )
  expect_equal(themes$n_layers[themes$theme == "imagery"], 3)
  # A theme folder with no readme still appears, with no
  # description, so undocumented themes stay visible.
  expect_true(is.na(themes$description[themes$theme == "temp"]))
})


# 4. find_layer -------------------------------------------------

test_that("find_layer matches keywords across name and metadata", {
  root <- local_fixture_share()

  expect_equal(
    find_layer(keyword = "grassland", verbose = FALSE)$id,
    "biota/vegetation/grassland"
  )
  # Matched via the abstract, not the title.
  expect_equal(
    find_layer(keyword = "Copernicus", verbose = FALSE)$id,
    "elevation/fab_dem"
  )
  expect_equal(
    nrow(find_layer(keyword = c("grassland", "roads"),
                    verbose = FALSE)),
    2
  )
})

test_that("find_layer filters by year, resolution, and extent", {
  root <- local_fixture_share()

  expect_equal(
    find_layer(year = 2018, verbose = FALSE)$id, "elevation/fab_dem"
  )
  expect_setequal(
    find_layer(year = c(2020, 2024), verbose = FALSE)$id,
    c("biota/vegetation/grassland", "transportation/access_layers",
      "imagery/scanfi", "imagery/scanfi/2020")
  )
  expect_setequal(
    find_layer(resolution = c(0, 50), verbose = FALSE)$id,
    c("biota/vegetation/grassland", "imagery/scanfi")
  )
  # Alberta: overlaps the two continental layers, misses neither
  # bound of the prairie layer.
  ab <- find_layer(extent = c(-120, -110, 49, 60), verbose = FALSE)
  expect_true("elevation/fab_dem" %in% ab$id)
  expect_true("biota/vegetation/grassland" %in% ab$id)
  # A box off the coast of Africa overlaps nothing.
  expect_equal(
    nrow(find_layer(extent = c(0, 10, 0, 10), verbose = FALSE)), 0
  )
})

test_that("find_layer combines filters and excludes unknown values", {
  root <- local_fixture_share()

  expect_equal(
    nrow(find_layer(theme = "imagery", year = 2018,
                    verbose = FALSE)),
    0
  )
  # The unedited template has no year, so a year filter drops it.
  expect_false(
    "imagery/unedited" %in%
      find_layer(year = c(1900, 2100), verbose = FALSE)$id
  )
  expect_error(find_layer(extent = c(1, 2)), "numeric c\\(xmin")
  expect_error(find_layer(year = "2020"), "numeric of length")
})


# 5. get_layer and layer_files ----------------------------------

test_that("layer_files lists data files without shapefile sidecars", {
  root <- local_fixture_share()

  expect_equal(
    basename(layer_files("access_layers")), "roads.shp"
  )
  expect_equal(
    basename(layer_files("access_layers", all = TRUE)),
    c("_readme.txt", "roads.dbf", "roads.prj", "roads.shp",
      "roads.shx")
  )
  expect_equal(
    basename(layer_files("grassland", pattern = "alberta")),
    "alberta_grassland_2023.tif"
  )
})

test_that("get_layer returns a path and reports ambiguity", {
  root <- local_fixture_share()

  expect_equal(
    basename(get_layer("fab_dem", return_path = TRUE)),
    "fab_dem.tif"
  )
  expect_error(get_layer("grassland"), "holds 2 data files")
  expect_equal(
    basename(
      get_layer("grassland", file = "saskatchewan",
                return_path = TRUE)
    ),
    "saskatchewan_grassland_2023.tif"
  )
  expect_error(get_layer("unedited", file = "no_match"),
               "no readable spatial data file")
})

test_that("layers resolve by short name or by full id", {
  root <- local_fixture_share()

  expect_equal(
    get_layer("elevation/fab_dem", return_path = TRUE),
    get_layer("fab_dem", return_path = TRUE)
  )
  expect_error(get_layer("not_a_layer"), "No catalogued layer")
  expect_error(get_layer("fab"), "Did you mean")
  expect_error(get_layer(""), "single non-empty")
})

test_that("an ambiguous short name asks for the full id", {
  root <- local_fixture_share()
  write_fixture(
    file.path(root, "temp", "fab_dem", "readme.txt"),
    c("Title: A Second Copy Of FABDEM", "Spatial Resolution: 100 m")
  )
  clear_catalogue_cache()

  expect_error(get_layer("fab_dem"), "matches 2 layers")
  expect_no_error(get_layer("elevation/fab_dem", return_path = TRUE))
})
