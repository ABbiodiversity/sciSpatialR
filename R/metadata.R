# ---
# title: metadata — read and parse spatial dataset readme files
# author: Brendan Casey
# created: 2026-08-12
# inputs:
#   readme.txt / readme.md files stored beside each spatial dataset
#   on the science share, written to the metadata template in
#   github.com/bgcasey/geospatial_catalog_and_management_guide
# outputs:
#   named metadata lists, one-row metadata data.frames, and
#   metadata completeness reports
# notes:
#   Every dataset folder on the share carries a readme written to
#   one template, so the readmes — not a separate database — are
#   the catalogue.  These functions turn that free text into
#   structured fields the catalogue functions in catalogue.R build
#   tables from.
#
#   The parser is deliberately forgiving because real readmes drift
#   from the template: values appear inline (`Title: X`) or on the
#   lines below the label, sub-fields are indented under a parent
#   (`Extent:` then `West Bounding Coordinate:`), some files add
#   sections the template never defined (`BAND INFORMATION`,
#   `LAYER INFORMATION`, `Version History`), and some carry
#   markdown emphasis or trailing double-spaces.  Anything shaped
#   like `Label: value` is captured, so extra fields survive
#   parsing even though only the template fields are promoted to
#   catalogue columns.
#
#   Unfilled template placeholders (`[Data Title]`) and the
#   template's own guidance text are treated as missing rather than
#   as data, so check_metadata() reports a copied-but-unedited
#   readme as incomplete instead of cataloguing the placeholder.
#
#   Planned improvements:
#   - The template has no CRS field, so `crs` is almost always NA.
#     Either add one to the template or read it from the file
#     headers with terra::crs().
# ---


# 1. Constants --------------------------------------------------

# Readme file names recognised on the share.  Some folders prefix
# the name with an underscore to sort it to the top of the folder.
.readme_pattern <- "^_?readme\\.(txt|md)$"

# Fields meant to hold one short value.  Several readmes follow
# `Title: ...` with an indented unlabelled blurb, and the template
# follows the bounding coordinates with a note about their units;
# folding either into the value corrupts a field that is meant to
# be short.  These fields therefore take a continuation line only
# when it is laid out as a wrap of the value — flush left, or
# indented to the column the value starts in — and not when it is
# an indented block of its own.  Long prose fields such as Abstract
# take any continuation, since there the risk runs the other way.
.meta_single_line <- c(
  "title", "doi", "data_language", "publication_date",
  "metadata_date", "start_date", "end_date", "size", "format_name",
  "west_bounding_coordinate", "east_bounding_coordinate",
  "north_bounding_coordinate", "south_bounding_coordinate",
  "name", "role", "email", "phone"
)

# Values that mean "no value" rather than a real value.
.meta_null_values <- c(
  "na", "n/a", "none", "not specified", "not applicable",
  "not provided", "not publicly provided", "unknown", "tbd",
  "to be determined", "-", "--"
)

# Template fields promoted to catalogue columns.  Each entry lists
# the parsed keys to try, in order, so a readme that renamed a
# field (e.g. "Spatial Resolution of this raster") still resolves.
.meta_field_map <- list(
  title              = "title",
  abstract           = "abstract",
  purpose            = "purpose",
  credits            = "credits",
  language           = c("data_language", "language"),
  topic_category     = "topic_category",
  keywords           = "keywords",
  resolution         = c(
    "spatial_resolution_of_this_raster",
    "spatial_resolution",
    "spatial_resolution_of_original_product"
  ),
  xmin               = c(
    "extent_west_bounding_coordinate",
    "west_bounding_coordinate"
  ),
  xmax               = c(
    "extent_east_bounding_coordinate",
    "east_bounding_coordinate"
  ),
  ymax               = c(
    "extent_north_bounding_coordinate",
    "north_bounding_coordinate"
  ),
  ymin               = c(
    "extent_south_bounding_coordinate",
    "south_bounding_coordinate"
  ),
  publication_date   = "publication_date",
  start_date         = c("temporal_extent_start_date", "start_date"),
  end_date           = c("temporal_extent_end_date", "end_date"),
  lineage            = "lineage",
  positional_accuracy = "positional_accuracy",
  use_constraints    = "use_constraints",
  access_constraints = "access_constraints",
  format             = c("format_name", "format"),
  size               = "size",
  online_resource    = c("online_resource", "url"),
  contact_name       = c("point_of_contact_name", "contact_name"),
  contact_role       = c("point_of_contact_role", "contact_role"),
  contact_email      = c("point_of_contact_email", "contact_email"),
  contact_phone      = c("point_of_contact_phone", "contact_phone"),
  metadata_date      = "metadata_date",
  citation           = c("data_citation", "citation"),
  doi                = "doi",
  # Not in the template; parsed when a readme happens to record it.
  crs                = c(
    "crs", "coordinate_reference_system", "projection", "epsg"
  )
)

