# ---
# title: reference — default Alberta reference bounds, grid, and CRS
# author: Brendan Casey
# created: 2026-08-12
# inputs:
#   inst/extdata/alberta.gpkg - Alberta provincial boundary (2020)
#   inst/extdata/grid_1km.tif - 1 km reference grid template
# outputs: SpatVector boundary, SpatRaster grid, CRS string
# notes:
#   Accessors for the layers every harmonization function in this
#   package defaults to.  Alberta-focused workflows harmonize to the
#   ABMI 1 km grid in NAD83 / Alberta 10-TM Forest (EPSG:3400), so
#   these are the defaults rather than something each caller has to
#   supply.
#
#   Layers are read from disk on every call rather than cached in a
#   package environment: terra objects hold external pointers that
#   become invalid across sessions, and both files are small enough
#   (a single polygon; a 1234 x 695 template) that re-reading costs
#   little.  Raster values are not loaded until they are used.
#
#   See inst/extdata/README.md for provenance of both layers.
# ---

# 1. ab_crs -----------------------------------------------------

#' Default coordinate reference system for Alberta workflows
#'
#' Returns the CRS that sciSpatialR harmonizes to: NAD83 / Alberta
#' 10-TM (Forest), `EPSG:3400`.  This is the CRS of both
#' [ab_boundary()] and [ab_grid()].
#'
#' @return A length-one character string, `"EPSG:3400"`, suitable
#'   for [terra::project()], [sf::st_transform()], and friends.
#'
#' @examples
#' ab_crs()
#'
#' @export
ab_crs <- function() {
  "EPSG:3400"
}


# 2. ab_boundary ------------------------------------------------

#' Alberta provincial boundary
#'
#' Returns the 2020 revision of the Alberta provincial boundary as a
#' single dissolved polygon in [ab_crs()].  This is the default
#' boundary used by [mask_to_boundary()].
#'
#' @return A `SpatVector` containing one polygon.
#'
#' @seealso [mask_to_boundary()] to clip a raster to this boundary.
#'
#' @examples
#' \dontrun{
#' ab <- ab_boundary()
#' terra::ext(ab)
#' }
#'
#' @export
ab_boundary <- function() {
  terra::vect(.reference_path("alberta.gpkg"))
}


# 3. ab_grid ----------------------------------------------------

#' ABMI 1 km reference grid
#'
#' Returns the ABMI 1 km reference grid for Alberta as a template
#' `SpatRaster`: 1234 rows by 695 columns of 1000 m cells in
#' [ab_crs()].  Cells belonging to the grid (those covering Alberta)
#' hold the value 1; cells outside the province are `NA`.
#'
#' This is the default reference grid for [check_alignment()],
#' [resample_to_grid()], [aggregate_to_grid()], and
#' [harmonize_crs()], so harmonized layers share one CRS, extent,
#' resolution, and origin by default.
#'
#' The template is snapped to the lattice of the source grid
#' polygons, so a cell's raster row and column reproduce its source
#' `GRID_LABEL` (`"<row>_<col>"`, row 1 at the north edge, column 1
#' at the west edge).
#'
#' @return A `SpatRaster` with a single layer named `grid_1km`.
#'
#' @seealso [resample_to_grid()] and [aggregate_to_grid()] to
#'   harmonize a layer onto this grid; [check_alignment()] to test a
#'   layer against it.
#'
#' @examples
#' \dontrun{
#' ref <- ab_grid()
#' terra::res(ref)
#' terra::ext(ref)
#' }
#'
#' @export
ab_grid <- function() {
  terra::rast(.reference_path("grid_1km.tif"))
}


# Internal helper -------------------------------------------------

#' Resolve the path to a packaged reference layer
#'
#' @param file Character; file name within `inst/extdata`.
#' @return An absolute file path.
#' @noRd
.reference_path <- function(file) {
  path <- system.file("extdata", file, package = "sciSpatialR")
  if (!nzchar(path) || !file.exists(path)) {
    stop(
      "Reference layer '", file, "' not found in the installed ",
      "package. Reinstall sciSpatialR, or rebuild the layer with ",
      "data-raw/make_reference_layers.R.",
      call. = FALSE
    )
  }
  path
}

# End of script ----
