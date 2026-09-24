# ---
# title: download_layer — copy a catalogued layer to a local folder
# author: Brendan Casey
# created: 2026-09-23
# inputs:
#   name - a layer name or catalogue id, as listed by list_layers()
#   dest - a local directory to copy into
# outputs:
#   the layer's files written under dest/<id>/, and a data.frame
#   copy manifest returned invisibly
# notes:
#   A layer is a folder, not a file: the data sits beside the readme
#   that documents it and whatever ancillary files came with it, and
#   a copy that leaves the readme behind on the share is a copy that
#   arrives undocumented.  Everything in the layer folder therefore
#   comes down, sidecars included — this is the one place the
#   shapefile parts layer_files() hides must not be hidden, since a
#   `.shp` separated from its `.dbf` and `.shx` will not open.
#
#   Where a product splits its record, the variant's readme carries
#   the geometry and the product's carries the title, licence, and
#   citation, so a variant copied on its own is missing half its
#   provenance.  The product folder's non-data files come too, and
#   because the local tree mirrors the catalogue path they land one
#   level up from the variant, exactly as they sit on the share.
#   Sibling variants do not: they are separate layers with their own
#   ids, and are downloaded by asking for them.
#
#   Nothing is re-copied that is already here: a destination file
#   matching the source on size and modification time is skipped, so
#   re-running after a partial copy resumes rather than restarts.
#   file.copy(copy.date = TRUE) is what makes that test work — a
#   copy stamped `now` would never match its source again.
#
#   Planned improvements:
#   - A `metadata_only` mode for auditing readmes without the data.
#   - Checksum verification for destinations that must be trusted
#     rather than merely present.
# ---


# 1. Constants --------------------------------------------------

# Name of the receipt written into the layer's destination folder.
# Underscore-prefixed so it sorts beside the readme and is plainly
# not one of the product's own files.
.log_file <- "_download_log.txt"


# 2. download_layer ---------------------------------------------

