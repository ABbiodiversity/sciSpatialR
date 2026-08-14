# ---
# title: Add a Coordinate Reference System block to share readmes
# author: Brendan Casey
# created: 2026-08-14
# inputs:
#   the spatial data share (spatial_root()), its dataset readmes,
#   and the data files each readme describes
# outputs:
#   a printed report of the CRS found per layer and, when DRY_RUN
#   is FALSE, an edited readme.txt per layer plus a timestamped
#   backup of every file touched under readme_backups/
# notes:
#   The metadata template gained a Coordinate Reference System
#   block in the GEOGRAPHIC INFORMATION section, but no readme on
#   the share carries it.  Rather than transcribe it by hand, this
#   reads the CRS from each layer's data files and splices the
#   block in above the existing `Extent:` line.
#
#   The CRS is read from file headers only — terra::rast() and
#   terra::vect(proxy = TRUE) open the header without pulling
#   pixels or geometries — so a 15 GB raster costs about a tenth of
#   a second.
#
#   Writing to the share is deliberately hard to do by accident:
#   DRY_RUN is TRUE, so sourcing this file only reports.  Set it to
#   FALSE to apply.  Every edit is byte-preserving — the file is
#   read and written as raw bytes, so line endings and the mix of
#   UTF-8 and Windows-1252 encodings on the share survive
#   untouched, and the only change to a file is the inserted block.
#   That invariant is asserted before each write, not assumed.
#
#   Layers are skipped rather than guessed at when the data cannot
#   settle the question: files within one folder disagreeing on
#   their CRS, or carrying no CRS at all.  Skips are reported so
#   they can be handled by hand.
#
#   Planned improvements:
#   - Datasets with no EPSG code (ESRI WKT) get their Authority
#     Code written as "Not Specified"; identifying those needs a
#     human decision.
# ---


# 1. Setup ----

## 1.1 Load packages ----
library(terra)      # read CRS from file headers (version: 1.8.50)
library(sciSpatialR) # catalogue scan and readme parsing (0.1.0)

## 1.2 Configuration ----
# DRY_RUN = TRUE reports without touching the share.  Set FALSE to
# write.  MAX_FILES caps how many files per layer are checked for
# CRS agreement; folders holding thousands of tiles are sampled
# evenly rather than read in full.
DRY_RUN     <- TRUE
MAX_FILES   <- 60
BACKUP_ROOT <- file.path(getwd(), "readme_backups")


# 2. Read the CRS from a layer's data files ----
# Opens each sampled file's header, describes its CRS, and returns
# a single answer for the layer — or a reason it cannot.

## 2.1 Describe one file's CRS ----
crs_of_file <- function(path) {
  ext <- tolower(tools::file_ext(path))
  obj <- if (ext %in% c("shp", "gpkg", "geojson", "kml", "gml",
                        "sqlite", "gdb")) {
    terra::vect(path, proxy = TRUE)
  } else {
    terra::rast(path)
  }

  wkt <- terra::crs(obj)
  if (!nzchar(wkt)) {
    return(NULL)
  }
  desc <- terra::crs(obj, describe = TRUE)
  name <- desc$name
  # "unknown" is GDAL's placeholder for a file whose CRS could not
  # be identified; treat it as absent rather than as a CRS.
  if (is.na(name) || !nzchar(name) || identical(name, "unknown")) {
    return(NULL)
  }

  list(
    name       = name,
    code       = if (is.na(desc$authority) || is.na(desc$code)) {
      NA_character_
    } else {
      paste0(desc$authority, ":", desc$code)
    },
    datum      = wkt_field(wkt, "(?:DATUM|ENSEMBLE)"),
    projection = wkt_field(wkt, "METHOD"),
    vertical   = wkt_field(wkt, "VERTCRS")
  )
}