# Fields a complete dataset readme is expected to fill in.  Used by
# check_metadata() to score completeness.
.meta_required <- c(
  "title", "abstract", "purpose", "credits", "topic_category",
  "keywords", "resolution", "xmin", "xmax", "ymin", "ymax",
  "publication_date", "lineage", "use_constraints",
  "access_constraints", "format", "contact_name", "contact_email",
  "metadata_date"
)


# 2. read_metadata ----------------------------------------------

#' Read a spatial metadata readme
#'
#' Parses one `readme.txt` or `readme.md` written to the ABMI
#' spatial metadata template into a named list of fields.  Field
#' labels are normalised to `snake_case` keys, so
#' `West Bounding Coordinate:` becomes `west_bounding_coordinate`
#' and sub-fields indented under a parent label are prefixed with
#' it (`extent_west_bounding_coordinate`).
#'
#' Every `Label: value` line is captured, including fields the
#' template does not define, so nothing in a readme is silently
#' dropped.  Unfilled template placeholders such as `[Data Title]`
#' and non-values such as `"Not Specified"` are returned as `NA`.
#'
#' @param path Character; path to a readme file.
#'
#' @return A named list of length-one character values with class
#'   `sciSpatial_metadata`, carrying the source `path` and the
#'   template `sections` found as attributes.  Fields defined in
#'   the template but absent from the file are returned as `NA`.
#'
#' @seealso [layer_meta()] to read metadata by layer name,
#'   [as_metadata_row()] to flatten it to a one-row `data.frame`,
#'   and [check_metadata()] to audit completeness.
#'
#' @examples
#' \dontrun{
#' md <- read_metadata(
#'   file.path(spatial_root(), "elevation", "fab_dem", "readme.txt")
#' )
#' md$title
#' md$extent_west_bounding_coordinate
#' }
#'
#' @export
read_metadata <- function(path) {
  if (!is.character(path) || length(path) != 1 || !nzchar(path)) {
    stop("`path` must be a single non-empty character string.",
         call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("Metadata file not found: ", path, call. = FALSE)
  }

  lines <- .read_text_lines(path)
  parsed <- .parse_metadata_lines(lines)

  # Promote the template fields so every metadata object has the
  # same shape, whether or not the readme filled each one in.
  out <- parsed$fields
  for (nm in names(.meta_field_map)) {
    if (is.null(out[[nm]])) {
      out[[nm]] <- .meta_pick(parsed$fields, .meta_field_map[[nm]])
    }
  }

  structure(
    out[unique(c(names(.meta_field_map), names(out)))],
    path       = path,
    sections   = parsed$sections,
    # Labels the file actually carried, before the template fields
    # were filled in as NA.  This is what distinguishes a dataset
    # readme from a theme readme, and an unedited template copy
    # from a file that never had the field at all.
    raw_fields = names(parsed$fields),
    class      = c("sciSpatial_metadata", "list")
  )
}


#' Read a text file as UTF-8 regardless of session encoding
#'
#' `readLines(path, encoding = "UTF-8")` only *labels* the strings it
#' returns; it does not decode them, and the read still passes
#' through `getOption("encoding")`.  In a session where that option
#' is set to `"UTF-8"` while the native encoding is a legacy code
#' page, the connection transcodes the file's UTF-8 bytes down to
#' that code page on the way in - an en dash becomes `0x96`, `±`
#' becomes `0xb1`, `β` best-fits to `0xdf` - and the result is
#' then mislabelled UTF-8.  Those strings are invalid UTF-8, so the
#' first regular expression the parser applies fails with "unable to
#' translate ... to a wide string" and the whole readme is dropped.
#'
#' Reading the bytes in binary mode and decoding them here bypasses
#' the session settings entirely, so a readme parses the same way for
#' every user.  Files that really are Windows-1252 (the other half of
#' what lands on the share) are converted rather than rejected.
#'
#' @param path Character; path to a text file.
#' @return Character vector of lines, marked UTF-8.
#' @noRd
.read_text_lines <- function(path) {
  con <- file(path, "rb")
  on.exit(close(con))
  bytes <- readBin(con, "raw", file.size(path))
  if (!length(bytes)) {
    return(character(0))
  }

  # A stray NUL would silently truncate the string.
  txt <- rawToChar(bytes[bytes != as.raw(0)])
  if (!validUTF8(txt)) {
    txt <- iconv(txt, from = "windows-1252", to = "UTF-8", sub = "?")
  }
  Encoding(txt) <- "UTF-8"

  # The byte read keeps any BOM, and readmes arrive with either line
  # ending, so both are handled before the parser sees a line.
  strsplit(sub("^﻿", "", txt), "\r\n|\n|\r")[[1]]
}


#' Test whether parsed metadata describes a dataset
#'
#' Dataset readmes follow the full metadata template; theme folders
#' carry a short `Category`/`Description`/`Examples` readme
#' instead.  A dataset readme copied but not yet filled in still
#' counts, so an undocumented dataset is catalogued and reported by
#' [check_metadata()] rather than disappearing.
#'
#' @param md A `sciSpatial_metadata` object.
#' @return `TRUE` for a dataset readme.
#' @noRd
.is_dataset_readme <- function(md) {
  raw <- attr(md, "raw_fields")
  if ("title" %in% raw) {
    return(TRUE)
  }
  if ("category" %in% raw) {
    return(FALSE)
  }
  sum(raw %in% .meta_dataset_keys) >= 3
}


# Labels that only appear in the dataset metadata template, used to
# recognise a dataset readme that omitted its Title.
.meta_dataset_keys <- c(
  "abstract", "purpose", "credits", "spatial_resolution",
  "publication_date", "lineage", "use_constraints",
  "access_constraints", "format_name", "metadata_date",
  "temporal_extent", "point_of_contact", "positional_accuracy"
)


# 3. Parser internals -------------------------------------------

#' Parse readme lines into fields and section names
#'
#' Walks the file once, tracking the current template section, the
#' current field (so wrapped values continue onto it), and the
#' current parent label (so indented sub-fields are namespaced).
#'
#' @param lines Character vector of file lines.
#' @return A list with `fields` (named list) and `sections`
#'   (character vector).
#' @noRd
.parse_metadata_lines <- function(lines) {
  lines <- sub("^﻿", "", lines)
  lines <- gsub("\t", "    ", lines, fixed = TRUE)

  fields   <- list()
  sections <- character(0)
  field    <- NULL   # key currently accepting continuation lines
  wrap_col <- NA     # column a wrap of that value must align to
  parent   <- NULL   # label whose indented children are namespaced
  section  <- NA_character_
  at_rule  <- FALSE  # previous line was a ==== banner

  for (line in lines) {
    # Banner rules delimit section headings.
    if (grepl("^\\s*[=_-]{3,}\\s*$", line)) {
      at_rule <- TRUE
      field   <- NULL
      parent  <- NULL
      next
    }

    if (!nzchar(trimws(line))) {
      next
    }

    # A heading is the shouted line sitting between two banners.
    heading <- trimws(line)
    if (at_rule &&
        grepl("^[A-Z0-9][A-Z0-9 &/()'.,-]*$", heading)) {
      section  <- heading
      sections <- c(sections, section)
      at_rule  <- FALSE
      next
    }
    at_rule <- FALSE

    parts <- .match_field_line(line)

    if (is.null(parts)) {
      # Continuation of the value started on an earlier line.
      if (!is.null(field) && .is_wrap(line, wrap_col)) {
        fields[[field]] <- .append_value(
          fields[[field]], .clean_value(line)
        )
      }
      next
    }

    key <- parts$key
    if (parts$indent > 0 && !is.null(parent)) {
      key <- paste0(parent, "_", key)
    }

    # Track the parent for the indented block that follows a bare
    # label such as `Extent:` or `Point of Contact:`.
    if (parts$indent == 0) {
      parent <- if (!nzchar(parts$value)) parts$key else NULL
    }

    # First value wins: repeated labels in ad hoc sections (a
    # `Description:` under each `Layer n:`) must not overwrite the
    # template field of the same name.
    if (!is.null(fields[[key]])) {
      field <- NULL
      next
    }

    if (.is_placeholder(parts$value)) {
      # An unedited template slot, and the guidance text under it
      # is not data either, so stop accepting continuations.
      fields[[key]] <- NA_character_
      field <- NULL
      next
    }

    fields[[key]] <- if (nzchar(parts$value)) parts$value else ""
    field <- key
    # A short field that already has its value only accepts a
    # continuation laid out as a wrap; everything else takes any.
    wrap_col <- if (nzchar(parts$value) &&
                    parts$key %in% .meta_single_line) {
      parts$value_col
    } else {
      NA
    }
  }

  fields <- lapply(fields, .finalise_value)
  list(fields = fields, sections = unique(sections))
}


#' Test whether a line opens a `Label: value` field
#'
#' Rejects prose and URLs that merely contain a colon, so a wrapped
#' `Online Resource:` value beginning `https://...` continues the
#' URL instead of starting a field named `https`.
#'
#' @param line Character; one line of a readme.
#' @return `NULL`, or a list with `indent`, `key`, and `value`.
#' @noRd
.match_field_line <- function(line) {
  # The first colon separates label from value; a later colon
  # belongs to the value (`Abstract: MERIT Hydro: a global map`).
  pos <- regexpr(":", line, fixed = TRUE)
  if (pos < 1) {
    return(NULL)
  }

  label  <- substr(line, 1, pos - 1)
  indent <- nchar(label) - nchar(sub("^\\s+", "", label))
  label  <- trimws(label)

  # A label is one short run of ordinary words.  Prose and
  # citations that happen to contain a colon fail this test, so
  # they stay attached to the field they are wrapping.
  if (!grepl("^[A-Za-z][A-Za-z0-9 _/&'().-]{0,58}$", label)) {
    return(NULL)
  }
  if (lengths(regmatches(label, gregexpr("\\S+", label))) > 6) {
    return(NULL)
  }
  # URL schemes: a wrapped `Online Resource:` value beginning
  # `https://` must continue the URL, not open a field.
  if (grepl("^(https?|ftp|file|s3|www)$", tolower(label))) {
    return(NULL)
  }

  raw  <- substring(line, pos + 1)
  gap  <- nchar(raw) - nchar(sub("^\\s+", "", raw))

  list(
    indent    = indent,
    key       = .norm_key(label),
    value     = .clean_value(raw),
    # Column the value starts in, which a hanging-indent wrap of
    # that value lines up with.
    value_col = pos + gap
  )
}


#' Test whether a line continues the previous value
#'
#' With `col` missing, any line continues.  With `col` set, only a
#' line laid out as a wrap does: flush left, or indented to the
#' column the value starts in.
#'
#' @param line Character; one line of a readme.
#' @param col Integer or `NA`; the value column to align to.
#' @return `TRUE` when the line should be appended.
#' @noRd
.is_wrap <- function(line, col) {
  if (is.na(col)) {
    return(TRUE)
  }
  indent <- nchar(line) - nchar(sub("^\\s+", "", line))
  indent == 0 || indent == col
}


#' Append a continuation line to the value it wraps
#'
#' Wrapping normally reflows to a space, but a URL split across
#' lines has no space in it, so rejoining one with a space would
#' break the link.
#'
#' @noRd
.append_value <- function(old, new) {
  if (grepl("^(https?|ftp)://", old) && !grepl("\\s", new)) {
    return(paste0(old, new))
  }
  .squish(paste(old, new))
}


#' Normalise a field label to a snake_case key
#' @noRd
.norm_key <- function(x) {
  x <- gsub("[^A-Za-z0-9]+", "_", tolower(trimws(x)))
  gsub("^_+|_+$", "", x)
}


#' Strip markdown emphasis, list bullets, and stray whitespace
#' @noRd
.clean_value <- function(x) {
  x <- gsub("\\*\\*|__", "", x)
  x <- sub("^\\s*[-*•]\\s+", "", x)
  .squish(x)
}


#' Collapse runs of whitespace and trim the ends
#' @noRd
.squish <- function(x) {
  trimws(gsub("\\s+", " ", x))
}


#' Test for an unfilled template placeholder, e.g. `[Data Title]`
#' @noRd
.is_placeholder <- function(x) {
  nzchar(x) && grepl("^\\[[^]]*\\]\\s*$", x)
}


#' Convert empty strings and non-values to NA
#' @noRd
.finalise_value <- function(x) {
  if (length(x) != 1 || is.na(x)) {
    return(NA_character_)
  }
  x <- .squish(x)
  if (!nzchar(x) || tolower(x) %in% .meta_null_values) {
    return(NA_character_)
  }
  x
}


#' Return the first non-missing value among candidate keys
#' @noRd
.meta_pick <- function(fields, keys) {
  for (key in keys) {
    val <- fields[[key]]
    if (!is.null(val) && !is.na(val)) {
      return(val)
    }
  }
  NA_character_
}


# 4. Value coercion ---------------------------------------------

#' Extract a resolution in metres from a free-text field
#'
#' Handles `"30 m"`, `"30 meters"`, `"1 km"`, and the parenthesised
#' metric equivalent in `"3.23 arc-seconds (~100 m at the
#' equator)"`, which is why the first number in the string is not
#' used on its own.
#'
#' @param x Character; the `Spatial Resolution` value.
#' @return A numeric resolution in metres, or `NA_real_`.
#' @noRd
.res_metres <- function(x) {
  if (is.na(x)) {
    return(NA_real_)
  }
  x <- tolower(x)
  m <- regmatches(
    x,
    regexec("([0-9]+(?:\\.[0-9]+)?)\\s*(k?m|kilomet|met)[a-z]*\\b", x)
  )[[1]]
  if (length(m) == 0) {
    return(NA_real_)
  }
  value <- as.numeric(m[2])
  if (grepl("^(km|kilomet)", m[3])) value * 1000 else value
}


#' Extract the leading signed number from a free-text field
#'
#' Bounding-coordinate lines are often followed by a trailing note
#' that the parser appends to the value, so only the leading number
#' is trusted.
#'
#' @noRd
.first_number <- function(x) {
  if (is.na(x)) {
    return(NA_real_)
  }
  m <- regmatches(x, regexpr("-?[0-9]+(\\.[0-9]+)?", x))
  if (length(m) == 0) NA_real_ else as.numeric(m)
}


#' Extract a four-digit year from a date or free-text field
#' @noRd
.year_of <- function(x) {
  if (is.na(x)) {
    return(NA_real_)
  }
  m <- regmatches(x, regexpr("(18|19|20)[0-9]{2}", x))
  if (length(m) == 0) NA_real_ else as.numeric(m)
}


#' Split a comma or semicolon separated field into a character
#' vector
#' @noRd
.split_list <- function(x) {
  if (is.na(x)) {
    return(character(0))
  }
  parts <- trimws(strsplit(x, "\\s*[,;]\\s*")[[1]])
  parts[nzchar(parts)]
}


# 5. as_metadata_row --------------------------------------------

#' Flatten parsed metadata to a one-row data.frame
#'
#' Selects the template fields, coerces the numeric ones
#' (resolution to metres, bounding coordinates to decimal degrees,
#' dates to years), and returns them in the column order the
#' catalogue manifest uses.
#'
#' @param md A `sciSpatial_metadata` object from [read_metadata()].
#'
#' @return A one-row `data.frame`.
#'
#' @seealso [read_metadata()], [build_catalogue()].
#'
#' @examples
#' \dontrun{
#' md <- read_metadata("readme.txt")
#' as_metadata_row(md)
#' }
#'
#' @export
as_metadata_row <- function(md) {
  if (!inherits(md, "sciSpatial_metadata")) {
    stop("`md` must be a `sciSpatial_metadata` object from ",
         "read_metadata().", call. = FALSE)
  }

  chr <- function(nm) {
    val <- md[[nm]]
    if (is.null(val)) NA_character_ else as.character(val)
  }

  end_date <- chr("end_date")
  # Year the layer represents: prefer the end of the temporal
  # extent, then its start, then the publication date.
  year <- .year_of(end_date)
  if (is.na(year)) year <- .year_of(chr("start_date"))
  if (is.na(year)) year <- .year_of(chr("publication_date"))

  data.frame(
    title              = chr("title"),
    topic_category     = chr("topic_category"),
    keywords           = chr("keywords"),
    year               = year,
    resolution         = chr("resolution"),
    resolution_m       = .res_metres(chr("resolution")),
    xmin               = .first_number(chr("xmin")),
    xmax               = .first_number(chr("xmax")),
    ymin               = .first_number(chr("ymin")),
    ymax               = .first_number(chr("ymax")),
    crs                = chr("crs"),
    publication_date   = chr("publication_date"),
    start_date         = chr("start_date"),
    end_date           = end_date,
    format             = chr("format"),
    size               = chr("size"),
    use_constraints    = chr("use_constraints"),
    access_constraints = chr("access_constraints"),
    contact_name       = chr("contact_name"),
    contact_email      = chr("contact_email"),
    doi                = chr("doi"),
    online_resource    = chr("online_resource"),
    metadata_date      = chr("metadata_date"),
    abstract           = chr("abstract"),
    purpose            = chr("purpose"),
    credits            = chr("credits"),
    lineage            = chr("lineage"),
    citation           = chr("citation"),
    stringsAsFactors   = FALSE
  )
}


# 6. layer_meta -------------------------------------------------

#' Return provenance metadata for a catalogue layer
#'
#' Reads the readme for `name` and returns its source, vintage,
#' licence, caveats, and contact information.
#'
#' @param name Character; layer name or catalogue id as listed by
#'   [list_layers()].
#' @param print Logical; if `TRUE` (default), print a formatted
#'   summary to the console.
#' @param ... Passed to [list_layers()], e.g. `root` or `refresh`.
#'
#' @return A `sciSpatial_metadata` list, invisibly.
#'
#' @seealso [read_metadata()] to parse a readme by path,
#'   [get_layer()] to load the data the metadata describes.
#'
#' @examples
#' \dontrun{
#' layer_meta("fab_dem")
#' md <- layer_meta("fab_dem", print = FALSE)
#' md$use_constraints
#' }
#'
#' @export
layer_meta <- function(name, print = TRUE, ...) {
  row <- .resolve_layer(name, ...)
  md  <- read_metadata(row$readme)
  if (isTRUE(print)) {
    print(md)
  }
  invisible(md)
}


#' Print a metadata object
#'
#' @param x A `sciSpatial_metadata` object.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.sciSpatial_metadata <- function(x, ...) {
  show <- c(
    Title = "title", Abstract = "abstract", Purpose = "purpose",
    Credits = "credits", Topic = "topic_category",
    Keywords = "keywords", Resolution = "resolution",
    Published = "publication_date", Start = "start_date",
    End = "end_date", Lineage = "lineage", Format = "format",
    Size = "size", Use = "use_constraints",
    Access = "access_constraints", Contact = "contact_name",
    Email = "contact_email", DOI = "doi",
    Source = "online_resource", Updated = "metadata_date"
  )
  cat("<sciSpatialR metadata>\n")
  cat("  file: ", attr(x, "path"), "\n", sep = "")
  width <- max(nchar(names(show)))
  for (i in seq_along(show)) {
    val <- x[[show[[i]]]]
    if (is.null(val) || is.na(val)) {
      next
    }
    cat(sprintf(
      "  %-*s  %s\n", width, names(show)[i], .truncate(val, 60)
    ))
  }
  invisible(x)
}


