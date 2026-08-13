# ---
# title: catalogue — build and query the spatial data catalogue
# author: Brendan Casey
# created: 2026-08-12
# inputs:
#   the spatial data share, default
#   \\ABMI-DATA2\science\spatial_data, organised by ISO 19115 topic
#   category with a readme beside each dataset — see
#   github.com/bgcasey/geospatial_catalog_and_management_guide
# outputs:
#   catalogue manifest data.frames, file inventories, SpatRaster or
#   SpatVector objects, and file paths
# notes:
#   The catalogue is the directory tree itself: these functions
#   scan the share, parse every dataset readme (metadata.R), and
#   assemble a manifest.  Nothing is written back to the share and
#   no separate manifest file is maintained, so the catalogue can
#   never drift from the data it describes — documenting a dataset
#   means editing its readme.
#
#   A folder is catalogued as a layer when it holds a readme with a
#   `Title` field.  Theme folders carry a different, short readme
#   (`Category`/`Description`/`Examples`), which is why those are
#   read by list_themes() rather than catalogued as layers.  Dataset
#   folders sit at whatever depth the theme needs
#   (`elevation/fab_dem`, `biota/vegetation/grassland_inventory`),
#   so the scan is depth-agnostic and derives `theme` and
#   `sub_theme` from the path.
#
#   Scanning a network share is slow, so the manifest is cached per
#   root for the session; pass `refresh = TRUE` after the share
#   changes.
#
#   Planned improvements:
#   - Read CRS and true extent from file headers with terra to fill
#     the gaps the metadata template leaves.
# ---


# 1. Constants and cache ----------------------------------------

# Default location of the science spatial data share.
.default_root <- "//ABMI-DATA2/science/spatial_data"

# File extensions treated as spatial data, split by the terra
# constructor needed to read them.
.raster_exts <- c(
  "tif", "tiff", "img", "nc", "grd", "asc", "bil", "vrt", "hdf",
  "h5", "jp2", "bsq", "dem"
)
.vector_exts <- c(
  "shp", "gpkg", "geojson", "kml", "kmz", "gml", "sqlite", "gdb"
)

# Manifests are cached per root; scanning the share is the slow
# step and the tree rarely changes within a session.
.catalogue_cache <- new.env(parent = emptyenv())


# 2. spatial_root -----------------------------------------------

#' Location of the spatial data share
#'
#' Returns the root directory the catalogue is built from.  The
#' default is the ABMI science share; override it with the
#' `sciSpatialR.spatial_root` option or the
#' `SCISPATIALR_SPATIAL_ROOT` environment variable, which is how
#' you point the catalogue at a mirror, a mapped drive letter, or a
#' local copy.
#'
#' @param check Logical; if `TRUE` (default), error when the
#'   directory is unreachable.
#'
#' @return A length-one character path.
#'
#' @examples
#' \dontrun{
#' spatial_root()
#'
#' options(sciSpatialR.spatial_root = "D:/spatial_data")
#' spatial_root()
#' }
#'
#' @export
spatial_root <- function(check = TRUE) {
  root <- getOption("sciSpatialR.spatial_root")
  if (is.null(root) || !nzchar(root)) {
    root <- Sys.getenv("SCISPATIALR_SPATIAL_ROOT")
  }
  if (!nzchar(root)) {
    root <- .default_root
  }
  root <- .norm_path(root)

  if (isTRUE(check) && !dir.exists(root)) {
    stop(
      "Spatial data root not reachable: ", root, "\n",
      "Connect to the share, or set a different root with ",
      "options(sciSpatialR.spatial_root = \"...\") or the ",
      "SCISPATIALR_SPATIAL_ROOT environment variable.",
      call. = FALSE
    )
  }
  root
}


#' Normalise a path to forward slashes with no trailing separator
#' @noRd
.norm_path <- function(x) {
  x <- gsub("\\\\", "/", x)
  sub("(?<=.)/+$", "", x, perl = TRUE)
}


#' Parent directory of a normalised path
#'
#' `dirname()` renders a UNC prefix back as `\\server`, which then
#' fails to match the forward-slash paths `list.files()` returns, so
#' the separator is trimmed textually instead.
#'
#' @noRd
.parent_dir <- function(x) {
  sub("/[^/]*$", "", .norm_path(x))
}


