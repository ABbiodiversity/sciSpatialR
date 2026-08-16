Browsing the spatial data catalogue
================

``` r
library(sciSpatialR)
```

## The share is the catalogue

There is no manifest file to maintain. `build_catalogue()` walks
`\\ABMI-DATA2\science\spatial_data`, parses the readme stored beside
each dataset, and assembles a table from what it finds. Documenting a
dataset means editing its readme; nothing has to be registered anywhere,
and the catalogue cannot drift from the data.

Folders follow the ISO 19115 topic categories and readmes follow the
ABMI spatial metadata template, both documented in the [geospatial
catalog and management
guide](https://github.com/bgcasey/geospatial_catalog_and_management_guide).

A folder is catalogued as a **layer** when it holds a readme written to
the dataset template. Theme folders carry a shorter
`Category`/`Description`/`Examples` readme and are reported by
`list_themes()` instead. Datasets sit at whatever depth a theme needs,
so each layer has both a short `name` (`fab_dem`) and a full `id`
(`elevation/fab_dem`).

## Pointing at the share

`spatial_root()` reports where the catalogue reads from and errors if
the share is unreachable.

``` r
spatial_root()
#> [1] "//ABMI-DATA2/science/spatial_data"
```

To work from a mirror, a mapped drive, or a local copy, set an option or
an environment variable:

``` r
options(sciSpatialR.spatial_root = "D:/spatial_data")
Sys.setenv(SCISPATIALR_SPATIAL_ROOT = "D:/spatial_data")
```

## Browsing

Start with the themes, which show the topic categories and how much sits
under each:

``` r
list_themes()
```

    12 themes, 15 layers catalogued

     theme                            description                                        n_layers
     elevation                        Height above or below sea level.                   5
     inlandWaters                     Inland water features, drainage systems, and thei… 4
     biota                            Flora and/or fauna in natural environments.        2
     imageryBaseMapsEarthCover        Base maps.                                         2
     temp                             <NA>                                               1
     transportation                   Means and aids for conveying persons and/or goods. 1
     boundaries                       Legal land descriptions.                           0
     climatologyMeteorologyAtmosphere Processes and phenomena of the atmosphere.         0
     economy                          Economic activities, conditions, and employment.   0
     environment                      Environmental resources, protection, and conserva… 0
     farming                          Rearing of animals and/or cultivation of plants.   0
     geoscientificInformation         Information pertaining to earth sciences.          0

Every ISO 19115 topic category appears, including the ones nothing is
filed under yet, so the empty folders read as available rather than
missing. A theme with no readme of its own also still appears, with no
description, so an undocumented theme folder stays visible rather than
dropping out of the listing.

The returned table carries an `examples` column as well, too long to
tabulate but useful when deciding where a new dataset belongs.

Then list the layers:

``` r
list_layers()
```

    15 layers in 6 themes

     id                                                            title                                         year resolution_m data_type
     biota/natural_regions/natural_regions_subregions_of_alberta   Natural Regions and Subregions of Alberta     2022     NA       vector
     biota/vegetation/grassland_inventory                          Grassland Inventory for Alberta, Manitoba, a… 2024  30.00       raster
     elevation/fab_dem                                             FABDEM – Forest And Buildings Removed Copern… 2018 100.00       raster
     elevation/geomorpho90                                         Alberta Geomorphometric Layers (Geomorpho90m) 2023  90.00       raster
     elevation/nrcan_mrdem_dsm                                     Medium Resolution Digital Elevation Model (M… 2006  30.00       raster
     elevation/nrcan_mrdem_dtm                                     Medium Resolution Digital Elevation Model (M… 2006  30.00       raster
     elevation/nrcan_mrdem_dtm_hillshade                           Medium Resolution Digital Elevation Model (M… 2006  30.00       raster
     imageryBaseMapsEarthCover/modis_land_cover_dynamics_2001_2023 MODIS Annual Land Cover Dynamics (MCD12Q2) -… 2023 500.00       raster
     imageryBaseMapsEarthCover/scanfi_v1.2                         SCANFI: Spatialized Canadian National Forest… 2020  30.00       raster
     inlandWaters/dynamicSurfaceWaterMaps                          Dynamic Surface Water Maps of Canada from 19… 2023     NA       raster
     inlandWaters/hydrologically adjusted elevations               Height Above Nearest Drainage (HAND) - Hydro… 2024  92.77       raster
     inlandWaters/streams/archydro2                                Alberta ArcHydro Phase 2 Data                 1996 100.00       vector
     inlandWaters/topographic_wetness_index                        Topographic Wetness Index (TWI)               2024  92.77       raster
     temp/sentinel2_summer_mean_indices_2019_2024                  Sentinel-2 Time Series - Alberta Spectral In… 2024  10.00       raster
     transportation/government_of_alberta_access_layers            Access and Facility Roads - Alberta           2023     NA       vector

Or narrow the listing to one theme:

``` r
list_layers(theme = "elevation")
```

    5 layers in 1 theme

     id                                  title                                         year resolution_m data_type
     elevation/fab_dem                   FABDEM – Forest And Buildings Removed Copern… 2018 100          raster
     elevation/geomorpho90               Alberta Geomorphometric Layers (Geomorpho90m) 2023  90          raster
     elevation/nrcan_mrdem_dsm           Medium Resolution Digital Elevation Model (M… 2006  30          raster
     elevation/nrcan_mrdem_dtm           Medium Resolution Digital Elevation Model (M… 2006  30          raster
     elevation/nrcan_mrdem_dtm_hillshade Medium Resolution Digital Elevation Model (M… 2006  30          raster

`list_layers()` prints a summary and returns the manifest invisibly.
Assign it, or pass `verbose = FALSE`, to work with the full table — one
row per layer, carrying the parsed template fields alongside `n_files`,
`size_mb`, `data_type`, `path`, and `readme`.

``` r
cat_df <- list_layers(verbose = FALSE)
dim(cat_df)
#> [1] 15 37
```

Thirty-seven columns is too wide to print whole; a few of them give the
shape of the table:

``` r
cat_df[1:5, c("name", "theme", "year", "resolution_m",
              "n_files", "size_mb", "data_type")]
```

                                       name     theme year resolution_m n_files size_mb data_type
    1 natural_regions_subregions_of_alberta     biota 2022           NA       1    11.2    vector
    2                   grassland_inventory     biota 2024           30       3 30110.4    raster
    3                               fab_dem elevation 2018          100       1 11272.9    raster
    4                           geomorpho90 elevation 2023           90       1 11197.9    raster
    5                       nrcan_mrdem_dsm elevation 2006           30       1 56895.8    raster

The full set of fields — the parsed template alongside the columns the
file scan adds:

``` r
names(cat_df)
```

     [1] "id"                 "name"               "theme"              "sub_theme"          "title"              "topic_category"
     [7] "keywords"           "year"               "resolution"         "resolution_m"       "xmin"               "xmax"
    [13] "ymin"               "ymax"               "crs"                "publication_date"   "start_date"         "end_date"
    [19] "format"             "size"               "use_constraints"    "access_constraints" "contact_name"       "contact_email"
    [25] "doi"                "online_resource"    "metadata_date"      "abstract"           "purpose"            "credits"
    [31] "lineage"            "citation"           "n_files"            "size_mb"            "data_type"          "path"
    [37] "readme"

### The catalogue as it stands

The table below is a frozen scan of the share, rendered when this
vignette was built. It is what `list_layers(verbose = FALSE)` returns,
narrowed to the columns worth tabulating — run the call yourself for the
live version and the other thirty-odd columns.

| theme | name | title | year | res (m) | type | size (MB) |
|:---|:---|:---|---:|---:|:---|---:|
| biota | natural_regions_subregions_of_alberta | Natural Regions and Subregions of Alberta | 2022 |  | vector | 11.2 |
| biota | grassland_inventory | Grassland Inventory for Alberta, Manitoba, and Saskatchewan (2023) | 2024 | 30.00 | raster | 30,110.4 |
| boundaries | alberta | AB2020_provincial_boundary | 2023 |  | vector | 0.4 |
| elevation | fab_dem | FABDEM – Forest And Buildings Removed Copernicus Global DEM (30 m) | 2018 | 100.00 | raster | 11,272.9 |
| elevation | geomorpho90 | Alberta Geomorphometric Layers (Geomorpho90m) | 2023 | 90.00 | raster | 11,197.9 |
| elevation | nrcan_mrdem_dsm | Medium Resolution Digital Elevation Model (MRDEM) - DSM Cloud Optimized GeoTIFF (COG) | 2006 | 30.00 | raster | 56,895.8 |
| elevation | nrcan_mrdem_dtm | Medium Resolution Digital Elevation Model (MRDEM) - DTM Cloud Optimized GeoTIFF (COG) | 2006 | 30.00 | raster | 57,503.7 |
| elevation | nrcan_mrdem_dtm_hillshade | Medium Resolution Digital Elevation Model (MRDEM) - DTM Hillshade Cloud Optimized GeoTIFF (COG) | 2006 | 30.00 | raster | 13,648.1 |
| imageryBaseMapsEarthCover | modis_land_cover_dynamics_2001_2023 | MODIS Annual Land Cover Dynamics (MCD12Q2) - 500m Phenology | 2023 | 500.00 | raster | 2,529.0 |
| imageryBaseMapsEarthCover | scanfi_v1.2 | SCANFI: Spatialized Canadian National Forest Inventory | 2020 | 30.00 | raster | 34,349.8 |
| inlandWaters | dynamicSurfaceWaterMaps | Dynamic Surface Water Maps of Canada from 1984-2023 Landsat Satellite Imagery | 2023 |  | raster | 21,796.5 |
| inlandWaters | hydrologically adjusted elevations | Height Above Nearest Drainage (HAND) - Hydrologically Adjusted Elevations | 2024 | 92.77 | raster | 239.0 |
| inlandWaters | archydro2 | Alberta ArcHydro Phase 2 Data | 1996 | 100.00 | vector | 680.3 |
| inlandWaters | topographic_wetness_index | Topographic Wetness Index (TWI) | 2024 | 92.77 | raster | 1,193.0 |
| location | GRID1SQKM_AB2020_gdb | GRID1SQKM_AB2020 |  | 1,000.00 |  | 322.8 |
| location | GRID1SQKM_AB2020_raster | GRID1SQKM_AB2020_raster | 2026 | 1,000.00 | raster | 0.0 |
| temp | sentinel2_summer_mean_indices_2019_2024 | Sentinel-2 Time Series - Alberta Spectral Indices (2015-2024) | 2024 | 10.00 | raster | 6,488,598.4 |
| transportation | government_of_alberta_access_layers | Access and Facility Roads - Alberta | 2023 |  | vector | 1,399.7 |

The spatial data catalogue, scanned 2026-08-16.

Blank cells are fields the readme leaves unfilled, which is what keeps a
layer out of the matching `find_layer()` filter.

## Finding a layer

`find_layer()` searches by what a layer *is* rather than where it lives.
`keyword` matches the folder name, title, keywords, topic category, and
abstract:

``` r
find_layer(keyword = "elevation")
```

    10 layers in 4 themes

     id                                                            title                                         year resolution_m data_type
     biota/natural_regions/natural_regions_subregions_of_alberta   Natural Regions and Subregions of Alberta     2022     NA       vector
     elevation/fab_dem                                             FABDEM – Forest And Buildings Removed Copern… 2018 100.00       raster
     elevation/geomorpho90                                         Alberta Geomorphometric Layers (Geomorpho90m) 2023  90.00       raster
     elevation/nrcan_mrdem_dsm                                     Medium Resolution Digital Elevation Model (M… 2006  30.00       raster
     elevation/nrcan_mrdem_dtm                                     Medium Resolution Digital Elevation Model (M… 2006  30.00       raster
     elevation/nrcan_mrdem_dtm_hillshade                           Medium Resolution Digital Elevation Model (M… 2006  30.00       raster
     imageryBaseMapsEarthCover/modis_land_cover_dynamics_2001_2023 MODIS Annual Land Cover Dynamics (MCD12Q2) -… 2023 500.00       raster
     inlandWaters/hydrologically adjusted elevations               Height Above Nearest Drainage (HAND) - Hydro… 2024  92.77       raster
     inlandWaters/streams/archydro2                                Alberta ArcHydro Phase 2 Data                 1996 100.00       vector
     inlandWaters/topographic_wetness_index                        Topographic Wetness Index (TWI)               2024  92.77       raster

Note the first hit: a layer filed under `biota` matched on its abstract,
which is the point of searching metadata rather than folder names.

Filters combine, and each takes either a single value or a `c(min, max)`
range:

``` r
find_layer(year = c(2020, 2024))
find_layer(resolution = c(0, 120))
find_layer(extent = c(-120, -110, 49, 60))   # decimal degrees
find_layer(theme = "elevation", resolution = 30)
```

A filter narrows to layers *known* to match. Resolution, year, and
extent come from the readme, so a layer whose readme leaves the field
blank is excluded rather than guessed at — `check_metadata()` will show
you which readmes are keeping a layer out.

## Loading a layer

`get_layer()` reads the data with terra, returning a `SpatRaster` or a
`SpatVector` depending on the format:

``` r
twi <- get_layer("topographic_wetness_index")
nsr <- get_layer("natural_regions_subregions_of_alberta")
```

Pass `return_path = TRUE` when you want the file rather than the object
— to hand it to another tool, or to open it with your own arguments:

``` r
get_layer("fab_dem", return_path = TRUE)
#> [1] "//ABMI-DATA2/science/spatial_data/elevation/fab_dem/fab_dem_us_canada.tif"
```

Some folders hold several datasets. `layer_files()` shows what is there,
and `file` picks one:

``` r
layer_files("grassland_inventory")
#> [1] ".../alberta_grassland_classification_2023.tif"
#> [2] ".../manitoba_grassland_classification_2023.tif"
#> [3] ".../saskatchewan_grassland_classification_2023.tif.tif"

get_layer("grassland_inventory", file = "alberta")
```

Asking for a multi-file layer without `file` is an error that lists the
candidates, so you never silently get the wrong raster. Shapefile
sidecars (`.dbf`, `.shx`, `.prj`) are hidden; pass `all = TRUE` to see
every file in the folder.

Short names work when unambiguous. If two themes hold a folder of the
same name, use the full id:

``` r
get_layer("elevation/fab_dem")
```

## Reading the metadata

`layer_meta()` prints a layer’s provenance, licence, and contact
details, and returns the parsed fields invisibly:

``` r
layer_meta("fab_dem")
```

    <sciSpatialR metadata>
      file: //ABMI-DATA2/science/spatial_data/elevation/fab_dem/readme.txt
      Title       FABDEM – Forest And Buildings Removed Copernicus Global DEM…
      Abstract    FABDEM is a global, bare-earth digital elevation model deri…
      Purpose     To provide a globally consistent, near–bare-earth digital e…
      Topic       geoscientificInformation
      Keywords    digital elevation model, DEM, bare-earth, terrain, topograp…
      Resolution  3.23 arc-seconds (~100 m at the equator)
      Published   2022-01-01
      Start       2010-01-01
      End         2018-12-31
      Lineage     FABDEM was derived from the Copernicus GLO-30 Digital Eleva…
      Format      GeoTIFF
      Size        Global dataset; size varies by tile (1° × 1° tiles grouped …
      Use         Creative Commons Attribution–NonCommercial–ShareAlike 4.0 I…
      Access      None. Data is publicly available subject to license terms.
      Contact     Laurence Hawker
      DOI         10.1088/1748-9326/ac4d4f
      Source      https://doi.org/10.1088/1748-9326/ac4d4f
      Updated     2026-01-23

Values are truncated for display only; the returned object holds them in
full. Fields the readme left blank are omitted from the printout — here
`Credits` and `Email`, which `check_metadata()` reports below.

Every `Label: value` line in the readme is captured, not just the
template fields, so anything a readme records is reachable. Labels
become `snake_case` keys, and sub-fields indented under a parent are
prefixed with it:

``` r
md <- layer_meta("fab_dem", print = FALSE)
md$use_constraints
md$extent_west_bounding_coordinate
md$temporal_extent_start_date
```

`read_metadata()` does the same for a readme you name by path, and
`as_metadata_row()` flattens the result to a one-row `data.frame` with
the numeric fields coerced — resolution to metres, bounding coordinates
to decimal degrees, dates to a `year`:

``` r
md <- read_metadata("path/to/readme.txt")
as_metadata_row(md)
```

Unfilled template placeholders (`[Data Title]`) and non-values
(`"Not Specified"`) are returned as `NA` rather than as text, so a
copied-but-unedited readme reads as missing rather than documented.

## Auditing the metadata

`check_metadata()` scores every layer against the required template
fields and lists the data folders that have no readme at all:

``` r
check_metadata()
```

    33 layers audited, 18 with no readme

     id                                                      n_missing complete missing
     …yAtmosphere/climate_na/fab_dem_us_canada_int/Year_2000 NA        0.000    readme
     …/SCANFI_additional_outputs_v2_20260119/biomass_outputs NA        0.000    readme
     temp/distance_to_water                                  NA        0.000    readme
     temp/scanfi_v2/SCANFI_age_v2_20260119                   NA        0.000    readme
     biota/vegetation/grassland_inventory                     8        0.579    purpose, xmin, xmax, ymin, ymax, use_constra…
     imageryBaseMapsEarthCover/scanfi_v1.2                    6        0.684    purpose, xmin, xmax, ymin, ymax, lineage
     elevation/fab_dem                                        2        0.895    credits, contact_email
     elevation/nrcan_mrdem_dsm                                1        0.947    access_constraints
     elevation/geomorpho90                                    0        1.000

(Abridged; folders with no readme sort first, then the least complete
readmes.) Rows with `missing = "readme"` are folders holding spatial
data that the catalogue cannot see at all — they are the first thing to
fix. Deep ids are trimmed from the front when printed, since the last
segment is what distinguishes one from another; the returned table holds
them in full.

Use `detail = TRUE` for one row per missing field, which is easier to
tabulate:

``` r
check_metadata(detail = TRUE)
check_metadata(theme = "elevation", detail = TRUE)
```

    5 missing fields across 4 layers

     id                                  theme     field
     elevation/fab_dem                   elevation credits
     elevation/fab_dem                   elevation contact_email
     elevation/nrcan_mrdem_dsm           elevation access_constraints
     elevation/nrcan_mrdem_dtm           elevation access_constraints
     elevation/nrcan_mrdem_dtm_hillshade elevation access_constraints

## Caching

Scanning a network share is the slow step, so the manifest is built once
per session and reused. After editing a readme or adding data, rescan:

``` r
build_catalogue(refresh = TRUE)
```

`build_catalogue(files = FALSE)` skips the file inventory for a faster,
metadata-only scan; `n_files`, `size_mb`, and `data_type` are then `NA`.
Any argument accepted by `build_catalogue()` can be passed through the
query functions:

``` r
list_layers(root = "D:/spatial_data", refresh = TRUE)
```

## Adding a field to the template

Readmes are parsed generically rather than against a fixed schema, so a
field you add to the template is readable immediately, with no change to
the package. Every `Label: value` line is captured, and a sub-field
indented under a parent label is namespaced by it. Given this block:

    Coordinate Reference System:
        Name: NAD83 / Alberta 10-TM (Forest)
        Authority Code: EPSG:3400
        Datum: North American Datum 1983
        Projection: Transverse Mercator
        Vertical CRS: CGVD2013

every part is reachable at once:

``` r
md <- layer_meta("some_layer", print = FALSE)
md$coordinate_reference_system_authority_code
#> [1] "EPSG:3400"
md$coordinate_reference_system_projection
#> [1] "Transverse Mercator"
```

What is *not* automatic is becoming a column of the manifest, and so a
filter in `find_layer()`. That takes one edit: add the parsed key to
`.meta_field_map` in `R/metadata.R`. Adding it to `.meta_required` in
the same file makes `check_metadata()` count it towards completeness.
`R/catalogue.R` builds its columns from that map and needs no change.