#' Copy a catalogued layer to a local directory
#'
#' Copies a layer from the spatial data share to a folder of your
#' own, bringing its documentation with it.  Everything in the layer
#' folder comes down — the data, its readme, and any ancillary files
#' beside them — and where a product's record is split between a
#' product readme and a variant readme, both are copied.
#'
#' Use this to work off the network, or to hand someone a dataset
#' they can cite.  To read a layer without copying it, use
#' [get_layer()].
#'
#' @details
#' The copy is rooted at the product folder, which lands directly in
#' `dest`: a layer catalogued as `geoscientific/soilgrids/soil1km`
#' arrives as `<dest>/soilgrids/soil1km`, with the product's readme
#' one level above it in `<dest>/soilgrids`, exactly as the two sit
#' on the share.  The ISO topic category is the share's filing
#' system rather than part of the dataset, so it is left behind;
#' pass `keep_theme = TRUE` to reproduce the full catalogue path,
#' which is what keeps two same-named products in different themes
#' from merging into one folder.  Sibling variants of the same
#' product are separate layers and are not copied; ask for them by
#' name.
#'
#' Only the product's *non-data* files are copied alongside a
#' variant — its readme and any documentation, not a second copy of
#' any data file that happens to sit at product level.  Shapefile
#' sidecars (`.dbf`, `.shx`, `.prj` and friends) are treated as data
#' and always accompany their `.shp`, unlike in [layer_files()],
#' which hides them so a shapefile is listed once.  An Esri file
#' geodatabase is copied whole, as one item.
#'
#' A file already present in `dest` and matching its source on size
#' and modification time is skipped, so an interrupted copy resumes
#' rather than restarts.  `overwrite = TRUE` forces every file to be
#' copied again; `overwrite = FALSE` still replaces a destination
#' file that differs from its source.
#'
#' Every copy leaves a receipt: `_download_log.txt` is written into
#' the layer's folder alongside the data, recording what was copied,
#' from where, by whom, when, how long it took, and each file's size
#' and md5 checksum.  Runs append to it rather than replacing it, so
#' a layer topped up over several sessions keeps its whole history.
#' A copy whose provenance lives only in the console scrollback has
#' none by the time anyone asks, which is the same reason the readme
#' comes down with the data.
#'
#' With `verify = TRUE` (the default) each copied file is read back
#' and compared to its source on size and md5 checksum before the
#' log records it as sound.  Only files copied in that run are
#' checked: a skipped file was verified when it was copied, and the
#' log beside it says so, which keeps a re-run cheap.
#'
#' Sidecar-style metadata such as a raster's `.tif.aux.xml` has
#' extension `xml` and so counts as ancillary rather than data.  At
#' product level that can bring down an orphan `.aux.xml`, which is
#' harmless: it is metadata, and it is tiny.
#'
#' @param name Character; a layer `name` (`"fab_dem"`) or catalogue
#'   `id` (`"elevation/fab_dem"`) as listed by [list_layers()].
#' @param dest Character; a local directory to copy into.  Created
#'   if it does not exist.
#' @param overwrite Logical; if `TRUE`, copy every file again rather
#'   than skipping those already present and unchanged.  Default
#'   `FALSE`.
#' @param dry_run Logical; if `TRUE`, report what would be copied
#'   and how much it comes to, writing nothing.  Default `FALSE`.
#' @param verify Logical; if `TRUE` (default), check every copied
#'   file against its source on size and md5 checksum, and record
#'   the result in the log.  Verification re-reads each copied file
#'   from the share, so it roughly doubles the time a large copy
#'   takes; pass `FALSE` to skip it.
#' @param keep_theme Logical; if `TRUE`, include the layer's ISO
#'   topic category folder in the local path, reproducing the
#'   share's full structure.  Default `FALSE`.
#' @param quiet Logical; if `TRUE`, suppress progress messages.
#'   Default `FALSE`.
#' @param ... Passed to [build_catalogue()], e.g. `root` or
#'   `refresh`.
#'
#' @return Invisibly, a `data.frame` with one row per file copied,
#'   skipped, or attempted:
#'   \describe{
#'     \item{`source`}{Path on the share.}
#'     \item{`destination`}{Path written under `dest`.}
#'     \item{`bytes`}{Size of the source, summed over a
#'       geodatabase's contents.}
#'     \item{`part`}{`"layer"` for the layer's own files,
#'       `"product"` for the parent product's metadata.}
#'     \item{`status`}{`"copied"`, `"skipped"`, or `"failed"`; or
#'       `"would copy"` and `"would skip"` under `dry_run`.}
#'     \item{`verified`}{`"ok"`, the reason verification failed, or
#'       `"not checked"`.  `NA` for a skipped file.}
#'     \item{`md5`}{The source checksum, where one was taken.}
#'   }
#'
#' @seealso [get_layer()] to read a layer without copying it,
#'   [layer_files()] to see what a layer folder holds, and
#'   [layer_meta()] for its metadata.
#'
#' @examples
#' \dontrun{
#' # See what a copy would cost before starting one.
#' download_layer("fab_dem", "D:/local_spatial", dry_run = TRUE)
#'
#' download_layer("fab_dem", "D:/local_spatial")
#'
#' # A variant brings its product's readme down with it.
#' p <- download_layer("soilgrids_250_v2_ab/abmi1km",
#'                     "D:/local_spatial")
#' p[p$part == "product", c("destination", "status")]
#'
#' # Reproduce the share's full path, theme folder included.
#' download_layer("fab_dem", "D:/local_spatial", keep_theme = TRUE)
#'
#' # The receipt left beside the data.
#' cat(readLines("D:/local_spatial/fab_dem/_download_log.txt"),
#'     sep = "\n")
#'
#' # Skip the read-back on a very large copy.
#' download_layer("scanfi", "D:/local_spatial", verify = FALSE)
#'
#' # Re-running copies only what changed.
#' download_layer("fab_dem", "D:/local_spatial")
#' }
#'
#' @export
download_layer <- function(name,
                           dest,
                           overwrite  = FALSE,
                           dry_run    = FALSE,
                           verify     = TRUE,
                           keep_theme = FALSE,
                           quiet      = FALSE,
                           ...) {
  # 1. Validate inputs ----
  if (!is.character(dest) || length(dest) != 1 || !nzchar(dest)) {
    stop("`dest` must be a single non-empty character path.",
         call. = FALSE)
  }
  dest <- .norm_path(
    normalizePath(path.expand(dest), winslash = "/",
                  mustWork = FALSE)
  )
  if (file.exists(dest) && !dir.exists(dest)) {
    stop("`dest` is a file, not a directory: ", dest, "\n",
         "Give a folder to copy the layer into.", call. = FALSE)
  }

  # 2. Resolve the layer ----
  cat_df <- build_catalogue(quiet = TRUE, ...)
  row    <- .resolve_layer(name, .catalogue = cat_df)
  root   <- .norm_path(attr(cat_df, "root"))

  # Copying the share onto itself is never what was meant, and
  # would recurse into the folder being written.
  if (identical(dest, root) ||
        startsWith(paste0(dest, "/"), paste0(root, "/"))) {
    stop("`dest` is inside the data share: ", dest, "\n",
         "Choose a local directory, not a folder under ", root, ".",
         call. = FALSE)
  }

  # 3. Plan the copy ----
  plan <- .copy_plan(row, cat_df, dest, keep_theme)
  if (!nrow(plan)) {
    stop("Layer '", row$id, "' holds no files to copy in ",
         row$path, "\n",
         "Run layer_files(\"", row$id, "\", all = TRUE) to see ",
         "what the folder holds.", call. = FALSE)
  }

  # 4. Decide copy or skip ----
  keep <- rep(TRUE, nrow(plan))
  if (!isTRUE(overwrite)) {
    for (i in seq_len(nrow(plan))) {
      keep[i] <- !.copy_unchanged(plan$bytes[i], plan$mtime[i],
                                  plan$destination[i],
                                  plan$bundle[i])
    }
  }
  plan$status <- ifelse(
    keep,
    if (isTRUE(dry_run)) "would copy" else "copied",
    if (isTRUE(dry_run)) "would skip" else "skipped"
  )

  # 5. Report and stop here on a dry run ----
  if (isTRUE(dry_run)) {
    if (!isTRUE(quiet)) {
      message(
        "Dry run — nothing was written.\n",
        .plural(sum(keep), "file"), " (",
        .fmt_bytes(sum(plan$bytes[keep], na.rm = TRUE)),
        ") would be copied to ", dest, "; ",
        sum(!keep), " already up to date."
      )
      .print_copy_plan(plan, dest)
    }
    return(invisible(.finish_plan(plan, row, dest, dry_run = TRUE)))
  }

  # Nothing to do is worth saying plainly, rather than announcing a
  # copy of no files and then reporting that none were copied.
  if (!any(keep)) {
    if (!isTRUE(quiet)) {
      message(row$id, " is already up to date in ", dest, " (",
              .plural(nrow(plan), "file"), ").")
    }
    return(invisible(.finish_plan(plan, row, dest, dry_run = FALSE)))
  }

  layer_dir <- .local_prefix(dest, row$id, row$theme, keep_theme)
  if (!isTRUE(quiet)) {
    message("Copying ", row$id, ": ", .plural(sum(keep), "file"),
            ", ", .fmt_bytes(sum(plan$bytes[keep], na.rm = TRUE)),
            " to ", layer_dir, " ...")
  }

  # 6. Create the destination tree ----
  dirs <- unique(.parent_dir(plan$destination[keep]))
  for (d in dirs) {
    if (!dir.exists(d)) {
      dir.create(d, recursive = TRUE, showWarnings = FALSE)
    }
  }
  if (!dir.exists(dest)) {
    stop("Could not create the destination directory: ", dest, "\n",
         "Check that the drive is connected and that you have ",
         "permission to write there.", call. = FALSE)
  }

  # 7. Copy ----
  started         <- Sys.time()
  reason          <- rep(NA_character_, nrow(plan))
  plan$verified   <- NA_character_
  plan$md5        <- NA_character_
  for (i in which(keep)) {
    res <- .copy_one(plan$source[i], plan$destination[i],
                     plan$bundle[i])
    if (!isTRUE(res$ok)) {
      plan$status[i] <- "failed"
      reason[i]      <- res$reason
    }
  }

  # 8. Verify what landed ----
  # Only this run's copies are checked.  A skipped file was verified
  # when it was copied, and the log beside it records that; checking
  # the whole layer again would read every byte back over the share
  # on a re-run that copied nothing.
  for (i in which(plan$status == "copied")) {
    if (isTRUE(verify)) {
      v <- .verify_copy(plan$source[i], plan$destination[i],
                        plan$bytes[i], plan$bundle[i])
      plan$verified[i] <- v$verdict
      plan$md5[i]      <- v$md5
      if (!identical(v$verdict, "ok")) {
        plan$status[i] <- "failed"
        reason[i]      <- v$verdict
      }
    } else {
      plan$verified[i] <- "not checked"
    }
  }
  elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))

  # 9. Write the copy log ----
  log_path <- paste0(layer_dir, "/", .log_file)
  ok_log <- .write_copy_log(plan, row, dest, log_path, elapsed,
                            verify, root)

  # 10. Report ----
  n_copied <- sum(plan$status == "copied")
  n_failed <- sum(plan$status == "failed")
  if (!isTRUE(quiet)) {
    message("Copied ", .plural(n_copied, "file"), " (",
            .fmt_bytes(sum(plan$bytes[plan$status == "copied"],
                           na.rm = TRUE)),
            ") in ", .fmt_elapsed(elapsed), "; ",
            sum(plan$status == "skipped"), " already up to date.")
    if (isTRUE(verify) && n_copied) {
      message("Verified ", .plural(n_copied, "file"),
              " against the source on size and md5 checksum.")
    }
    if (isTRUE(ok_log)) {
      message("Copy log written to ", log_path)
    }
  }
  if (n_failed) {
    .warn_failures(plan, reason, dest)
  }
  invisible(.finish_plan(plan, row, dest, dry_run = FALSE))
}