#' Shorten a string for console display
#' @noRd
.truncate <- function(x, n) {
  if (nchar(x) <= n) x else paste0(substr(x, 1, n - 1), "…")
}


# 7. check_metadata ---------------------------------------------

#' Audit metadata completeness across the catalogue
#'
#' Reports, for every catalogued layer, which required template
#' fields are missing — either absent from the readme or left as an
#' unedited placeholder — plus any data folder found with no readme
#' at all.  Use it to find the datasets that need documenting
#' before the catalogue can be trusted.
#'
#' @param theme Optional character; restrict the audit to one or
#'   more themes.
#' @param detail Logical; if `TRUE`, return one row per missing
#'   field instead of one row per layer.  Default `FALSE`.
#' @param ... Passed to [list_layers()], e.g. `root` or `refresh`.
#'
#' @return A `data.frame`.  With `detail = FALSE`, one row per
#'   layer with `id`, `name`, `theme`, `n_missing`, `complete`
#'   (proportion of required fields present), and `missing` (a
#'   comma-separated list).  With `detail = TRUE`, one row per
#'   `id`/`field` pair.  Folders holding spatial data but no readme
#'   are reported with `field = "readme"`.
#'
#' @seealso [list_layers()], [read_metadata()].
#'
#' @examples
#' \dontrun{
#' check_metadata()
#' check_metadata(theme = "elevation", detail = TRUE)
#' }
#'
#' @export
check_metadata <- function(theme = NULL, detail = FALSE, ...) {
  cat_df <- list_layers(theme = theme, verbose = FALSE, ...)
  undoc  <- attr(cat_df, "undocumented")

  rows <- lapply(seq_len(nrow(cat_df)), function(i) {
    md      <- read_metadata(cat_df$readme[i])
    present <- vapply(
      .meta_required,
      function(f) {
        val <- md[[f]]
        !is.null(val) && !is.na(val)
      },
      logical(1)
    )
    missing <- .meta_required[!present]
    data.frame(
      id        = cat_df$id[i],
      name      = cat_df$name[i],
      theme     = cat_df$theme[i],
      n_missing = length(missing),
      complete  = round(mean(present), 3),
      missing   = paste(missing, collapse = ", "),
      stringsAsFactors = FALSE
    )
  })

  out <- if (length(rows)) {
    do.call(rbind, rows)
  } else {
    data.frame(
      id = character(0), name = character(0),
      theme = character(0), n_missing = integer(0),
      complete = numeric(0), missing = character(0),
      stringsAsFactors = FALSE
    )
  }

  if (!isTRUE(detail)) {
    out <- out[order(-out$n_missing, out$id), , drop = FALSE]
    if (!is.null(undoc) && nrow(undoc)) {
      extra <- data.frame(
        id        = undoc$id,
        name      = undoc$name,
        theme     = undoc$theme,
        n_missing = NA_integer_,
        complete  = 0,
        missing   = "readme",
        stringsAsFactors = FALSE
      )
      out <- rbind(extra, out)
    }
    rownames(out) <- NULL
    return(out)
  }

  long <- lapply(seq_len(nrow(out)), function(i) {
    flds <- .split_list(out$missing[i])
    if (!length(flds)) {
      return(NULL)
    }
    data.frame(
      id = out$id[i], name = out$name[i], theme = out$theme[i],
      field = flds, stringsAsFactors = FALSE
    )
  })
  long <- do.call(rbind, long)

  if (!is.null(undoc) && nrow(undoc)) {
    long <- rbind(
      data.frame(
        id = undoc$id, name = undoc$name, theme = undoc$theme,
        field = "readme", stringsAsFactors = FALSE
      ),
      long
    )
  }
  if (is.null(long)) {
    long <- data.frame(
      id = character(0), name = character(0),
      theme = character(0), field = character(0),
      stringsAsFactors = FALSE
    )
  }
  rownames(long) <- NULL
  long
}

# End of script ----
