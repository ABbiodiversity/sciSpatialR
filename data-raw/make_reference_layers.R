# ---
# title: Build the sciSpatialR reference boundary and grid
# author: Brendan Casey
# created: 2026-08-12
# inputs:
#   //ABMI-DATA2/science/spatial_data/
#     boundaries/administrativeBoundaries/alberta/
#       AB2020_provincial_boundary.shp - Alberta provincial boundary
#       (2020 revision), NAD83 / Alberta 10-TM Forest (EPSG:3400)
#     location/referenceGrids/GRID1SQKM_AB2020_gdb/
#       GRID1SQKM_AB2020.gdb - ABMI 1 km reference grid; layer
#       Grid_1KM_revAB2020 holds 664,762 cells clipped to the
#       provincial boundary and labelled "<row>_<col>"
# outputs:
#   inst/extdata/alberta.gpkg     - provincial boundary polygon
#   inst/extdata/grid_1km.tif     - 1 km reference grid template
# notes:
#   Regenerates the two reference layers shipped with the package.
#   Run manually from the package root when the source layers are
#   revised; the outputs are committed, so this script is not run
#   at build or install time and requires access to the ABMI
#   network share.
#
#   The 1 km grid is distributed as a raster template rather than
#   as the source polygons: the file geodatabase is ~340 MB, which
#   is unsuitable for version control, and every harmonization
#   function in this package consumes the reference grid as a
#   SpatRaster.  The template is snapped to the polygon grid's own
#   lattice, so raster row/column indices reproduce the source
#   GRID_LABEL values exactly (see section 3).  Cells that exist in
#   the source grid are set to 1; cells outside Alberta are NA.
#
#   Proposed improvement: publish the 10 km grid and the
#   linkid_1km_to_10km lookup as a companion data package if
#   cross-scale joins become a common need.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(sf) # read shapefile and file geodatabase layers (1.0.21)
library(terra) # build and write the raster template (1.8.50)

## 1.2 Define paths ----
# Source layers live in the catalogue on the ABMI science share,
# each under its own theme; outputs are written into the package's
# inst/extdata/ folder.  Both source folders carry a readme.txt
# documenting the layer's lineage.
source_dir <- file.path(
  "//ABMI-DATA2",
  "science",
  "spatial_data"
)
boundary_shp <- file.path(
  source_dir,
  "boundaries",
  "administrativeBoundaries",
  "alberta",
  "AB2020_provincial_boundary.shp"
)
grid_gdb <- file.path(
  source_dir,
  "location",
  "referenceGrids",
  "GRID1SQKM_AB2020_gdb",
  "GRID1SQKM_AB2020.gdb"
)
grid_layer <- "Grid_1KM_revAB2020"

# View available layer names
st_layers(grid_gdb)

out_dir <- file.path("inst", "extdata")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

## 1.3 Grid constants ----
# Cell size of the source grid, in CRS units (metres).
cell_size <- 1000

# 2. Write the provincial boundary ----
# The source shapefile is a single dissolved polygon already in
# EPSG:3400.  It is rewritten as a GeoPackage so the package ships
# one file rather than the eight-file shapefile set.  The Shape_*
# attributes are dropped: they are ArcGIS bookkeeping fields that
# would go stale if the geometry were ever edited.

boundary <- st_read(boundary_shp, quiet = TRUE)
stopifnot(nrow(boundary) == 1)
stopifnot(st_crs(boundary)$epsg == 3400)

boundary <- st_geometry(boundary)
st_write(
  st_sf(geometry = boundary),
  file.path(out_dir, "alberta.gpkg"),
  layer = "alberta",
  delete_dsn = TRUE,
  quiet = TRUE
)

# 3. Derive the 1 km grid lattice ----
# GRID_LABEL encodes each cell's position as "<row>_<col>", with
# row 1 at the north edge and col 1 at the west edge of the
# unclipped grid rectangle.  Reading the labels without geometry is
# cheap (664,762 rows), and the lattice anchor is recovered from a
# handful of full-size cells, so the template lands on exactly the
# same cell boundaries as the source polygons.

