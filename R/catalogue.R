# ---
# title: Catalogue and Provenance functions (placeholders)
# author: Brendan Casey
# created: 2026-08-12
# inputs:  catalogue manifest (to be implemented)
# outputs: layer information, SpatRaster objects or file paths
# notes:
#   These functions are placeholders for the Catalogue and
#   Provenance module.  Full implementations will connect to the
#   internal layer manifest once the manifest data structure is
#   finalised.  Current stubs validate inputs and return
#   informative "not yet implemented" errors so downstream code
#   fails loudly rather than silently.
#
#   Planned improvements:
#   - Define manifest data structure (data.frame / YAML / JSON).
#   - Implement list_layers() to read and print the manifest.
#   - Implement find_layer() to filter by theme, year, extent,
#     resolution, and CRS.
#   - Implement get_layer() to retrieve a SpatRaster or path.
#   - Implement layer_meta() to return provenance metadata.
# ---

# 1. list_layers -----------------------------------------------

#' List catalogue contents
#'
#' Returns a summary of all spatial layers registered in the
#' sciSpatialR catalogue manifest.
#'
#' @param theme Optional character; filter by theme (e.g.,
#'   `"landcover"`, `"climate"`).
#' @param verbose Logical; if `TRUE` (default), prints the
#'   catalogue to the console.
#'
#' @return A `data.frame` (invisibly) with one row per layer.
#'
#' @note This function is a placeholder.  The catalogue manifest
#'   has not yet been implemented.
#'
#' @examples
#' \dontrun{
#' list_layers()
#' list_layers(theme = "landcover")
#' }
#'
#' @export
list_layers <- function(theme = NULL,
                         verbose = TRUE) {
  .not_yet_implemented("list_layers")
}


# 2. find_layer -----------------------------------------------

#' Filter catalogue manifest by theme, year, extent, resolution,
#' or CRS
#'
#' Searches the sciSpatialR catalogue manifest and returns all
#' layers that match the supplied filter criteria.
#'
#' @param theme Optional character; theme keyword to match.
#' @param year Optional integer or integer range of length 2;
#'   vintage year(s) to match.
#' @param extent Optional numeric vector `c(xmin, xmax, ymin,
#'   ymax)` in decimal degrees; layers whose extent overlaps are
#'   returned.
#' @param resolution Optional numeric; target resolution (CRS
#'   units) to match.
#' @param crs Optional character; EPSG code or WKT string to
#'   match.
#'
#' @return A `data.frame` (invisibly) with one row per matching
#'   layer.
#'
#' @note This function is a placeholder.  The catalogue manifest
#'   has not yet been implemented.
#'
#' @examples
#' \dontrun{
#' find_layer(theme = "landcover", year = 2020)
#' }
#'
#' @export
find_layer <- function(theme      = NULL,
                        year       = NULL,
                        extent     = NULL,
                        resolution = NULL,
                        crs        = NULL) {
  .not_yet_implemented("find_layer")
}


# 3. get_layer ------------------------------------------------

#' Return a SpatRaster or file path from a canonical layer name
#'
#' Looks up `name` in the sciSpatialR catalogue manifest and
#' returns the corresponding `SpatRaster` (default) or the local
#' file path.
#'
#' @param name Character; canonical layer name as listed by
#'   [list_layers()].
#' @param return_path Logical; if `TRUE`, return the local file
#'   path instead of loading the raster.  Default `FALSE`.
#'
#' @return A `SpatRaster`, or a character file path if
#'   `return_path = TRUE`.
#'
#' @note This function is a placeholder.  The catalogue manifest
#'   has not yet been implemented.
#'
#' @examples
#' \dontrun{
#' r <- get_layer("abmi_landcover_2020")
#' p <- get_layer("abmi_landcover_2020", return_path = TRUE)
#' }
#'
#' @export
get_layer <- function(name,
                       return_path = FALSE) {
  if (!is.character(name) || length(name) != 1 || !nzchar(name)) {
    stop("`name` must be a single non-empty character string.")
  }
  .not_yet_implemented("get_layer")
}


# 4. layer_meta -----------------------------------------------

#' Return provenance metadata for a catalogue layer
#'
#' Retrieves source, vintage, licence, caveats, and contact
#' information for a layer registered in the sciSpatialR
#' catalogue.
#'
#' @param name Character; canonical layer name as listed by
#'   [list_layers()].
#' @param print Logical; if `TRUE` (default), the metadata is
#'   printed to the console.
#'
#' @return A named `list` with elements `source`, `vintage`,
#'   `licence`, `caveats`, and `contact` (invisibly).
#'
#' @note This function is a placeholder.  The catalogue manifest
#'   has not yet been implemented.
#'
#' @examples
#' \dontrun{
#' layer_meta("abmi_landcover_2020")
#' }
#'
#' @export
layer_meta <- function(name,
                        print = TRUE) {
  if (!is.character(name) || length(name) != 1 || !nzchar(name)) {
    stop("`name` must be a single non-empty character string.")
  }
  .not_yet_implemented("layer_meta")
}


# Internal helper -----------------------------------------------

#' Emit a consistent "not yet implemented" error
#' @noRd
.not_yet_implemented <- function(fn_name) {
  stop(
    fn_name, "() is not yet implemented. ",
    "The catalogue manifest for sciSpatialR is under development. ",
    "Check back in a future package version.",
    call. = FALSE
  )
}

# End of script ----
