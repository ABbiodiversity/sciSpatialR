# ---
# title: Render vignettes to GitHub-readable markdown
# author: Brendan Casey
# created: 2026-08-13
# inputs:
#   vignettes/*.Rmd - vignette sources
# outputs:
#   docs/<name>.md  - GitHub-flavoured markdown, committed
#   docs/<name>.html - local preview, gitignored
# notes:
#   GitHub renders .md but not .Rmd, so a vignette linked from the
#   README shows as source rather than as a formatted page.  This
#   script knits each vignette to github_document so the rendered
#   copy can be browsed in the repository.  Run manually from the
#   package root after editing a vignette; docs/ is in
#   .Rbuildignore, so the rendered copies never reach the built
#   package.
#
#   Vignette chunks are not evaluated (the catalogue reads the ABMI
#   share, which is unreachable at build time), so this needs no
#   network access -- only pandoc.
# ---

# 1. Setup ----

## 1.1 Load packages ----
library(rmarkdown) # knit Rmd to markdown (version: 2.29)

## 1.2 Locate pandoc ----
# rmarkdown checks RSTUDIO_PANDOC before PATH.  Fall back to the
# copy shipped inside RStudio's Quarto install so the script runs
# from a plain terminal session as well as the RStudio console.
if (!pandoc_available()) {
  bundled <- file.path(
    "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools"
  )
  if (dir.exists(bundled)) {
    Sys.setenv(RSTUDIO_PANDOC = bundled)
  }
}

if (!pandoc_available()) {
  stop(
    "pandoc not found; install it or set RSTUDIO_PANDOC to its ",
    "directory before running this script."
  )
}

# 2. Render ----
# Knit every vignette to docs/.  output_file is relative to the
# vignette's own directory, hence the "../docs" prefix.

dir.create("docs", showWarnings = FALSE)

vignettes <- list.files("vignettes", pattern = "[.]Rmd$")

for (v in vignettes) {
  render(
    file.path("vignettes", v),
    output_format = "github_document",
    output_file = file.path("../docs", sub("[.]Rmd$", ".md", v)),
    quiet = TRUE
  )
  message("rendered: docs/", sub("[.]Rmd$", ".md", v))
}

# End of script ----