# 3. Copy planning ----------------------------------------------

#' Plan the copy for one layer
#'
#' Returns one row per unit to copy: every file in the layer folder,
#' plus the parent product's non-data files when the layer is a
#' variant.  A geodatabase is one unit, not its internals.
#'
#' @param row A one-row manifest, from `.resolve_layer()`.
#' @param cat_df The manifest `row` came from.
#' @param dest Character; the normalised destination root.
#' @param keep_theme Logical; keep the ISO topic category folder in
#'   the local path.
#' @return A `data.frame` with `source`, `destination`, `bytes`,
#'   `mtime`, `bundle`, and `part`.
#' @noRd
.copy_plan <- function(row, cat_df, dest, keep_theme = FALSE) {
  # Documented layer folders, plus the undocumented ones, are what
  # .layer_file_paths() subtracts as nested layers.  Both lists are
  # needed at product level: the first removes documented sibling
  # variants, the second a variant folder holding data but no
  # readme, which never reaches the manifest.
  undoc    <- attr(cat_df, "undocumented")
  all_dirs <- c(cat_df$path, undoc$path)

  out <- .copy_rows(row$path, all_dirs,
                    prefix = .local_prefix(dest, row$id, row$theme,
                                           keep_theme),
                    data = TRUE, part = "layer")

  # A product with no variants, or a variant with no product above
  # it, has no second record to fetch.
  split <- !is.na(row$variant) && !identical(row$id, row$product_id)
  if (split) {
    prod <- .copy_rows(
      .parent_dir(row$product_readme), all_dirs,
      prefix = .local_prefix(dest, row$product_id, row$theme,
                             keep_theme),
      data = FALSE, part = "product"
    )
    out <- rbind(out, prod)
  }
  rownames(out) <- NULL
  out
}