# 3. build_catalogue --------------------------------------------

#' Build the catalogue manifest by scanning the data share
#'
#' Walks `root`, parses every dataset readme it finds, and returns
#' one row per documented layer.  Folders holding spatial data with
#' no readme are recorded separately in the `undocumented`
#' attribute and reported by [check_metadata()].
#'
#' The result is cached per root for the session, so [list_layers()]
#' and friends only pay for the scan once.
#'
#' @param root Character; directory to scan.  Defaults to
#'   [spatial_root()].
#' @param files Logical; if `TRUE` (default), inventory each layer's
#'   files to populate `n_files`, `size_mb`, and `data_type`.  Set
#'   `FALSE` for a faster, metadata-only scan.
#' @param refresh Logical; if `TRUE`, rescan even when a cached
#'   manifest exists.  Default `FALSE`.
#' @param quiet Logical; if `TRUE`, suppress progress messages.
#'   Default `FALSE`.
#'
#' @return A `data.frame` with one row per layer: `id` (path
#'   relative to `root`), `name`, `theme`, `sub_theme`, the
#'   template metadata fields (see [as_metadata_row()]), `n_files`,
#'   `size_mb`, `data_type`, `path`, and `readme`.  Carries the
#'   scan `root` and the `undocumented` folders as attributes.
#'
#' @seealso [list_layers()] to query the manifest, [check_metadata()]
#'   to audit it.
#'
#' @examples
#' \dontrun{
#' cat_df <- build_catalogue()
#' nrow(cat_df)
#' build_catalogue(refresh = TRUE, files = FALSE)
#' }
#'
#' @export
build_catalogue <- function(root    = spatial_root(),
                            files   = TRUE,
                            refresh = FALSE,
                            quiet   = FALSE) {
  root <- .norm_path(root)
  key  <- paste0(root, "|", isTRUE(files))

  if (!isTRUE(refresh) && !is.null(.catalogue_cache[[key]])) {
    return(.catalogue_cache[[key]])
  }
  if (!dir.exists(root)) {
    stop("Spatial data root not reachable: ", root, call. = FALSE)
  }

  if (!isTRUE(quiet)) {
    message("Scanning ", root, " ...")
  }
  # One recursive listing feeds readme discovery, the per-layer file
  # inventory, and the undocumented-folder check.  Walking a network
  # share three times is the slow way to do this.
  all_files <- .norm_path(
    list.files(root, recursive = TRUE, full.names = TRUE)
  )
  readmes <- all_files[
    grepl(.readme_pattern, basename(all_files), ignore.case = TRUE)
  ]

  layers <- list()
  for (readme in readmes) {
    md <- tryCatch(read_metadata(readme),
                   error = function(e) conditionMessage(e))
    if (is.character(md)) {
      # Carry the reason: a readme dropped here is a layer missing
      # from the catalogue, and the path alone does not say why.
      warning("Could not read metadata: ", readme, " (", md, ")",
              call. = FALSE)
      next
    }
    # Theme-level readmes are a different, shorter form and are
    # handled by list_themes() instead.
    if (!.is_dataset_readme(md)) {
      next
    }
    layers[[length(layers) + 1]] <- .layer_row(md, readme, root)
  }

  out <- if (length(layers)) {
    do.call(rbind, layers)
  } else {
    .empty_manifest()
  }

  if (nrow(out) && isTRUE(files)) {
    inv <- .inventory(out$path, out$path, all_files)
    out$n_files   <- inv$n_files
    out$size_mb   <- inv$size_mb
    out$data_type <- inv$data_type
  }

  if (nrow(out)) {
    out <- out[order(out$id), , drop = FALSE]
    rownames(out) <- NULL
  }

  attr(out, "root")         <- root
  attr(out, "scanned")      <- Sys.time()
  attr(out, "undocumented") <- .undocumented(root, out$path,
                                             all_files)

  .catalogue_cache[[key]] <- out
  if (!isTRUE(quiet)) {
    message("Catalogued ", nrow(out), " layers.")
  }
  out
}


