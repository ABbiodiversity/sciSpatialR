# ---
# title: Snapshot the catalogue for the vignette and the README
# author: Brendan Casey
# created: 2026-08-16
# inputs:
#   //ABMI-DATA2/science/spatial_data/ - the ABMI science share,
#     scanned by build_catalogue()
# outputs:
#   vignettes/catalogue_snapshot.rds - display-ready table of the
#     scan, plus scanned_on and align attributes, committed
#   README.md - the same table spliced between the
#     <!-- catalogue-table --> markers in the Catalogue section
# notes:
#   The catalogue vignette cannot call build_catalogue() when the
#   package is built or checked: the share is not reachable from a
#   build machine.  Most of that vignette therefore shows pasted
#   console transcripts, but the manifest itself is worth rendering
#   as a real table, so this script freezes one scan to disk.  The
#   vignette reads the snapshot back and passes it to kable(); the
#   README gets the same table written in as markdown, since it is
#   plain .md with no knitting step of its own.
#
#   The snapshot is stored display-ready -- character columns, the
#   headings the table prints, missing fields left NA -- so both
#   call sites render it without repeating the formatting.  The
#   free-text template fields (abstract, lineage, citation) are
#   dropped: they run to paragraphs, and shipping them inside the
#   package would cost far more than the table shows.
#
#   Run manually from the package root, on the ABMI network, after
#   readmes change enough that the table looks stale, then re-render
#   docs/ with render_docs.R.  The console transcripts in
#   vignettes/catalogue.Rmd are still pasted by hand -- check them
#   in the same pass, since nothing keeps them in step.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(sciSpatialR) # build_catalogue() (version: 0.1.0)
library(knitr) # kable() renders the markdown table (version: 1.50)

## 1.2 Define paths ----
rds_file <- "vignettes/catalogue_snapshot.rds"
readme_file <- "README.md"

# The README table is spliced between these two lines, which stay
# in the file; everything between them is rewritten.
marker_start <- "<!-- catalogue-table:start -->"
marker_end <- "<!-- catalogue-table:end -->"

# 2. Scan the share ----
# refresh = TRUE so a manifest cached earlier in the session cannot
# be frozen into the snapshot by mistake.

catalogue <- build_catalogue(refresh = TRUE, quiet = FALSE)

stopifnot(nrow(catalogue) > 0)

# 3. Build the display table ----
# Numbers are formatted here rather than by kable's format.args,
# which would also group the digits of the years.

num <- function(x, digits) {
  out <- formatC(x, format = "f", digits = digits, big.mark = ",")
  out[is.na(x)] <- NA_character_
  out
}

snapshot <- data.frame(
  theme = catalogue$theme,
  name = catalogue$name,
  title = catalogue$title,
  year = as.character(catalogue$year),
  "res (m)" = num(catalogue$resolution_m, 2),
  type = catalogue$data_type,
  "size (MB)" = num(catalogue$size_mb, 1),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

# scanned_on lets both call sites date the table they print, so a
# reader can tell how old the snapshot is without opening this
# script.  align travels with the table for the same reason.
attr(snapshot, "scanned_on") <- as.character(Sys.Date())
attr(snapshot, "align") <- c("l", "l", "l", "r", "r", "l", "r")

# 4. Write the snapshot ----

saveRDS(snapshot, rds_file, compress = "xz")

message(
  "wrote: ", rds_file, " (", nrow(snapshot), " layers, ",
  round(file.size(rds_file) / 1024, 1), " KB)"
)

# 5. Splice the table into the README ----
# knitr.kable.NA prints unfilled readme fields as empty cells
# rather than as "NA".

old <- options(knitr.kable.NA = "")
table_md <- kable(
  snapshot,
  format = "pipe",
  row.names = FALSE,
  align = attr(snapshot, "align")
)
options(old)

readme <- readLines(readme_file, encoding = "UTF-8")
at_start <- which(readme == marker_start)
at_end <- which(readme == marker_end)

if (length(at_start) != 1L || length(at_end) != 1L ||
  at_end <= at_start) {
  stop(
    "README.md needs exactly one ", marker_start, " line followed ",
    "by one ", marker_end, " line; add them to the Catalogue ",
    "section before running this script."
  )
}

block <- c(
  marker_start,
  "",
  as.character(table_md),
  "",
  paste0(
    "*Scanned ", attr(snapshot, "scanned_on"), " from ",
    "`\\\\ABMI-DATA2\\science\\spatial_data`. Regenerate with ",
    "[`data-raw/make_catalogue_snapshot.R`]",
    "(data-raw/make_catalogue_snapshot.R).*"
  ),
  "",
  marker_end
)

writeLines(
  c(
    readme[seq_len(at_start - 1L)],
    block,
    readme[seq(at_end + 1L, length(readme))]
  ),
  readme_file,
  useBytes = TRUE
)

message("wrote: ", readme_file, " (catalogue table spliced in)")

# End of script ----