#' Where a catalogue id lands under the destination
#'
#' The ISO topic category is the share's filing system, not part of
#' the dataset's identity, and reproducing it locally buries a
#' single download two folders deep.  It is dropped by default, so
#' the product folder sits directly in `dest`; `keep_theme = TRUE`
#' puts it back, which is what keeps two same-named products in
#' different themes from merging into one folder.
#'
#' Only the theme is dropped.  Everything from the product folder
#' down is kept, so a variant stays inside its product and the
#' product's readme still lands one level above it.
#'
#' @param dest Character; the destination root.
#' @param id Character; a catalogue id or product id.
#' @param theme Character; the layer's theme, the first segment of
#'   its id.
#' @param keep_theme Logical; keep that first segment.
#' @return A length-one path.
#' @noRd
.local_prefix <- function(dest, id, theme, keep_theme = FALSE) {
  if (!isTRUE(keep_theme) && !is.na(theme) && nzchar(theme)) {
    id <- .relative_to(id, theme)
  }
  paste0(dest, "/", id)
}


#' Plan the copy of one folder into one destination prefix
#'
#' @param dir Character; the folder to copy from.
#' @param all_dirs Character; folders to subtract as nested layers.
#' @param prefix Character; the destination root for these files,
#'   i.e. `dest/<id>` or `dest/<product_id>`.
#' @param data Logical; if `FALSE`, drop spatial data files and keep
#'   only readmes, documentation, and other ancillary files.
#' @param part Character; the label recorded in the `part` column.
#' @return A `data.frame` of plan rows, with zero rows when the
#'   folder contributes nothing.
#' @noRd
.copy_rows <- function(dir, all_dirs, prefix, data = TRUE, part) {
  empty <- data.frame(
    source = character(0), destination = character(0),
    bytes = numeric(0), mtime = numeric(0),
    bundle = logical(0), part = character(0),
    stringsAsFactors = FALSE
  )
  if (!length(dir) || is.na(dir) || !dir.exists(dir)) {
    return(empty)
  }

  files <- .layer_file_paths(dir, all_dirs, bundles = TRUE)
  if (!isTRUE(data)) {
    files <- files[!.is_data_file(files)]
  }
  if (!length(files)) {
    return(empty)
  }

  bundle <- tolower(tools::file_ext(files)) %in% .bundle_exts
  data.frame(
    source      = files,
    destination = paste0(prefix, "/",
                         vapply(files, .relative_to, character(1),
                                root = dir, USE.NAMES = FALSE)),
    bytes       = .path_bytes(files, bundle),
    mtime       = .path_mtime(files, bundle),
    bundle      = bundle,
    part        = part,
    stringsAsFactors = FALSE
  )
}


