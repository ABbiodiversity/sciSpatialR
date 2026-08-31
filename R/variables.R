# ---
# title: variables — list the bands a product publishes
# author: Brendan Casey
# created: 2026-08-27
# inputs:
#   the product readmes on the spatial data share, via the
#   catalogue manifest built by build_catalogue() (catalogue.R)
# outputs:
#   a data.frame with one row per documented band
# notes:
#   Bands are a product-level fact: the guide records them in the
#   product readme and forbids repeating them in a variant record,
#   since aggregating a raster does not change what its bands
#   measure.  Rows are therefore emitted once per product, not once
#   per variant, and a product's `product_readme` is what gets
#   parsed.
#
#   The band blocks cannot be read off read_metadata().  That
#   parser is a flat key-value store where the first value for a
#   key wins, which is right for template fields but wrong here: a
#   readme documenting 61 bands repeats `Band:` 61 times and only
#   the first survives.  .parse_bands() below walks the file again
#   and collects repeated records instead, reusing the same line
#   matcher so both agree on what counts as a label.
#
#   Three block styles occur on the share and all three are read:
#
#     Layers:                     Band 1: NumCycles       Layer 1:
#         Band: bdod_0-5cm            Description: ...        Name: ...
#         Measure: Bulk density                               Fields: ...
#         Units: kg/dm3
#
#   A record ends at the next record, at a field indented less than
#   the record opened, or at a banner rule — which is what keeps
#   `Class Definitions:` out of the last band of a product readme.
# ---


# 1. Constants --------------------------------------------------

# Keys from .match_field_line() that open a band or layer record.
.band_start_keys <- "^(band|band_[0-9]+|layer_[0-9]+)$"

# Record fields promoted to columns, in order, each naming the
# parsed keys to try.  Anything else a block carries is kept in the
# record but not tabulated.
.band_field_map <- list(
  measure     = c("measure", "geometry"),
  units       = c("units", "unit"),
  scale       = c("measurement_scale", "scale"),
  valid_range = c("valid_range", "values", "range"),
  description = c("description", "notes")
)


# 2. list_variables ---------------------------------------------

#' List the variables a product publishes
#'
#' Reports the bands documented in each product's readme — what
#' each one measures, its units, its measurement scale, and its
#' valid range — so the variables available for extraction can be
#' browsed without opening a readme or a raster.
#'
#' Bands belong to the product, not to a variant: the data
#' management guide records them once in the product readme, since
#' resampling a layer does not change what its bands measure.  A
#' product with several variants therefore contributes one set of
#' rows, not one set per variant.
#'
#' Products whose readme documents no bands are listed with `band`
#' `NA` rather than dropped, so a documentation gap is visible
#' instead of looking like an absent product.  [check_metadata()]
#' reports the same gaps against the required template fields.
#'
#' @param theme Optional character; theme folder name(s) to keep,
#'   e.g. `"elevation"`.  Matched case-insensitively.
#' @param product Optional character; product name(s) or catalogue
#'   id(s), e.g. `"soilgrids_250_v2_ab"` or
#'   `"geoscientificInformation/soilgrids_250_v2_ab"`.  Matched
#'   case-insensitively: exactly first, and if nothing matches
#'   exactly, as a substring, so a fragment of a long product name
#'   is enough.
#' @param verbose Logical; if `TRUE` (default), print a compact
#'   summary and return the table invisibly.
#' @param ... Passed to [build_catalogue()], e.g. `root`,
#'   `refresh`, or `files`.
#'
#' @return A `data.frame` with one row per band: `product` (the
#'   product's catalogue id), `name`, `theme`, `band`, `measure`,
#'   `units`, `scale`, `valid_range`, and `description`.  Classed
#'   `sciSpatial_variables` unless `verbose = FALSE`.
#'
#' @seealso [list_layers()] for the layers themselves,
#'   [layer_meta()] for one layer's full metadata.
#'
#' @examples
#' \dontrun{
#' list_variables()
#' list_variables(theme = "geoscientificInformation")
#' list_variables(product = "soilgrids")
#'
#' # Every band measuring pH, across the catalogue.
#' v <- list_variables(verbose = FALSE)
#' v[grepl("pH", v$measure, ignore.case = TRUE), ]
#' }
#'
#' @export
list_variables <- function(theme   = NULL,
                           product = NULL,
                           verbose = TRUE,
                           ...) {
  cat_df <- build_catalogue(quiet = TRUE, ...)

  if (!is.null(theme)) {
    if (!is.character(theme)) {
      stop("`theme` must be a character vector.", call. = FALSE)
    }
    cat_df <- cat_df[tolower(cat_df$theme) %in% tolower(theme), ,
                     drop = FALSE]
  }

  if (!is.null(product)) {
    if (!is.character(product)) {
      stop("`product` must be a character vector.", call. = FALSE)
    }
    cat_df <- cat_df[.match_product(cat_df, product), , drop = FALSE]
  }

  # One set of rows per product, however many variants it has.
  keep   <- !duplicated(cat_df$product_id)
  prods  <- cat_df[keep, , drop = FALSE]

  rows <- lapply(seq_len(nrow(prods)), function(i) {
    recs <- tryCatch(.parse_bands(prods$product_readme[i]),
                     error = function(e) list())
    .band_rows(recs, prods[i, , drop = FALSE])
  })

  out <- if (length(rows)) {
    do.call(rbind, rows)
  } else {
    .empty_variables()
  }
  rownames(out) <- NULL

  if (isTRUE(verbose)) {
    out <- structure(
      out, class = c("sciSpatial_variables", "data.frame")
    )
    print(out)
    return(invisible(out))
  }
  out
}