#' Assemble one manifest row from parsed metadata
#' @noRd
.layer_row <- function(md, readme, root) {
  dir <- .parent_dir(readme)
  id  <- .relative_to(dir, root)
  bits <- strsplit(id, "/", fixed = TRUE)[[1]]

  cbind(
    data.frame(
      id        = id,
      name      = basename(dir),
      theme     = bits[1],
      sub_theme = if (length(bits) > 2) bits[2] else NA_character_,
      stringsAsFactors = FALSE
    ),
    as_metadata_row(md),
    data.frame(
      n_files   = NA_integer_,
      size_mb   = NA_real_,
      data_type = NA_character_,
      path      = dir,
      readme    = readme,
      stringsAsFactors = FALSE
    )
  )
}


#' Manifest with the right columns and no rows
#' @noRd
.empty_manifest <- function() {
  md <- structure(
    stats::setNames(
      as.list(rep(NA_character_, length(.meta_field_map))),
      names(.meta_field_map)
    ),
    path = NA_character_, sections = character(0),
    class = c("sciSpatial_metadata", "list")
  )
  template <- .layer_row(md, "x/readme.txt", "x")
  template[0, , drop = FALSE]
}


#' Express a path relative to root, using forward slashes
#' @noRd
.relative_to <- function(path, root) {
  rel <- sub(paste0("^", .escape(.norm_path(root)), "/?"), "",
             .norm_path(path))
  if (nzchar(rel)) rel else "."
}


#' Escape a string for use as a literal in a regex
#' @noRd
.escape <- function(x) {
  gsub("([.^$*+?()\\[\\]{}|\\\\])", "\\\\\\1", x, perl = TRUE)
}


# 4. File inventory ---------------------------------------------

#' Count files, total size, and data type for each layer folder
#'
#' Files under a nested layer folder are attributed to that nested
#' layer only, so a parent dataset is not credited with its
#' children's contents.
#'
#' @param dirs Character; layer directories to inventory.
#' @param all_dirs Character; every layer directory, used to detect
#'   nesting.
#' @param all_files Character; every file under the scan root.
#' @return A list of three vectors, one element per directory.
#' @noRd
.inventory <- function(dirs, all_dirs, all_files = NULL) {
  n_files   <- integer(length(dirs))
  size_mb   <- numeric(length(dirs))
  data_type <- character(length(dirs))

  for (i in seq_along(dirs)) {
    files <- .layer_file_paths(dirs[i], all_dirs, all_files)
    exts  <- tolower(tools::file_ext(files))
    keep  <- exts %in% c(.raster_exts, .vector_exts)

    n_files[i]   <- sum(keep)
    size_mb[i]   <- round(
      sum(file.size(files), na.rm = TRUE) / 1024^2, 1
    )
    data_type[i] <- .classify(exts[keep])
  }
  list(n_files = n_files, size_mb = size_mb, data_type = data_type)
}


#' List the files belonging to one layer folder
#'
#' @param dir Character; the layer directory.
#' @param all_dirs Character; every layer directory in the scan.
#' @param all_files Optional character; a listing of the whole scan
#'   root to filter, avoiding a fresh trip to the share.
#' @return A character vector of file paths.
#' @noRd
.layer_file_paths <- function(dir, all_dirs, all_files = NULL) {
  files <- if (is.null(all_files)) {
    .norm_path(list.files(dir, recursive = TRUE, full.names = TRUE))
  } else {
    all_files[startsWith(all_files, paste0(dir, "/"))]
  }
  if (!length(files)) {
    return(files)
  }
  nested <- setdiff(
    all_dirs[startsWith(all_dirs, paste0(dir, "/"))], dir
  )
  for (child in nested) {
    files <- files[!startsWith(files, paste0(child, "/"))]
  }
  files
}


#' Label a set of file extensions as raster, vector, or both
#' @noRd
.classify <- function(exts) {
  has_r <- any(exts %in% .raster_exts)
  has_v <- any(exts %in% .vector_exts)
  if (has_r && has_v) {
    "mixed"
  } else if (has_r) {
    "raster"
  } else if (has_v) {
    "vector"
  } else {
    NA_character_
  }
}