#' Is a path a spatial data file, sidecars included?
#'
#' Extension alone is not enough.  A shapefile's `.dbf`, `.shx`, and
#' `.prj` carry no extension the data lists recognise, so an
#' extension-only test files them as ancillary — and a loose
#' product-level shapefile would then arrive as three orphan
#' sidecars with no `.shp` beside them.
#'
#' @param paths Character; file paths.
#' @return A logical vector the length of `paths`.
#' @noRd
.is_data_file <- function(paths) {
  if (!length(paths)) {
    return(logical(0))
  }
  exts <- tolower(tools::file_ext(paths))
  exts %in% c(.raster_exts, .vector_exts, .sidecar_exts)
}


# 4. Size, time, and the skip test ------------------------------

#' Size in bytes, summed over a bundle's contents
#'
#' `file.size()` on a `.gdb` reports the directory entry rather than
#' the geodatabase, so a bundle is totalled from the files inside
#' it, as `.inventory()` does for the manifest.
#'
#' @param paths Character; file or bundle paths.
#' @param bundle Logical; which elements are bundles.
#' @return A numeric vector of bytes.
#' @noRd
.path_bytes <- function(paths, bundle) {
  out <- numeric(length(paths))
  for (i in seq_along(paths)) {
    out[i] <- if (isTRUE(bundle[i])) {
      sum(file.size(list.files(paths[i], recursive = TRUE,
                               full.names = TRUE)),
          na.rm = TRUE)
    } else {
      file.size(paths[i])
    }
  }
  out
}


#' Modification time, taken as the newest file in a bundle
#'
#' Returned as seconds since the epoch rather than `POSIXct`.  The
#' value is only ever differenced against another one, and a numeric
#' carries no time zone to be reinterpreted on the way into and out
#' of a `data.frame` column.
#'
#' @param paths Character; file or bundle paths.
#' @param bundle Logical; which elements are bundles.
#' @return A numeric vector of seconds, `NA` where unreadable.
#' @noRd
.path_mtime <- function(paths, bundle) {
  out <- rep(NA_real_, length(paths))
  for (i in seq_along(paths)) {
    out[i] <- if (isTRUE(bundle[i])) {
      inner <- list.files(paths[i], recursive = TRUE,
                          full.names = TRUE)
      if (length(inner)) {
        max(as.numeric(file.mtime(inner)))
      } else {
        NA_real_
      }
    } else {
      as.numeric(file.mtime(paths[i]))
    }
  }
  out
}


#' Does the destination already hold this file unchanged?
#'
#' Size is the primary test — it is what catches a transfer that was
#' interrupted part way — and modification time the secondary one,
#' which catches a source replaced by a same-size file.  Time is
#' compared with a tolerance: FAT and exFAT store timestamps to the
#' nearest two seconds, so a copy onto a USB drive lands up to a
#' second away from its source and would otherwise be re-copied on
#' every run.  NTFS over SMB is exact and unaffected.
#'
#' @param bytes Numeric; the source's size, from `.path_bytes()`.
#' @param mtime Numeric; the source's time, from `.path_mtime()`.
#' @param dest Character; the destination path.
#' @param bundle Logical; is this a directory bundle?
#' @param tol Numeric; seconds of allowed drift.  Default 2.
#' @return `TRUE` when the destination matches and can be skipped.
#' @noRd
.copy_unchanged <- function(bytes, mtime, dest, bundle, tol = 2) {
  if (!file.exists(dest)) {
    return(FALSE)
  }
  # A bundle must still be a directory, and a plain file must not
  # have become one, or the copy that follows means something
  # different from the one the size was measured for.
  if (!identical(isTRUE(bundle), dir.exists(dest))) {
    return(FALSE)
  }
  have_bytes <- .path_bytes(dest, bundle)
  if (is.na(have_bytes) || is.na(bytes) || have_bytes != bytes) {
    return(FALSE)
  }
  have_mtime <- .path_mtime(dest, bundle)
  if (is.na(have_mtime) || is.na(mtime)) {
    return(FALSE)
  }
  abs(have_mtime - mtime) <= tol
}


# 5. Copying ----------------------------------------------------