#' Match a product argument against the manifest
#'
#' Exact on name, id, or product id first; substring only if that
#' finds nothing, so an exact name is never widened by a product
#' that merely contains it.
#'
#' @param cat_df A manifest.
#' @param product Character; names or ids to match.
#' @return A logical vector the length of `nrow(cat_df)`.
#' @noRd
.match_product <- function(cat_df, product) {
  hay <- tolower(
    cbind(cat_df$name, cat_df$id, cat_df$product_id)
  )
  needle <- tolower(product)

  hit <- rep(FALSE, nrow(cat_df))
  for (p in needle) {
    hit <- hit | apply(hay, 1, function(r) any(r == p))
  }
  if (any(hit)) {
    return(hit)
  }
  for (p in needle) {
    hit <- hit | apply(hay, 1, function(r) any(grepl(p, r, fixed = TRUE)))
  }
  hit
}


#' Turn parsed band records into manifest-joined rows
#' @noRd
.band_rows <- function(recs, row) {
  pick <- function(rec, keys) {
    for (k in keys) {
      val <- rec[[k]]
      if (!is.null(val) && !is.na(val) && nzchar(val)) {
        return(val)
      }
    }
    NA_character_
  }

  if (!length(recs)) {
    # No band block: keep the product visible as a gap.
    recs <- list(list(band = NA_character_))
  }

  do.call(rbind, lapply(recs, function(rec) {
    data.frame(
      product     = row$product_id,
      name        = row$name,
      theme       = row$theme,
      band        = if (is.null(rec$band)) NA_character_ else rec$band,
      measure     = pick(rec, .band_field_map$measure),
      units       = pick(rec, .band_field_map$units),
      scale       = pick(rec, .band_field_map$scale),
      valid_range = pick(rec, .band_field_map$valid_range),
      description = pick(rec, .band_field_map$description),
      stringsAsFactors = FALSE
    )
  }))
}


#' Variables table with the right columns and no rows
#' @noRd
.empty_variables <- function() {
  data.frame(
    product = character(0), name = character(0),
    theme = character(0), band = character(0),
    measure = character(0), units = character(0),
    scale = character(0), valid_range = character(0),
    description = character(0), stringsAsFactors = FALSE
  )
}


# 3. Band block parser ------------------------------------------