#' Find folders holding spatial data but no readme
#'
#' @param root Character; the scan root.
#' @param layer_dirs Character; documented layer directories.
#' @param all_files Character; every file under the scan root.
#' @return A `data.frame` of undocumented folders.
#' @noRd
.undocumented <- function(root, layer_dirs, all_files) {
  files <- all_files
  exts  <- tolower(tools::file_ext(files))
  files <- files[exts %in% c(.raster_exts, .vector_exts)]

  dirs <- unique(.parent_dir(files))
  # Drop anything already covered by a documented layer, including
  # subfolders of one.
  covered <- vapply(
    dirs,
    function(d) {
      any(d == layer_dirs | startsWith(d, paste0(layer_dirs, "/")))
    },
    logical(1)
  )
  dirs <- dirs[!covered]

  if (!length(dirs)) {
    return(data.frame(
      id = character(0), name = character(0),
      theme = character(0), path = character(0),
      stringsAsFactors = FALSE
    ))
  }
  ids <- vapply(dirs, .relative_to, character(1), root = root)
  data.frame(
    id    = unname(ids),
    name  = basename(dirs),
    theme = vapply(
      strsplit(unname(ids), "/", fixed = TRUE),
      function(x) x[1], character(1)
    ),
    path  = dirs,
    stringsAsFactors = FALSE
  )
}


# 5. list_layers ------------------------------------------------

#' List catalogue contents
#'
#' Returns the catalogue manifest, optionally restricted to one or
#' more themes.
#'
#' @param theme Optional character; theme folder name(s) to keep,
#'   e.g. `"elevation"` or `"biota"`.  Matched case-insensitively.
#' @param verbose Logical; if `TRUE` (default), print a short
#'   summary of the matching layers.
#' @param ... Passed to [build_catalogue()], e.g. `root`,
#'   `refresh`, or `files`.
#'
#' @return A `data.frame` with one row per layer, invisibly when
#'   `verbose = TRUE`.
#'
#' @seealso [find_layer()] for attribute filters, [layer_meta()]
#'   for a single layer's full metadata.
#'
#' @examples
#' \dontrun{
#' list_layers()
#' elevation <- list_layers(theme = "elevation")
#' }
#'
#' @export
list_layers <- function(theme = NULL, verbose = TRUE, ...) {
  out <- build_catalogue(quiet = TRUE, ...)

  if (!is.null(theme)) {
    if (!is.character(theme)) {
      stop("`theme` must be a character vector.", call. = FALSE)
    }
    keep <- tolower(out$theme) %in% tolower(theme)
    out  <- .subset_manifest(out, keep)
  }

  if (isTRUE(verbose)) {
    .print_manifest(out)
    return(invisible(out))
  }
  out
}


#' Subset a manifest while preserving its attributes
#' @noRd
.subset_manifest <- function(x, keep) {
  keep <- keep & !is.na(keep)
  atts <- attributes(x)[c("root", "scanned", "undocumented")]
  out  <- x[keep, , drop = FALSE]
  rownames(out) <- NULL

  undoc <- atts$undocumented
  if (!is.null(undoc) && nrow(undoc)) {
    atts$undocumented <- undoc[undoc$theme %in% x$theme[keep], ,
                               drop = FALSE]
  }
  for (nm in names(atts)) {
    attr(out, nm) <- atts[[nm]]
  }
  out
}


#' Count with a singular or plural noun
#'
#' Keeps summary lines reading "1 theme" rather than "1 themes".
#' @noRd
.plural <- function(n, word) {
  paste0(n, " ", word, if (identical(as.integer(n), 1L)) "" else "s")
}


#' Print a compact view of a manifest
#' @noRd
.print_manifest <- function(x) {
  if (!nrow(x)) {
    cat("No layers matched.\n")
    return(invisible(NULL))
  }
  cols <- c("id", "title", "year", "resolution_m", "data_type")
  cols <- cols[cols %in% names(x)]
  view <- x[, cols, drop = FALSE]
  view$title <- vapply(view$title, .truncate, character(1), n = 45)

  cat(sprintf(
    "%s in %s\n\n",
    .plural(nrow(x), "layer"),
    .plural(length(unique(x$theme)), "theme")
  ))
  print(view, row.names = FALSE, right = FALSE)
  invisible(NULL)
}