#' Copy one file or one bundle, returning why it failed
#'
#' `file.copy()` warns and returns `FALSE` rather than erroring, and
#' the warning carries the reason — permission, disk space, a name
#' the filesystem will not take — which the logical alone does not.
#' It is caught here so the reasons can be summarised once at the
#' end instead of one warning per file.
#'
#' `overwrite = TRUE` is always passed: this function is only
#' reached for a file the caller has already decided to copy, and
#' `overwrite = FALSE` would refuse a stale destination and report
#' it as a failure rather than replacing it.
#'
#' `copy.date = TRUE` is what makes `.copy_unchanged()` work on the
#' next run.  Without it every copy is stamped with the current
#' time, never matches its source, and the skip test never fires.
#'
#' @param src Character; a single source path.
#' @param dest Character; a single destination path.
#' @param bundle Logical; copy recursively and replace wholesale.
#' @return A list of `ok` (logical) and `reason` (character, `NA`
#'   on success).
#' @noRd
.copy_one <- function(src, dest, bundle) {
  reason <- NA_character_
  ok     <- FALSE

  # The destination must be free, or already the same kind of thing
  # as the source.  A plain file whose path is held by a directory
  # is the case that matters: file.copy() treats a `to` that is a
  # directory as a folder to copy *into*, so it would report success
  # having written the file one level too deep.  Guessing which the
  # caller meant is worse than saying so.
  if (file.exists(dest) &&
        !identical(isTRUE(bundle), dir.exists(dest))) {
    return(list(
      ok     = FALSE,
      reason = if (isTRUE(bundle)) {
        "a file of that name is in the way"
      } else {
        "a directory of that name is in the way"
      }
    ))
  }

  withCallingHandlers(
    {
      if (isTRUE(bundle)) {
        # Replaced wholesale rather than merged: a merge leaves any
        # internal table the new geodatabase does not have, and a
        # .gdb carrying a stale a0000000X.gdbtable is corrupt, not
        # merely out of date.
        if (dir.exists(dest)) {
          unlink(dest, recursive = TRUE)
        }
        # A recursive copy places the folder *inside* `to`, so the
        # destination's parent is what is passed.
        ok <- file.copy(src, .parent_dir(dest), recursive = TRUE,
                        copy.date = TRUE)
      } else {
        ok <- file.copy(src, dest, overwrite = TRUE,
                        copy.date = TRUE)
      }
    },
    warning = function(w) {
      reason <<- conditionMessage(w)
      invokeRestart("muffleWarning")
    }
  )
  list(ok = isTRUE(ok), reason = reason)
}


#' Report the files that could not be copied, in one warning
#'
#' One warning per file buries the summary for a layer of any size,
#' so the count leads and the first few are named.  The full list is
#' in the returned manifest.
#'
#' @param plan The copy plan, with `status` filled in.
#' @param reason Character; failure reasons, `NA` where none.
#' @param dest Character; the destination root.
#' @return `NULL`, invisibly.
#' @noRd
.warn_failures <- function(plan, reason, dest) {
  bad <- which(plan$status == "failed")
  why <- ifelse(is.na(reason[bad]), "unknown reason", reason[bad])
  txt <- paste0(basename(plan$destination[bad]), " (", why, ")")

  warning(
    .plural(length(bad), "file"), " could not be copied to ", dest,
    ":\n  ", paste(utils::head(txt, 3), collapse = "\n  "),
    if (length(bad) > 3) {
      paste0("\n  ... and ", length(bad) - 3, " more")
    },
    "\nThe `status` column of the returned manifest lists them all. ",
    "Check free space and write permission on the destination, then ",
    "re-run: files already copied are skipped.",
    call. = FALSE
  )
  invisible(NULL)
}


# 6. Verification and the copy log ------------------------------

#' Checksum one file, or a bundle's contents as a whole
#'
#' A geodatabase has no single file to hash, so its internals are
#' hashed individually and the sorted `name  hash` lines hashed in
#' turn.  Sorting by the path relative to the bundle keeps the
#' result independent of the order the filesystem lists them in, so
#' a source and its copy agree.
#'
#' md5 is used to detect a truncated or corrupted transfer, which is
#' what it is good for here; it is not a guard against deliberate
#' tampering.
#'
#' @param path Character; a single file or bundle path.
#' @param bundle Logical; is this a directory bundle?
#' @return A length-one md5 string, or `NA` if unreadable.
#' @noRd
.md5_of <- function(path, bundle) {
  if (!isTRUE(bundle)) {
    return(unname(tools::md5sum(path)))
  }
  inner <- list.files(path, recursive = TRUE, full.names = TRUE)
  if (!length(inner)) {
    return(NA_character_)
  }
  rel <- vapply(.norm_path(inner), .relative_to, character(1),
                root = .norm_path(path), USE.NAMES = FALSE)
  ord <- order(rel)
  txt <- paste0(rel[ord], "  ", unname(tools::md5sum(inner[ord])))

  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  writeLines(txt, tmp)
  unname(tools::md5sum(tmp))
}