#' Collect the repeated band records in a readme
#'
#' @param path Character; path to a readme file.
#' @return A list of named lists, one per band or layer record.
#' @noRd
.parse_bands <- function(path) {
  if (!length(path) || is.na(path) || !file.exists(path)) {
    return(list())
  }
  lines <- .read_text_lines(path)
  lines <- gsub("\t", "    ", lines, fixed = TRUE)

  recs   <- list()
  cur    <- NULL
  indent <- NA_integer_
  field  <- NULL

  close_record <- function() {
    if (!is.null(cur)) {
      recs[[length(recs) + 1L]] <<- lapply(cur, .band_value)
    }
    cur   <<- NULL
    field <<- NULL
  }

  for (line in lines) {
    # A banner rule ends whatever block was open.
    if (grepl("^\\s*[=_-]{3,}\\s*$", line)) {
      close_record()
      next
    }
    if (!nzchar(trimws(line))) {
      next
    }

    parts <- .match_field_line(line)

    if (is.null(parts)) {
      # Prose continuing the value started on the previous line.
      if (!is.null(cur) && !is.null(field)) {
        cur[[field]] <- .append_value(cur[[field]],
                                      .clean_value(line))
      }
      next
    }

    if (grepl(.band_start_keys, parts$key)) {
      close_record()
      cur    <- list(band = .band_label(parts))
      indent <- parts$indent
      # Only a named record can take a wrapped continuation of its
      # own label; `Band:` with an empty value cannot.
      field  <- if (nzchar(parts$value)) "band" else NULL
      next
    }

    if (is.null(cur)) {
      next
    }
    # A field standing further left than the record opened belongs
    # to the section, not to the band: `Class Definitions:` closes
    # the last band of a product readme this way.
    if (parts$indent < indent) {
      close_record()
      next
    }

    key <- parts$key
    cur[[key]] <- if (is.null(cur[[key]])) {
      parts$value
    } else {
      .append_value(cur[[key]], parts$value)
    }
    field <- key
  }
  close_record()

  # A record whose name only arrived as a `Name:` field.
  lapply(recs, function(rec) {
    named <- !is.null(rec$name) && !is.na(rec$name)
    if (named && !is.na(rec$band) &&
          grepl("^(Band|Layer) [0-9]+$", rec$band)) {
      rec$band <- rec$name
    }
    rec
  })
}


#' Finalise one band field value
#'
#' As [.finalise_value()], plus the unedited template slots the band
#' blocks carry — `[REQUIRED — not available from source]` is the
#' absence of a valid range, not a valid range.
#'
#' @param x A length-one character.
#' @return The cleaned value, or `NA_character_`.
#' @noRd
.band_value <- function(x) {
  out <- .finalise_value(x)
  if (!is.na(out) && .is_placeholder(out)) {
    return(NA_character_)
  }
  out
}


#' Name a band record from the line that opened it
#'
#' `Band: bdod_0-5cm_mean` and `Band 1: NumCycles` both name the
#' band in the value.  `Band 1:` alone does not, so the label falls
#' back to the ordinal the key carries.
#'
#' @param parts A `.match_field_line()` result.
#' @return A length-one character.
#' @noRd
.band_label <- function(parts) {
  if (nzchar(parts$value) && !.is_placeholder(parts$value)) {
    return(.squish(parts$value))
  }
  bits <- strsplit(parts$key, "_", fixed = TRUE)[[1]]
  if (length(bits) == 2L) {
    paste0(toupper(substr(bits[1], 1, 1)), substr(bits[1], 2, 99),
           " ", bits[2])
  } else {
    NA_character_
  }
}


# 4. Printing ---------------------------------------------------

#' Print a compact view of the variables table
#'
#' @param x A `sciSpatial_variables` object.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.sciSpatial_variables <- function(x, ...) {
  if (!nrow(x)) {
    cat("No variables matched.\n")
    return(invisible(x))
  }
  documented <- !is.na(x$band)

  view <- data.frame(
    product = vapply(x$name, .truncate, character(1), n = 32,
                     USE.NAMES = FALSE),
    band    = vapply(x$band, .truncate, character(1), n = 26,
                     USE.NAMES = FALSE),
    measure = vapply(x$measure, .truncate, character(1), n = 40,
                     USE.NAMES = FALSE),
    units   = vapply(x$units, .truncate, character(1), n = 14,
                     USE.NAMES = FALSE),
    stringsAsFactors = FALSE
  )

  cat(sprintf(
    "%s across %s\n",
    .plural(sum(documented), "variable"),
    .plural(length(unique(x$product[documented])), "product")
  ))
  undoc <- unique(x$product[!documented])
  if (length(undoc)) {
    cat(sprintf(
      "%s with no bands documented\n",
      .plural(length(undoc), "product")
    ))
  }
  cat("\n")
  print(view, row.names = FALSE, right = FALSE)
  invisible(x)
}

# End of script ----