# 6. find_layer -------------------------------------------------

#' Filter the catalogue by theme, keyword, year, extent, or
#' resolution
#'
#' Applies each supplied filter in turn and returns the layers that
#' satisfy all of them.  Layers whose readme leaves a filtered
#' field blank cannot be tested, so they are excluded — a filter
#' narrows to layers *known* to match, and [check_metadata()] shows
#' which readmes are keeping a layer out.
#'
#' @param theme Optional character; theme folder name(s).
#' @param keyword Optional character; matched case-insensitively
#'   against title, keywords, abstract, and layer name.  Multiple
#'   keywords match layers containing any of them.
#' @param year Optional numeric; a single year or a `c(min, max)`
#'   range, tested against the layer's vintage.
#' @param extent Optional numeric `c(xmin, xmax, ymin, ymax)` in
#'   decimal degrees; keeps layers whose bounding box overlaps it.
#' @param resolution Optional numeric; a single resolution in
#'   metres or a `c(min, max)` range.
#' @param crs Optional character; matched against the layer's CRS
#'   field.  The metadata template has no CRS element, so this is
#'   `NA` for most layers — see the note in `R/metadata.R`.
#' @param verbose Logical; if `TRUE` (default), print the matches.
#' @param ... Passed to [build_catalogue()].
#'
#' @return A `data.frame` of matching layers, invisibly when
#'   `verbose = TRUE`.
#'
#' @seealso [list_layers()], [get_layer()].
#'
#' @examples
#' \dontrun{
#' find_layer(keyword = "elevation")
#' find_layer(year = c(2015, 2024), resolution = c(0, 100))
#' find_layer(extent = c(-120, -110, 49, 60))
#' }
#'
#' @export
find_layer <- function(theme      = NULL,
                       keyword    = NULL,
                       year       = NULL,
                       extent     = NULL,
                       resolution = NULL,
                       crs        = NULL,
                       verbose    = TRUE,
                       ...) {
  out  <- build_catalogue(quiet = TRUE, ...)
  keep <- rep(TRUE, nrow(out))

  if (!is.null(theme)) {
    keep <- keep & tolower(out$theme) %in% tolower(theme)
  }

  if (!is.null(keyword)) {
    haystack <- tolower(paste(
      out$name, out$title, out$keywords, out$topic_category,
      out$abstract
    ))
    hit <- rep(FALSE, nrow(out))
    for (k in keyword) {
      hit <- hit | grepl(tolower(k), haystack, fixed = TRUE)
    }
    keep <- keep & hit
  }

  if (!is.null(year)) {
    rng  <- .as_range(year, "year")
    keep <- keep & .in_range(out$year, rng)
  }

  if (!is.null(resolution)) {
    rng  <- .as_range(resolution, "resolution")
    keep <- keep & .in_range(out$resolution_m, rng)
  }

  if (!is.null(extent)) {
    if (!is.numeric(extent) || length(extent) != 4) {
      stop("`extent` must be numeric c(xmin, xmax, ymin, ymax).",
           call. = FALSE)
    }
    overlap <- !(out$xmax < extent[1] | out$xmin > extent[2] |
                   out$ymax < extent[3] | out$ymin > extent[4])
    keep <- keep & !is.na(overlap) & overlap
  }

  if (!is.null(crs)) {
    keep <- keep & !is.na(out$crs) &
      grepl(tolower(crs), tolower(out$crs), fixed = TRUE)
  }

  out <- .subset_manifest(out, keep)
  if (isTRUE(verbose)) {
    .print_manifest(out)
    return(invisible(out))
  }
  out
}


#' Coerce a filter argument to a c(min, max) range
#' @noRd
.as_range <- function(x, arg) {
  if (!is.numeric(x) || !length(x) %in% c(1, 2)) {
    stop("`", arg, "` must be a numeric of length 1 or 2.",
         call. = FALSE)
  }
  if (length(x) == 1) c(x, x) else sort(x)
}


#' Test values against a range, treating NA as no match
#' @noRd
.in_range <- function(x, rng) {
  !is.na(x) & x >= rng[1] & x <= rng[2]
}