#' Check a copy against its source on size and checksum
#'
#' Size is checked first because it is free and catches the common
#' failure — a transfer that stopped part way.  The checksum then
#' catches the rarer one, a file of the right length whose contents
#' are wrong.
#'
#' @param src Character; the source path.
#' @param dst Character; the destination path.
#' @param bytes Numeric; the source size measured before the copy.
#' @param bundle Logical; is this a directory bundle?
#' @return A list of `verdict` (`"ok"` or why not) and `md5` (the
#'   source checksum, for the log).
#' @noRd
.verify_copy <- function(src, dst, bytes, bundle) {
  if (!file.exists(dst)) {
    return(list(verdict = "missing after copy", md5 = NA_character_))
  }
  have <- .path_bytes(dst, bundle)
  if (is.na(have) || is.na(bytes) || have != bytes) {
    return(list(
      verdict = paste0("size mismatch (", have, " vs ", bytes,
                       " bytes)"),
      md5     = NA_character_
    ))
  }

  src_md5 <- .md5_of(src, bundle)
  dst_md5 <- .md5_of(dst, bundle)
  if (is.na(src_md5) || is.na(dst_md5)) {
    return(list(verdict = "checksum unreadable", md5 = src_md5))
  }
  if (!identical(src_md5, dst_md5)) {
    return(list(verdict = "checksum mismatch", md5 = src_md5))
  }
  list(verdict = "ok", md5 = src_md5)
}


