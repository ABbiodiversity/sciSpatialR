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
    c("elevation/fab_dem", "biota/grassland",
      "transportation/access_layers", "imagery/unedited",
      "imagery/scanfi", "imagery/scanfi/2020",
      "geoscientific/soilgrids/soil1km",
      "geoscientific/soilgrids/soil250m",
      "location/grid")
  )
  # Theme readmes have no Title, so they are not layers.
  expect_false("elevation" %in% cat_df$id)
  expect_false("biota" %in% cat_df$id)
})

test_that("theme comes from the folder path", {
  root <- local_fixture_share()
  cat_df <- build_catalogue(quiet = TRUE)

  fab <- cat_df[cat_df$id == "elevation/fab_dem", ]
  expect_equal(fab$theme, "elevation")
  expect_equal(fab$product_id, "elevation/fab_dem")
  expect_true(is.na(fab$variant))

  grass <- cat_df[cat_df$id == "biota/grassland", ]
  expect_equal(grass$theme, "biota")
  expect_equal(grass$name, "grassland")
})


# 2a. Split product/variant records ------------------------------

test_that("a product with variants yields one row per variant, not its own", {
  root <- local_fixture_share()
  cat_df <- build_catalogue(quiet = TRUE)

  # The product folder holds no data, so it must not be a row.
  expect_false("geoscientific/soilgrids" %in% cat_df$id)

  variants <- cat_df[cat_df$product_id == "geoscientific/soilgrids", ]
  expect_setequal(variants$variant, c("soil1km", "soil250m"))
  # `name` stays the product, so a short name still finds the layer.
  expect_equal(unique(variants$name), "soilgrids")
  expect_equal(unique(variants$theme), "geoscientific")
})

test_that("a variant row merges its product's identity with its own geometry", {
  root <- local_fixture_share()
  cat_df <- build_catalogue(quiet = TRUE)

  km <- cat_df[cat_df$id == "geoscientific/soilgrids/soil1km", ]
  # From the product record ...
  expect_equal(km$title, "SoilGrids 2.0")
  expect_equal(km$use_constraints, "CC BY 4.0")
  expect_equal(km$year, 2020)
  # ... and from the variant record.
  expect_equal(km$resolution_m, 1000)
  expect_equal(km$crs, "EPSG:3400")
  expect_equal(km$xmin, -120.9066)
  # Unstated by the variant, so it falls through to the product.
  expect_equal(km$format, "GeoTIFF")

  # The variant wins where both fill the field in.
  m250 <- cat_df[cat_df$id == "geoscientific/soilgrids/soil250m", ]
  expect_equal(m250$resolution_m, 250)
  expect_equal(m250$format, "COG")
  expect_equal(m250$title, "SoilGrids 2.0")
})

test_that("split records carry both readme paths and inventory the variant", {
  root <- local_fixture_share()
  cat_df <- build_catalogue(quiet = TRUE)

  km <- cat_df[cat_df$id == "geoscientific/soilgrids/soil1km", ]
  expect_match(km$readme, "soil1km/readme\\.txt$")
  expect_match(km$product_readme, "soilgrids/readme\\.txt$")
  expect_equal(km$n_files, 1)

  # An unsplit product points both columns at the one readme.
  fab <- cat_df[cat_df$id == "elevation/fab_dem", ]
  expect_equal(fab$readme, fab$product_readme)
})

test_that("a variant folder with data but no readme is undocumented", {
  root <- local_fixture_share()
  undoc <- attr(build_catalogue(quiet = TRUE), "undocumented")

  expect_true("geoscientific/soilgrids/soil90m" %in% undoc$id)
})


# 2b. Directory-based formats -----------------------------------

test_that("a file geodatabase counts as one vector dataset", {
  root <- local_fixture_share()
  cat_df <- build_catalogue(quiet = TRUE)

  grid <- cat_df[cat_df$id == "location/grid", ]
  # Five internal files, one dataset.
  expect_equal(grid$n_files, 1)
  expect_equal(grid$data_type, "vector")
  # Size still reflects what the bundle occupies on disk.
  expect_true(grid$size_mb >= 0)

  expect_equal(
    basename(layer_files("grid")), "GRID1SQKM.gdb"
  )
  expect_match(
    get_layer("grid", return_path = TRUE), "GRID1SQKM\\.gdb$"
  )
})

test_that("an undocumented geodatabase is still reported", {
  root <- local_fixture_share()
  undoc <- attr(build_catalogue(quiet = TRUE), "undocumented")

  expect_true("location/undocumented_grid" %in% undoc$id)
})

test_that("collapsing stops at the .gdb segment, not inside it", {
  collapse <- sciSpatialR:::.collapse_bundles

  # `.gdbtable` starts with "gdb"; a greedy pattern would return
  # the internal file rather than the bundle.
  expect_equal(
    collapse("x/GRID.gdb/a00000001.gdbtable"), "x/GRID.gdb"
  )
  # Many internals collapse to one path.
  expect_equal(
    collapse(c("x/G.gdb/a.gdbtable", "x/G.gdb/b.spx", "x/G.gdb/gdb")),
    "x/G.gdb"
  )
  # Ordinary files are untouched, and a bundle named directly stays.
  expect_equal(collapse("x/dem.tif"), "x/dem.tif")
  expect_equal(collapse("x/G.gdb"), "x/G.gdb")
  expect_equal(collapse(character(0)), character(0))
})