# 7. get_layer and layer_files ----------------------------------

#' Load a catalogued layer, or return its path
#'
#' Looks `name` up in the catalogue and reads the layer's data file
#' with terra.  Rasters are returned as a `SpatRaster`, vectors as a
#' `SpatVector`.  When a folder holds more than one data file, pass
#' `file` to choose; otherwise the ambiguity is reported along with
#' the available files.
#'
#' @param name Character; a layer `name` (`"fab_dem"`) or catalogue
#'   `id` (`"elevation/fab_dem"`) as listed by [list_layers()].
#' @param file Optional character; a file name or regular
#'   expression selecting one file within the layer folder.
#' @param return_path Logical; if `TRUE`, return the file path
#'   instead of reading the data.  Default `FALSE`.
#' @param ... Passed to [build_catalogue()].
#'
#' @return A `SpatRaster`, a `SpatVector`, or a character path.
#'
#' @seealso [layer_files()] to see what a layer folder holds,
#'   [layer_meta()] for its metadata.
#'
#' @examples
#' \dontrun{
#' r <- get_layer("topographic_wetness_index")
#' p <- get_layer("fab_dem", return_path = TRUE)
#' g <- get_layer("grassland_inventory", file = "alberta")
#' }
#'
#' @export
get_layer <- function(name,
                      file        = NULL,
                      return_path = FALSE,
                      ...) {
  row   <- .resolve_layer(name, ...)
  paths <- layer_files(name, pattern = file, ...)

  if (!length(paths)) {
    stop("Layer '", row$id, "' has no readable spatial data file ",
         "in ", row$path, call. = FALSE)
  }
  if (length(paths) > 1) {
    stop(
      "Layer '", row$id, "' holds ", length(paths), " data files. ",
      "Select one with `file =`:\n  ",
      paste(basename(paths), collapse = "\n  "),
      call. = FALSE
    )
  }

  if (isTRUE(return_path)) {
    return(paths)
  }
  if (tolower(tools::file_ext(paths)) %in% .vector_exts) {
    terra::vect(paths)
  } else {
    terra::rast(paths)
  }
}


#' List the spatial data files in a layer folder
#'
#' @param name Character; layer `name` or catalogue `id`.
#' @param pattern Optional character; a file name or regular
#'   expression to filter by, matched case-insensitively.
#' @param all Logical; if `TRUE`, return every file in the folder
#'   rather than only recognised spatial formats.  Default `FALSE`.
#' @param ... Passed to [build_catalogue()].
#'
#' @return A character vector of file paths.
#'
#' @seealso [get_layer()].
#'
#' @examples
#' \dontrun{
#' layer_files("grassland_inventory")
#' layer_files("grassland_inventory", all = TRUE)
#' }
#'
#' @export
layer_files <- function(name, pattern = NULL, all = FALSE, ...) {
  cat_df <- build_catalogue(quiet = TRUE, ...)
  row    <- .resolve_layer(name, .catalogue = cat_df)

  files <- .layer_file_paths(row$path, cat_df$path)
  if (!isTRUE(all)) {
    exts  <- tolower(tools::file_ext(files))
    files <- files[exts %in% c(.raster_exts, .vector_exts)]
    # Sidecar shapefile parts are not separate datasets.
    files <- files[!grepl("\\.(shx|dbf|prj|cpg|sbn|sbx)$", files,
                          ignore.case = TRUE)]
  }
  if (!is.null(pattern)) {
    files <- files[grepl(pattern, basename(files),
                         ignore.case = TRUE)]
  }
  sort(files)
}