#' Append a record of this copy to the layer's download log
#'
#' The log travels with the data, like the readme beside it: it says
#' where the files came from, when, and on what evidence they are
#' believed to be intact.  A copy whose provenance lives only in the
#' console scrollback has none by the time anyone asks.
#'
#' Each run appends a block rather than replacing the file, so a
#' layer topped up over several sessions keeps its whole history.
#'
#' @param plan The finished copy plan.
#' @param row The resolved manifest row.
#' @param dest Character; the destination root.
#' @param path Character; where to write the log.
#' @param elapsed Numeric; seconds spent copying and verifying.
#' @param verify Logical; were checksums taken?
#' @param root Character; the share the copy came from.
#' @return `TRUE` if the log was written, `FALSE` otherwise.
#' @noRd
.write_copy_log <- function(plan, row, dest, path, elapsed, verify,
                            root) {
  rule <- strrep("=", 64)
  thin <- strrep("-", 64)
  done <- plan$status == "copied"
  bad  <- plan$status == "failed"

  head_lines <- c(
    rule,
    "sciSpatialR download log",
    rule,
    "",
    .log_field("Layer", row$id),
    .log_field("Title", row$title),
    .log_field("Source", row$path),
    .log_field("Destination", .parent_dir(path)),
    .log_field("Share", root),
    .log_field("Downloaded",
               format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    .log_field("By", unname(Sys.info()[["user"]])),
    .log_field("Package", paste(
      "sciSpatialR",
      as.character(utils::packageVersion("sciSpatialR"))
    )),
    .log_field("R", R.version.string),
    .log_field("Elapsed", .fmt_elapsed(elapsed)),
    .log_field("Verified", if (isTRUE(verify)) {
      "size and md5 checksum against the source"
    } else {
      "not checked (verify = FALSE)"
    }),
    ""
  )

  fmt <- "%-8s %-10s %14s  %-32s %s"
  file_lines <- c(
    "FILES", thin,
    sprintf(fmt, "status", "verified", "bytes", "md5", "file"),
    sprintf(fmt,
            plan$status,
            ifelse(is.na(plan$verified), "-", plan$verified),
            format(plan$bytes, scientific = FALSE, trim = TRUE),
            ifelse(is.na(plan$md5), "-", plan$md5),
            vapply(plan$destination, .relative_to, character(1),
                   root = dest, USE.NAMES = FALSE)),
    ""
  )

  verdict <- if (any(bad)) {
    paste0(.plural(sum(bad), "file"),
           " did NOT copy cleanly - see the status column above.")
  } else if (isTRUE(verify) && any(done)) {
    paste0("All ", .plural(sum(done), "file"),
           " match their source on size and md5 checksum.")
  } else if (any(done)) {
    paste0(.plural(sum(done), "file"),
           " copied; contents not checked (verify = FALSE).")
  } else {
    "Nothing was copied; every file was already up to date."
  }

  bytes <- sum(plan$bytes[done], na.rm = TRUE)
  tail_lines <- c(
    "SUMMARY", thin,
    paste0(sum(done), " copied, ", sum(plan$status == "skipped"),
           " already up to date, ", sum(bad), " failed"),
    paste0(.fmt_bytes(bytes), " in ", .fmt_elapsed(elapsed),
           if (bytes > 0 && elapsed > 0) {
             paste0(" (", .fmt_bytes(bytes / elapsed), "/s)")
           }),
    verdict,
    "", ""
  )

  ok <- tryCatch(
    {
      con <- file(path, open = if (file.exists(path)) "at" else "wt")
      on.exit(close(con), add = TRUE)
      writeLines(c(head_lines, file_lines, tail_lines), con)
      TRUE
    },
    error = function(e) FALSE
  )
  if (!isTRUE(ok)) {
    warning("Could not write the copy log to ", path, "\n",
            "The files themselves copied; only the receipt is ",
            "missing.", call. = FALSE)
  }
  ok
}


#' One `Label: value` line of the log header
#' @noRd
.log_field <- function(label, value) {
  if (is.null(value) || !length(value) || is.na(value)) {
    value <- "-"
  }
  paste0(formatC(paste0(label, ":"), width = -14), value)
}


#' Format an elapsed time in seconds for a person to read
#' @noRd
.fmt_elapsed <- function(secs) {
  if (!is.finite(secs)) {
    return("-")
  }
  if (secs < 60) {
    return(paste0(round(secs, 1), "s"))
  }
  mins <- floor(secs / 60)
  if (mins < 60) {
    return(paste0(mins, "m ", round(secs - mins * 60), "s"))
  }
  hrs <- floor(mins / 60)
  paste0(hrs, "h ", mins - hrs * 60, "m")
}


# 7. Output helpers ---------------------------------------------

#' Drop the working columns and attach the run's attributes
#'
#' `mtime` and `bundle` exist to decide the copy, not to describe
#' it, so they are not part of what is returned.
#'
#' @param plan The copy plan.
#' @param row The resolved manifest row.
#' @param dest Character; the destination root.
#' @param dry_run Logical; was anything written?
#' @return A `data.frame` with the documented columns.
#' @noRd
.finish_plan <- function(plan, row, dest, dry_run) {
  # A dry run, and a run that copied nothing, return before the
  # verification step ever adds these, so they are filled in here
  # rather than left for the caller to find missing.
  for (nm in c("verified", "md5")) {
    if (is.null(plan[[nm]])) {
      plan[[nm]] <- NA_character_
    }
  }
  out <- plan[, c("source", "destination", "bytes", "part",
                  "status", "verified", "md5"), drop = FALSE]
  rownames(out) <- NULL
  structure(out, layer = row$id, dest = dest, dry_run = dry_run)
}


#' Format a byte count for a progress message
#'
#' @param n Numeric; bytes.
#' @return A length-one string such as `"1.4 GB"`.
#' @noRd
.fmt_bytes <- function(n) {
  n <- sum(n, na.rm = TRUE)
  units <- c("B", "KB", "MB", "GB", "TB")
  i <- if (n <= 0) 1 else min(floor(log(n, 1024)) + 1, length(units))
  if (i == 1) {
    paste0(round(n), " B")
  } else {
    paste0(round(n / 1024^(i - 1), 1), " ", units[i])
  }
}


#' Print the copy plan as a table
#'
#' Destinations are shown relative to `dest`, which is already named
#' in the message above the table and would otherwise repeat on
#' every row.
#'
#' @param plan The copy plan, with `status` filled in.
#' @param dest Character; the destination root.
#' @return `NULL`, invisibly.
#' @noRd
.print_copy_plan <- function(plan, dest) {
  if (!nrow(plan)) {
    cat("Nothing to copy.\n")
    return(invisible(NULL))
  }
  view <- data.frame(
    file   = vapply(plan$destination, .relative_to, character(1),
                    root = dest, USE.NAMES = FALSE),
    size   = vapply(plan$bytes, .fmt_bytes, character(1),
                    USE.NAMES = FALSE),
    part   = plan$part,
    status = plan$status,
    stringsAsFactors = FALSE
  )
  print(view, row.names = FALSE, right = FALSE)
  invisible(NULL)
}

# End of script ----