test_that("the file inventory classifies and sizes each layer", {
  root <- local_fixture_share()
  cat_df <- build_catalogue(quiet = TRUE)

  fab <- cat_df[cat_df$id == "elevation/fab_dem", ]
  expect_equal(fab$n_files, 1)          # the .aux.xml is not data
  expect_equal(fab$data_type, "raster")

  access <- cat_df[cat_df$id == "transportation/access_layers", ]
  expect_equal(access$data_type, "vector")

  grass <- cat_df[cat_df$id == "biota/grassland", ]
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

  expect_setequal(
    undoc$id,
    c("misc/orphan", "geoscientific/soilgrids/soil90m",
      "location/undocumented_grid")
  )
  expect_setequal(
    undoc$theme, c("misc", "geoscientific", "location")
  )
})

test_that("the _temp scratch folder is skipped by every scan", {
  root   <- local_fixture_share()
  cat_df <- build_catalogue(quiet = TRUE)

  # Documented or not, nothing under _temp/ reaches the manifest,
  # the undocumented report, or the theme listing.
  expect_false(any(cat_df$theme == "_temp"))
  expect_false("_temp/scratch_dem" %in% cat_df$id)
  expect_false(
    any(startsWith(attr(cat_df, "undocumented")$id, "_temp/"))
  )
  expect_false("_temp" %in% list_themes()$theme)
  expect_error(get_layer("scratch_dem"), "No catalogued layer")
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
  expect_equal(nrow(all_layers), 9)

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
    c("elevation", "biota", "imagery", "misc") %in% themes$theme
  ))
  expect_equal(
    themes$description[themes$theme == "biota"],
    "Flora and/or fauna in natural environments."
  )
  expect_equal(themes$n_layers[themes$theme == "imagery"], 3)
  # A theme folder with no readme still appears, with no
  # description, so undocumented themes stay visible.
  expect_true(is.na(themes$description[themes$theme == "misc"]))
})

test_that("list_themes prints a compact view", {
  root <- local_fixture_share()
  themes <- list_themes()

  expect_s3_class(themes, "sciSpatial_themes")
  expect_s3_class(themes, "data.frame")

  # examples is too long to tabulate, so it is dropped from the
  # printout but kept on the returned object.
  expect_true("examples" %in% names(themes))
  out <- capture.output(print(themes))
  expect_false(any(grepl("examples", out)))
  expect_true(any(grepl("n_layers", out)))
  # A theme with no readme prints as <NA> rather than erroring on
  # nchar(NA_character_).
  expect_true(any(grepl("<NA>", out, fixed = TRUE)))
})

test_that("summary lines singularise counts", {
  root <- local_fixture_share()

  expect_output(list_layers(theme = "elevation"),
                "1 layer in 1 theme\\b")
  expect_output(list_layers(), "layers in [0-9]+ themes")
})


# 4. find_layer -------------------------------------------------

test_that("find_layer matches keywords across name and metadata", {
  root <- local_fixture_share()

  expect_equal(
    find_layer(keyword = "grassland", verbose = FALSE)$id,
    "biota/grassland"
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
    c("biota/grassland", "transportation/access_layers",
      "imagery/scanfi", "imagery/scanfi/2020",
      "geoscientific/soilgrids/soil1km",
      "geoscientific/soilgrids/soil250m",
      "location/grid")
  )
  expect_setequal(
    find_layer(resolution = c(0, 50), verbose = FALSE)$id,
    c("biota/grassland", "imagery/scanfi")
  )
  # Alberta: overlaps the two continental layers, misses neither
  # bound of the prairie layer.
  ab <- find_layer(extent = c(-120, -110, 49, 60), verbose = FALSE)
  expect_true("elevation/fab_dem" %in% ab$id)
  expect_true("biota/grassland" %in% ab$id)
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

test_that("find_layer matches a CRS by code or by name", {
  root <- local_fixture_share()
  # A variant record supplies the CRS its product record must not
  # restate, so soil1km is matched on the strength of its own half.
  on_3400 <- c("biota/grassland", "geoscientific/soilgrids/soil1km")

  expect_setequal(find_layer(crs = "3400", verbose = FALSE)$id, on_3400)
  expect_setequal(
    find_layer(crs = "EPSG:3400", verbose = FALSE)$id, on_3400
  )
  # The human-readable name works too, case-insensitively.  Only
  # grassland and soil1km name their CRS; soil1km's name comes from
  # the variant record.
  expect_setequal(
    find_layer(crs = "alberta 10-tm", verbose = FALSE)$id, on_3400
  )
  expect_equal(
    find_layer(crs = "4326", verbose = FALSE)$id,
    "geoscientific/soilgrids/soil250m"
  )
  # Layers whose readme records no CRS cannot be matched, and a
  # miss returns no rows rather than everything.
  expect_equal(nrow(find_layer(crs = "26913", verbose = FALSE)), 0)
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
    file.path(root, "misc", "fab_dem", "readme.txt"),
    c("Title: A Second Copy Of FABDEM", "Spatial Resolution: 100 m")
  )
  clear_catalogue_cache()

  expect_error(get_layer("fab_dem"), "matches 2 layers")
  expect_no_error(get_layer("elevation/fab_dem", return_path = TRUE))
})
