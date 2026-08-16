# ---
# title: Snapshot the catalogue for the catalogue vignette
# author: Brendan Casey
# created: 2026-08-16
# inputs:
#   //ABMI-DATA2/science/spatial_data/ - the ABMI science share,
#     scanned by build_catalogue()
# outputs:
#   vignettes/catalogue_snapshot.rds - manifest of the scan, plus a
#     scanned_on attribute, committed
# notes:
#   The catalogue vignette cannot call build_catalogue() when the
#   package is built or checked: the share is not reachable from a
#   build machine.  Most of that vignette therefore shows pasted
#   console transcripts, but the manifest itself is worth rendering
#   as a real table, so this script freezes one scan to disk and the
#   vignette reads it back.
#
#   The snapshot is trimmed to the columns the vignette tabulates.
#   The free-text template fields (abstract, lineage, citation) are
#   dropped: they run to paragraphs, and shipping them inside the
#   package would cost far more than the table shows.
#
#   Run manually from the package root, on the ABMI network, after
#   readmes change enough that the vignette's table looks stale.
#   Refresh the transcripts in vignettes/catalogue.Rmd in the same
#   pass -- nothing keeps them in step automatically.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(sciSpatialR) # build_catalogue() (version: 0.1.0)

## 1.2 Define paths ----
out_file <- "vignettes/catalogue_snapshot.rds"

# Columns the vignette tabulates, in the order it prints them.
keep_cols <- c(
  "id", "name", "theme", "title", "year", "resolution_m",
  "n_files", "size_mb", "data_type"
)

# 2. Scan the share ----
# refresh = TRUE so a manifest cached earlier in the session cannot
# be frozen into the snapshot by mistake.

catalogue <- build_catalogue(refresh = TRUE, quiet = FALSE)

stopifnot(nrow(catalogue) > 0, all(keep_cols %in% names(catalogue)))

# 3. Trim and record the scan date ----
# scanned_on lets the vignette date the table it prints, so a reader
# can tell how old the snapshot is without opening this script.

snapshot <- catalogue[, keep_cols]
row.names(snapshot) <- NULL
attr(snapshot, "scanned_on") <- as.character(Sys.Date())

# 4. Write ----

saveRDS(snapshot, out_file, compress = "xz")

message(
  "wrote: ", out_file, " (", nrow(snapshot), " layers, ",
  round(file.size(out_file) / 1024, 1), " KB)"
)

# End of script ----