## 2.2 Pull a named node out of a WKT string ----
# WKT2 nests the pieces the template asks for: the datum sits in
# DATUM (or ENSEMBLE, for WGS 84), the projection in the CONVERSION
# METHOD, and any vertical component in VERTCRS.
wkt_field <- function(wkt, node) {
  pat <- paste0('(?s).*?', node, '\\["([^"]+)".*')
  if (!grepl(paste0(node, '\\['), wkt, perl = TRUE)) {
    return(NA_character_)
  }
  sub(pat, "\\1", wkt, perl = TRUE)
}

## 2.3 Agree a CRS for the whole layer ----
# A layer folder can hold many files; they must agree before the
# answer is written to a readme describing all of them.
layer_crs <- function(files) {
  if (!length(files)) {
    return(list(status = "no data file"))
  }
  idx <- if (length(files) > MAX_FILES) {
    unique(round(seq(1, length(files), length.out = MAX_FILES)))
  } else {
    seq_along(files)
  }

  found <- lapply(files[idx], function(f) {
    tryCatch(crs_of_file(f), error = function(e) NULL)
  })
  found <- Filter(Negate(is.null), found)

  if (!length(found)) {
    return(list(status = "no CRS in any file"))
  }
  keys <- vapply(found, function(x) paste(x$name, x$code), character(1))
  if (length(unique(keys)) > 1) {
    return(list(
      status = paste("files disagree:",
                     paste(unique(keys), collapse = " / "))
    ))
  }

  out <- found[[1]]
  out$status   <- "ok"
  out$n_checked <- length(idx)
  out$n_files   <- length(files)
  out
}


# 3. Build the readme block ----
# Renders the block exactly as the template lays it out: a parent
# label with four-space indented sub-fields, so the catalogue
# parser namespaces them under coordinate_reference_system_*.

crs_block <- function(crs) {
  value <- function(x, fallback) {
    if (is.null(x) || is.na(x) || !nzchar(x)) fallback else x
  }
  c(
    "Coordinate Reference System:",
    paste0("    Name: ", value(crs$name, "Not Specified")),
    paste0("    Authority Code: ", value(crs$code, "Not Specified")),
    paste0("    Datum: ", value(crs$datum, "Not Specified")),
    paste0("    Projection: ",
           value(crs$projection, "None (geographic coordinate system)")),
    paste0("    Vertical CRS: ", value(crs$vertical, "None"))
  )
}


# 4. Splice the block into a readme ----
# The share holds a mix of UTF-8 and Windows-1252 files with both
# line endings, so the file is handled as bytes throughout and
# never decoded.  Every regular expression here passes
# useBytes = TRUE for the same reason.

## 4.1 Read a file as lines of bytes ----
read_bytes_lines <- function(path) {
  con <- file(path, "rb")
  on.exit(close(con))
  txt <- rawToChar(readBin(con, "raw", file.size(path)))

  eol <- if (grepl("\r\n", txt, fixed = TRUE, useBytes = TRUE)) {
    "\r\n"
  } else {
    "\n"
  }
  list(
    lines    = strsplit(txt, eol, fixed = TRUE, useBytes = TRUE)[[1]],
    eol      = eol,
    trailing = endsWith(txt, eol)
  )
}

## 4.2 Rejoin lines to the exact original byte layout ----
join_bytes_lines <- function(doc, lines) {
  txt <- paste(lines, collapse = doc$eol)
  if (doc$trailing) {
    txt <- paste0(txt, doc$eol)
  }
  charToRaw(txt)
}

## 4.3 Locate an existing block so a re-run replaces it ----
# Returns the line span of a previous Coordinate Reference System
# block: the label plus the indented sub-fields beneath it.
existing_block <- function(lines) {
  at <- grep("^[ \t]*Coordinate Reference System[ \t]*:", lines,
             useBytes = TRUE)
  if (!length(at)) {
    return(NULL)
  }
  start <- at[1]
  end   <- start
  while (end < length(lines) &&
         grepl("^[ \t]+\\S", lines[end + 1], useBytes = TRUE)) {
    end <- end + 1
  }
  c(start, end)
}

