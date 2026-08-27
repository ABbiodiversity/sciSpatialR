# ---
# title: helper-catalogue — synthetic spatial data share for tests
# author: Brendan Casey
# created: 2026-08-12
# inputs: none
# outputs: a temporary directory tree mimicking the science share
# notes:
#   The catalogue reads a network share the test suite cannot rely
#   on, so these helpers build a miniature share in tempdir()
#   instead.  The fixture readmes deliberately reproduce the ways
#   real readmes drift from the template — block values, inline
#   values, indented sub-fields, an underscore-prefixed file name,
#   an unedited placeholder copy, extra sections with repeated
#   labels, wrapped URLs, and markdown emphasis — so the parser is
#   tested against the mess it actually meets.
#
#   The tree also carries a `_temp` folder, which the catalogue
#   skips wholesale, and a `misc` folder, which it does not; tests
#   needing a plain undocumented folder use `misc`.
# ---

# 1. Fixture construction ---------------------------------------

#' Write a file, creating its parent directory first
write_fixture <- function(path, lines) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(lines, path)
  invisible(path)
}

#' Build a miniature spatial data share
#'
#' @return Path to the root of the fixture tree.
make_fixture_share <- function() {
  root <- file.path(tempfile("share_"))
  dir.create(root, recursive = TRUE)

  # Theme readmes: the short form, with no Title, so they must not
  # be catalogued as layers.
  write_fixture(file.path(root, "elevation", "readme.txt"), c(
    "Category: elevation",
    "",
    "Description: Height above or below sea level.",
    "",
    "Examples: Altitude, bathymetry, digital elevation models."
  ))
  write_fixture(file.path(root, "biota", "readme.txt"), c(
    "Category: biota",
    "",
    "Description: Flora and/or fauna in natural environments.",
    "",
    "Examples: Wildlife, vegetation, wetlands, habitat."
  ))

  # Block-style values, indented sub-fields, a trailing note the
  # parser will glue onto the last coordinate, and a resolution
  # given as arc-seconds with the metric equivalent in brackets.
  write_fixture(
    file.path(root, "elevation", "fab_dem", "readme.txt"),
    c(
      "==================================================",
      "IDENTIFICATION",
      "==================================================",
      "Title: FABDEM - Forest And Buildings Removed DEM",
      "",
      "Abstract:",
      "A global bare-earth digital elevation model derived from",
      "the Copernicus GLO-30 DEM.",
      "",
      "Purpose:",
      "Terrain and hydrological modelling.",
      "",
      "Credits:",
      "Hawker, L.; Uhe, P.",
      "",
      "Data Language: English",
      "",
      "Topic Category:",
      "geoscientificInformation",
      "",
      "Keywords:",
      "digital elevation model, DEM, bare-earth, terrain",
      "",
      "Spatial Resolution of original product:",
      "1 arc-second (~30 m at the equator)",
      "",
      "Spatial Resolution of this raster:",
      "3.23 arc-seconds (~100 m at the equator)",
      "",
      "==================================================",
      "BAND INFORMATION",
      "==================================================",
      # `Band n: name`, the other style on the share: the name is
      # in the value and the fields sit further indented.
      "Band 1: elevation",
      "        Description: Bare-earth elevation above the",
      "        EGM2008 geoid.",
      "        Units: m",
      "",
      "Band 2: mask",
      "        Description: Valid-data mask.",
      "",
      "==================================================",
      "GEOGRAPHIC INFORMATION",
      "==================================================",
      "Extent:",
      "    West Bounding Coordinate: -179.9999",
      "    East Bounding Coordinate: -50.00023",
      "    North Bounding Coordinate: 82.99984",
      "    South Bounding Coordinate: 24.00029",
      "    Geographic extent in decimal degrees (WGS 84).",
      "",
      "==================================================",
      "TEMPORAL INFORMATION",
      "==================================================",
      "Publication Date: 2022-01-01",
      "",
      "Temporal Extent:",
      "    Start Date: 2010-01-01",
      "    End Date: 2018-12-31",
      "",
      "==================================================",
      "DATA QUALITY",
      "==================================================",
      "Lineage:",
      "Derived from the Copernicus GLO-30 DEM.",
      "",
      "Positional Accuracy:",
      "Inherited from Copernicus WorldDEM-30.",
      "",
      "==================================================",
      "ACCESS AND USE CONSTRAINTS",
      "==================================================",
      "Use Constraints:",
      "CC BY-NC-SA 4.0.",
      "",
      "Access Constraints:",
      "None. Publicly available subject to licence terms.",
      "",
      "==================================================",
      "DISTRIBUTION INFORMATION",
      "==================================================",
      "Format Name:",
      "GeoTIFF",
      "",
      "Size:",
      "11 GB",
      "",
      "Online Resource:",
      "https://doi.org/10.1088/1748-9326/",
      "ac4d4f",
      "",
      "==================================================",
      "CONTACT INFORMATION",
      "==================================================",
      "Point of Contact:",
      "    Name: Laurence Hawker",
      "    Role: Principal Investigator",
      "    Email: hawker@example.org",
      "    Phone: Not provided",
      "",
      "==================================================",
      "ADDITIONAL INFORMATION",
      "==================================================",
      "Metadata Date: 2026-01-23",
      "",
      "Data Citation: Hawker, L. et al. (2022). Env. Res. Lett.",
      "DOI: 10.1088/1748-9326/ac4d4f"
    )
  )
  write_fixture(
    file.path(root, "elevation", "fab_dem", "fab_dem.tif"), "x"
  )
  write_fixture(
    file.path(root, "elevation", "fab_dem", "fab_dem.tif.aux.xml"),
    "x"
  )

  # Inline values, markdown emphasis, trailing double-spaces, a
  # nested layer folder, and two data files so get_layer() must
  # ask which one is wanted.
  write_fixture(
    file.path(root, "biota", "grassland", "readme.txt"),
    c(
      "==================================================",
      "Title: Prairie Grassland  ",
      "Inventory  ",
      "Abstract: Grassland classification for the prairie  ",
      "          provinces derived from Sentinel-2.  ",
      "Purpose: For use in predictive models.  ",
      "Credits: **Mousavi et al.**  ",
      "Data Language: English  ",
      "Topic Category: biota, environment  ",
      "Keywords: grassland, land cover, prairie  ",
      "Spatial Resolution: 30 m  ",
      "",
      "==================================================",
      "GEOGRAPHIC INFORMATION",
      "==================================================",
      "Extent:  ",
      "    West Bounding Coordinate: -120.00  ",
      "    East Bounding Coordinate: -95.00  ",
      "    North Bounding Coordinate: 60.00  ",
      "    South Bounding Coordinate: 49.00  ",
      "",
      "==================================================",
      "REFERENCE SYSTEM",
      "==================================================",
      "Coordinate Reference System:",
      "    Name: NAD83 / Alberta 10-TM (Forest)",
      "    Authority Code: EPSG:3400",
      "    Datum: North American Datum 1983",
      "    Projection: Transverse Mercator",
      "    Vertical CRS: CGVD2013",
      "",
      "==================================================",
      "TEMPORAL INFORMATION",
      "==================================================",
      "Publication Date: 2024-06-01",
      "Temporal Extent:",
      "    Start Date: 2023-01-01",
      "    End Date: Ongoing",
      "",
      "==================================================",
      "DATA QUALITY",
      "==================================================",
      "Lineage: Classified in Google Earth Engine.",
      "Positional Accuracy: Not Specified",
      "",
      "==================================================",
      "ACCESS AND USE CONSTRAINTS",
      "==================================================",
      "Use Constraints: CC BY 4.0",
      "Access Constraints: None.",
      "",
      "==================================================",
      "DISTRIBUTION INFORMATION",
      "==================================================",
      "Format Name: GeoTIFF",
      "Size: 30 GB",
      "Online Resource: https://example.org/grassland",
      "",
      "==================================================",
      "CONTACT INFORMATION",
      "==================================================",
      "Point of Contact:",
      "    Name: Brendan Casey",
      "    Role: Author",
      "    Email: brendan@example.org",
      "",
      "==================================================",
      "ADDITIONAL INFORMATION",
      "==================================================",
      "Metadata Date: 2024-12-17"
    )
  )
  write_fixture(
    file.path(root, "biota", "grassland",
              "alberta_grassland_2023.tif"), "x"
  )
  write_fixture(
    file.path(root, "biota", "grassland",
              "saskatchewan_grassland_2023.tif"), "x"
  )

  # Underscore-prefixed readme, vector data with shapefile
  # sidecars, and an ad hoc section repeating `Description:`.
  write_fixture(
    file.path(root, "transportation", "access_layers", "_readme.txt"),
    c(
      "Title: Government of Alberta Access Layers",
      "    An indented blurb that is not part of the title.",
      "Abstract: Authoritative transportation infrastructure.",
      "Purpose: Infrastructure mapping.",
      "Credits: Alberta Environment and Protected Areas",
      "Data Language: English",
      "Topic Category: transportation",
      "Keywords: roads, railways, powerlines",
      "Spatial Resolution: Not Specified",
      "",
      "==================================================",
      "LAYER INFORMATION",
      "==================================================",
      "Layer 1: Road",
      "        Description: Line features representing roads.",
      "Layer 2: Railway",
      "        Description: Line features representing railways.",
      "",
      "==================================================",
      "GEOGRAPHIC INFORMATION",
      "==================================================",
      "Extent:",
      "    West Bounding Coordinate: -120.00",
      "    East Bounding Coordinate: -110.00",
      "    North Bounding Coordinate: 60.00",
      "    South Bounding Coordinate: 49.00",
      "",
      "Publication Date: 2024-11-01",
      "Lineage: Supplied by the Government of Alberta.",
      "Use Constraints: Open Government Licence - Alberta",
      "Access Constraints: None.",
      "Format Name: Shapefile",
      "Point of Contact:",
      "    Name: Data Manager",
      "    Email: gis@example.org",
      "Metadata Date: 2025-01-10"
    )
  )
  for (ext in c("shp", "dbf", "shx", "prj")) {
    write_fixture(
      file.path(root, "transportation", "access_layers",
                paste0("roads.", ext)), "x"
    )
  }

  # A copied but unedited template: every value is still a
  # placeholder, so check_metadata() must flag it.
  write_fixture(
    file.path(root, "imagery", "unedited", "readme.txt"),
    c(
      "Title: [Data Title]",
      "    A descriptive title (e.g., \"Alberta Land Cover 2020\").",
      "Abstract: [Brief description of the data.]",
      "Purpose: [The intended use or application.]",
      "Spatial Resolution: [Resolution]",
      "   E.g., \"30 m\""
    )
  )
  write_fixture(
    file.path(root, "imagery", "unedited", "cover.tif"), "x"
  )

  # A layer nested inside another layer: the parent must not be
  # credited with the child's files.
  write_fixture(
    file.path(root, "imagery", "scanfi", "_readme.txt"),
    c(
      "Title: SCANFI - Spatialized Canadian National",
      "       Forest Inventory",
      "Abstract: Spatialized Canadian National Forest Inventory.",
      "Spatial Resolution: 30 meters",
      "Publication Date: 2024-11-19",
      "Temporal Extent:",
      "    Start Date: 2020-01-01",
      "    End Date: 2020-12-31"
    )
  )
  write_fixture(
    file.path(root, "imagery", "scanfi", "scanfi_index.tif"), "x"
  )
  write_fixture(
    file.path(root, "imagery", "scanfi", "2020", "readme.txt"),
    c(
      "Title: SCANFI 2020",
      "Abstract: The 2020 SCANFI release.",
      "Spatial Resolution: 1 km",
      "Publication Date: 2024-11-19"
    )
  )
  write_fixture(
    file.path(root, "imagery", "scanfi", "2020", "biomass.tif"), "x"
  )

  # A split record: a product readme carrying the identity and
  # licence, and two variant readmes carrying the geometry of one
  # processed copy each.  The product folder holds no data of its
  # own, so it must contribute no row; each variant must, merged
  # with its parent.  `soil1km` deliberately restates no product
  # field, and `soil250m` overrides the product's Format Name, so
  # both directions of the merge are exercised.
  write_fixture(
    file.path(root, "geoscientific", "soilgrids", "readme.txt"),
    c(
      "Title: SoilGrids 2.0",
      "Abstract: Global soil property predictions at 250 m.",
      "Purpose: Predict soil properties globally.",
      "Credits: ISRIC",
      "Topic Category: geoscientificInformation",
      "Keywords: soil, soil properties, digital soil mapping",
      "Publication Date: 2020-05-04",
      "Lineage: Fitted to global soil profile observations.",
      "Use Constraints: CC BY 4.0",
      "Access Constraints: None",
      "Format Name: GeoTIFF",
      "Point of Contact:",
      "    Name: ISRIC",
      "    Email: soilgrids@isric.org",
      "Metadata Date: 2026-08-24",
      "Variants:",
      "    soil1km     Aligned to the ABMI 1 km reference grid.",
      "    soil250m    Provider resolution.",
      "",
      "==================================================",
      "LAYERS AND BANDS",
      "==================================================",
      "Layer Count: 3",
      "Layers:",
      "    Band: bdod_0-5cm_mean",
      "    Measure: Bulk density of the fine earth fraction",
      "    Units: kg/dm3",
      "    Measurement Scale: continuous",
      "    Valid Range: [REQUIRED - not available from source]",
      "    Description: Mean prediction for the 0-5 cm interval.",
      "",
      "    Band: phh2o_0-5cm_mean",
      "    Measure: Soil pH",
      "    Units: pH",
      "    Measurement Scale: continuous",
      "    Valid Range: 30 to 90",
      "    Description: Mean prediction for the 0-5 cm interval,",
      "        wrapped onto a second line.",
      "",
      "    Band: clay_0-5cm_mean",
      "    Measure: Proportion of clay particles",
      "    Units: g/100g (%)",
      "    Measurement Scale: continuous",
      "    Description: Mean prediction for the 0-5 cm interval.",
      # Flush left, so it closes the last band rather than joining
      # it.  A greedy reader would file this under clay_0-5cm_mean.
      "Class Definitions: None"
    )
  )
  write_fixture(
    file.path(root, "geoscientific", "soilgrids", "soil1km",
              "readme.txt"),
    c(
      "Variant ID: soilgrids__soil1km",
      "Product ID: soilgrids",
      "Parent Record: ../readme.txt",
      "Spatial Resolution: 1000 m",
      "Coordinate Reference System:",
      "    Name: NAD83 / Alberta 10-TM (Forest)",
      "    Authority Code: EPSG:3400",
      "Extent:",
      "    West Bounding Coordinate: -120.9066",
      "    East Bounding Coordinate: -108.4484",
      "    North Bounding Coordinate: 59.9647",
      "    South Bounding Coordinate: 48.8941",
      "Derived From: Source",
      "Operation: aggregate",
      "Metadata Date: 2026-08-24"
    )
  )
  write_fixture(
    file.path(root, "geoscientific", "soilgrids", "soil1km",
              "soilgrids_soil1km.tif"), "x"
  )
  write_fixture(
    file.path(root, "geoscientific", "soilgrids", "soil250m",
              "readme.txt"),
    c(
      "Variant ID: soilgrids__soil250m",
      "Product ID: soilgrids",
      "Parent Record: ../readme.txt",
      "Spatial Resolution: 250 m",
      "Coordinate Reference System:",
      "    Authority Code: EPSG:4326",
      "Format Name: COG",
      "Metadata Date: 2026-08-24"
    )
  )
  write_fixture(
    file.path(root, "geoscientific", "soilgrids", "soil250m",
              "soilgrids_soil250m.tif"), "x"
  )

  # A variant folder holding data but no variant readme, beside one
  # that has both.  The product record does not document it, so it
  # must be reported as undocumented rather than silently covered.
  write_fixture(
    file.path(root, "geoscientific", "soilgrids", "soil90m",
              "soilgrids_soil90m.tif"), "x"
  )

  # A file geodatabase: a directory of internal tables, none of them
  # a dataset and none with a recognised extension.  It must count
  # as one vector dataset, not as its contents and not as nothing.
  # `a00000001.gdbtable` is here on purpose — its extension starts
  # with "gdb", so a greedy match would collapse to the wrong path.
  write_fixture(
    file.path(root, "location", "grid", "readme.txt"),
    c(
      "Title: ABMI 1 km Reference Grid",
      "Abstract: The 1 km grid the share is aligned to.",
      "Spatial Resolution: 1000 m",
      "Publication Date: 2020-01-01",
      "",
      "==================================================",
      "LAYERS",
      "==================================================",
      # `Layer n:` with the name arriving as a field rather than in
      # the value, which is how vector products document theirs.
      "Layer 1:",
      "    Name: Grid_1KM_revAB2020",
      "    Geometry: Multi Polygon",
      "    Notes: The 1 km cells, clipped to the boundary.",
      "",
      "Layer 2:",
      "    Name: linkid_1km_to_10km",
      "    Geometry: None (non-spatial table)",
      "    Notes: A lookup from 1 km cell to 10 km group."
    )
  )
  for (part in c("a00000001.gdbtable", "a00000001.gdbtablx",
                 "a00000004.spx", "gdb", "timestamps")) {
    write_fixture(
      file.path(root, "location", "grid", "GRID1SQKM.gdb", part), "x"
    )
  }

  # The same, with no readme, so the folder holding it is reported
  # as undocumented rather than looking empty of spatial data.
  write_fixture(
    file.path(root, "location", "undocumented_grid",
              "OTHER.gdb", "a00000001.gdbtable"), "x"
  )

  # Spatial data with no readme at all, under a theme folder that
  # has no readme either.  Deliberately not under `_temp`, which the
  # catalogue skips wholesale.
  write_fixture(
    file.path(root, "misc", "orphan", "distance_to_water.tif"), "x"
  )

  # The scratch folder, which no scan should see: a layer with a
  # perfectly good readme, and data with none.  Both are excluded,
  # so neither is catalogued nor reported as undocumented.
  write_fixture(
    file.path(root, "_temp", "scratch_dem", "readme.txt"),
    c(
      "Title: Work In Progress DEM",
      "Abstract: A staging copy that is not part of the catalogue.",
      "Spatial Resolution: 10 m",
      "Publication Date: 2024-01-01"
    )
  )
  write_fixture(
    file.path(root, "_temp", "scratch_dem", "wip.tif"), "x"
  )
  write_fixture(
    file.path(root, "_temp", "exports", "untracked.tif"), "x"
  )

  normalizePath(root, winslash = "/")
}


# 2. Scoped fixture ---------------------------------------------

#' Point the catalogue at a fresh fixture share for one test
#'
#' Sets the root option, clears the manifest cache, and restores
#' both when the calling test finishes.
#'
#' @param env Environment the cleanup is attached to.
#' @return The fixture root path.
local_fixture_share <- function(env = parent.frame()) {
  root <- make_fixture_share()
  old  <- options(sciSpatialR.spatial_root = root)
  clear_catalogue_cache()

  withr::defer(
    {
      options(old)
      clear_catalogue_cache()
      unlink(root, recursive = TRUE)
    },
    envir = env
  )
  root
}


#' Empty the session manifest cache
clear_catalogue_cache <- function() {
  cache <- sciSpatialR:::.catalogue_cache
  rm(list = ls(cache, all.names = TRUE), envir = cache)
  invisible(NULL)
}

# End of script ----