#' Resolve a layer name or id to a single manifest row
#'
#' Tries an exact `id` match, then an exact `name` match, then a
#' case-insensitive match, so short names work while ids stay
#' available to disambiguate.
#'
#' @param name Character; layer name or catalogue id.
#' @param .catalogue Optional manifest to search, to avoid
#'   rebuilding it.
#' @param ... Passed to [build_catalogue()].
#' @return A one-row `data.frame`.
#' @noRd
.resolve_layer <- function(name, .catalogue = NULL, ...) {
  if (!is.character(name) || length(name) != 1 || !nzchar(name)) {
    stop("`name` must be a single non-empty character string.",
         call. = FALSE)
  }
  cat_df <- if (is.null(.catalogue)) {
    build_catalogue(quiet = TRUE, ...)
  } else {
    .catalogue
  }

  key  <- .norm_path(name)
  hits <- which(cat_df$id == key)
  if (!length(hits)) hits <- which(cat_df$name == key)
  if (!length(hits)) {
    hits <- which(tolower(cat_df$id) == tolower(key) |
                    tolower(cat_df$name) == tolower(key))
  }

  if (!length(hits)) {
    near <- cat_df$id[grepl(key, cat_df$id, ignore.case = TRUE)]
    stop(
      "No catalogued layer named '", name, "'.",
      if (length(near)) {
        paste0("\nDid you mean:\n  ",
               paste(utils::head(near, 5), collapse = "\n  "))
      } else {
        " Run list_layers() to see what is catalogued."
      },
      call. = FALSE
    )
  }
  if (length(hits) > 1) {
    stop(
      "'", name, "' matches ", length(hits), " layers. Use the ",
      "full id:\n  ",
      paste(cat_df$id[hits], collapse = "\n  "),
      call. = FALSE
    )
  }
  cat_df[hits, , drop = FALSE]
}


# 8. list_themes ------------------------------------------------

#' List the catalogue's themes
#'
#' Reads the short `Category`/`Description`/`Examples` readme in
#' each top-level theme folder and reports it alongside the number
#' of layers catalogued under it.  Themes follow the ISO 19115
#' topic categories used by the data management guide.
#'
#' @param ... Passed to [build_catalogue()], e.g. `root` or
#'   `refresh`.
#'
#' @return A `data.frame` with `theme`, `description`, `examples`,
#'   and `n_layers`, classed `sciSpatial_themes` so that printing it
#'   gives the same compact view [list_layers()] does.  The full
#'   table, `examples` included, is there for subsetting.
#'
#' @seealso [list_layers()].
#'
#' @examples
#' \dontrun{
#' list_themes()
#' }
#'
#' @export
list_themes <- function(...) {
  cat_df <- build_catalogue(quiet = TRUE, ...)
  root   <- attr(cat_df, "root")

  dirs <- list.dirs(root, recursive = FALSE, full.names = TRUE)
  dirs <- .norm_path(dirs)

  rows <- lapply(dirs, function(dir) {
    readme <- list.files(
      dir, pattern = .readme_pattern, full.names = TRUE,
      ignore.case = TRUE
    )
    md <- if (length(readme)) {
      tryCatch(read_metadata(readme[1]), error = function(e) NULL)
    }
    theme <- basename(dir)
    data.frame(
      theme       = theme,
      description = .theme_field(md, "description"),
      examples    = .theme_field(md, "examples"),
      n_layers    = sum(cat_df$theme == theme),
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  out <- out[order(-out$n_layers, out$theme), , drop = FALSE]
  rownames(out) <- NULL
  structure(out, class = c("sciSpatial_themes", "data.frame"))
}


#' Print a compact view of the themes
#'
#' Drops `examples`, which is too long to tabulate, and truncates
#' the description, matching the manifest printer.
#'
#' @param x A `sciSpatial_themes` object.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.sciSpatial_themes <- function(x, ...) {
  if (!nrow(x)) {
    cat("No themes found.\n")
    return(invisible(x))
  }
  view <- data.frame(
    theme       = x$theme,
    description = vapply(x$description, .truncate, character(1),
                         n = 50, USE.NAMES = FALSE),
    n_layers    = x$n_layers,
    stringsAsFactors = FALSE
  )

  cat(sprintf(
    "%s, %s catalogued\n\n",
    .plural(nrow(x), "theme"),
    .plural(sum(x$n_layers), "layer")
  ))
  print(view, row.names = FALSE, right = FALSE)
  invisible(x)
}


#' Pull one field from a theme readme, tolerating a missing file
#' @noRd
.theme_field <- function(md, field) {
  if (is.null(md) || is.null(md[[field]])) {
    return(NA_character_)
  }
  as.character(md[[field]])
}

# End of script ----