## 4.4 Produce the edited byte vector ----
# Inserts above `Extent:` — where the template places the block —
# falling back to just under the GEOGRAPHIC INFORMATION banner for
# a readme with no extent recorded.
splice_crs <- function(path, block) {
  doc   <- read_bytes_lines(path)
  lines <- doc$lines

  span <- existing_block(lines)
  if (!is.null(span)) {
    lines <- append(lines[-seq(span[1], span[2])], block,
                    after = span[1] - 1)
    return(list(bytes = join_bytes_lines(doc, lines),
                doc = doc, action = "replaced"))
  }

  at <- grep("^[ \t]*Extent[ \t]*:", lines, useBytes = TRUE)
  if (!length(at)) {
    at <- grep("GEOGRAPHIC INFORMATION", lines, useBytes = TRUE)
    if (!length(at)) {
      return(list(bytes = NULL, action = "no insertion point"))
    }
    # Skip the banner rule closing the section heading.
    at <- at[1] + 2
  } else {
    at <- at[1] - 1
  }

  lines <- append(lines, block, after = at)
  list(bytes = join_bytes_lines(doc, lines), doc = doc,
       action = "inserted")
}

## 4.5 Assert the edit changed nothing but the block ----
# Removing the inserted lines again must reproduce the original
# file byte for byte.  This is checked before every write, so an
# encoding or line-ending slip cannot reach the share.
verify_splice <- function(path, new_bytes, block) {
  original <- readBin(file(path, "rb"), "raw", file.size(path))
  doc      <- read_bytes_lines(path)

  txt   <- rawToChar(new_bytes)
  lines <- strsplit(txt, doc$eol, fixed = TRUE, useBytes = TRUE)[[1]]
  span  <- existing_block(lines)
  if (is.null(span)) {
    return(FALSE)
  }
  stripped <- lines[-seq(span[1], span[2])]
  identical(join_bytes_lines(doc, stripped), original)
}


# 5. Run ----
# Reports one line per layer, then writes when DRY_RUN is FALSE.

cat_df <- build_catalogue(quiet = TRUE)
stamp  <- format(Sys.time(), "%Y%m%d_%H%M%S")
report <- list()

for (i in seq_len(nrow(cat_df))) {
  id     <- cat_df$id[i]
  readme <- cat_df$readme[i]
  crs    <- layer_crs(layer_files(id))

  if (!identical(crs$status, "ok")) {
    report[[length(report) + 1]] <- data.frame(
      id = id, action = "SKIP", crs = crs$status,
      stringsAsFactors = FALSE
    )
    next
  }

  block  <- crs_block(crs)
  spliced <- splice_crs(readme, block)

  if (is.null(spliced$bytes)) {
    report[[length(report) + 1]] <- data.frame(
      id = id, action = "SKIP", crs = spliced$action,
      stringsAsFactors = FALSE
    )
    next
  }

  label <- paste0(crs$name, " (",
                  if (is.na(crs$code)) "no EPSG code" else crs$code,
                  ")")

  if (!DRY_RUN) {
    # Back up first, mirroring the share's folder structure so a
    # restore is a straight copy back.
    dest <- file.path(BACKUP_ROOT, stamp, id, basename(readme))
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    file.copy(readme, dest, overwrite = FALSE)

    if (!verify_splice(readme, spliced$bytes, block)) {
      stop("Edit would change more than the CRS block: ", readme,
           call. = FALSE)
    }
    con <- file(readme, "wb")
    writeBin(spliced$bytes, con)
    close(con)
  }

  report[[length(report) + 1]] <- data.frame(
    id     = id,
    action = if (DRY_RUN) paste0("would ", spliced$action)
             else spliced$action,
    crs    = label,
    stringsAsFactors = FALSE
  )
}

report <- do.call(rbind, report)
cat(if (DRY_RUN) "DRY RUN - nothing written\n\n" else
      paste0("WROTE to the share; backups in ",
             file.path(BACKUP_ROOT, stamp), "\n\n"))
print(report, row.names = FALSE, right = FALSE)

# End of script ----