## 3.1 Read cell labels ----
labels <- st_read(
  grid_gdb,
  query = paste(
    "SELECT GRID_LABEL, GridArea FROM",
    grid_layer
  ),
  quiet = TRUE
)

label_parts <- do.call(
  rbind,
  strsplit(labels$GRID_LABEL, "_", fixed = TRUE)
)
grid_row <- as.integer(label_parts[, 1])
grid_col <- as.integer(label_parts[, 2])

stopifnot(!anyNA(grid_row), !anyNA(grid_col))
stopifnot(min(grid_row) == 1, min(grid_col) == 1)

n_row <- max(grid_row)
n_col <- max(grid_col)

## 3.2 Recover the lattice anchor ----
# Edge cells are clipped to the provincial boundary, so the anchor
# is derived only from cells whose area is a full square kilometre.
# Several are checked to confirm they agree on one lattice.
full_cells <- labels$GRID_LABEL[
  abs(labels$GridArea - cell_size^2) < 1e-6
]
stopifnot(length(full_cells) > 0)

probe_labels <- full_cells[
  round(seq(1, length(full_cells), length.out = 5))
]
probes <- st_read(
  grid_gdb,
  query = paste0(
    "SELECT GRID_LABEL FROM ",
    grid_layer,
    " WHERE GRID_LABEL IN ('",
    paste(probe_labels, collapse = "','"),
    "')"
  ),
  quiet = TRUE
)

probe_parts <- do.call(
  rbind,
  strsplit(probes$GRID_LABEL, "_", fixed = TRUE)
)
probe_box <- vapply(
  seq_len(nrow(probes)),
  function(i) as.numeric(st_bbox(probes[i, ])),
  numeric(4)
)

# Anchor = north-west corner of cell (row 1, col 1).
anchor_x <- probe_box[1, ] -
  (as.integer(probe_parts[, 2]) - 1) * cell_size
anchor_y <- probe_box[4, ] +
  (as.integer(probe_parts[, 1]) - 1) * cell_size

stopifnot(diff(range(anchor_x)) < 1e-6)
stopifnot(diff(range(anchor_y)) < 1e-6)

anchor_x <- mean(anchor_x)
anchor_y <- mean(anchor_y)

# 4. Build and write the grid template ----
# Cells present in the source grid are set to 1; the rest stay NA.
# Row-major cell numbering in terra matches the "<row>_<col>"
# label scheme, so cells are addressed arithmetically instead of
# rasterising 664,762 polygons.

grid_ref <- rast(
  nrows = n_row,
  ncols = n_col,
  xmin = anchor_x,
  xmax = anchor_x + n_col * cell_size,
  ymin = anchor_y - n_row * cell_size,
  ymax = anchor_y,
  crs = "EPSG:3400",
  vals = NA_integer_
)
names(grid_ref) <- "grid_1km"

grid_ref[cellFromRowCol(grid_ref, grid_row, grid_col)] <- 1L

stopifnot(
  global(grid_ref, "notNA")[[1]] == nrow(labels)
)

writeRaster(
  grid_ref,
  file.path(out_dir, "grid_1km.tif"),
  overwrite = TRUE,
  datatype = "INT1U",
  NAflag = 0,
  gdal = c(
    "COMPRESS=DEFLATE",
    "ZLEVEL=9",
    "PREDICTOR=2",
    "TILED=YES"
  )
)

# 5. Report ----
# Print the geometry that downstream code is harmonized to, so a
# rebuild can be compared against the values documented in
# inst/extdata/README.md.

message("Boundary and grid written to ", normalizePath(out_dir))
message("Grid dimensions: ", n_row, " rows x ", n_col, " cols")
message(
  "Grid extent: ",
  paste(format(as.vector(ext(grid_ref)), nsmall = 4), collapse = ", ")
)
message("Grid cells: ", nrow(labels))

# End of script ----
