# CLAUDE.md

Conventions for Claude Code when working across these ABMI
biodiversity-modelling repositories (species distribution models,
biodiversity indicators, geospatial workflows). Adapted from
[`bgcasey/code_standards`](https://github.com/bgcasey/code_standards) —
personal coding conventions followed across projects to keep work
consistent and reproducible.

The goal is reproducible, reviewable, well-documented code that a
colleague — or future me — can pick up, run, and build on without
re-tracing the reasoning. Every project is unique; where a project
deviates from these conventions, note the change and the reasoning so
it's clear later.

> **How to use this file:** Follow these conventions by default. When a
> repository's own `README.md`, `.Rproj`, or a local override says
> something different, the repository wins — note the deviation and the
> reason.
>
> **Templates are canonical in `code_standards`.** The template excerpts
> embedded below are trimmed for reference and can drift; treat
> `templates/` in the standards repo as the source of truth, and prefer
> the `new_r_module()` helper (§5.6) to scaffold from the live version.

---

## 1. Project context

Typical stack and outputs across these projects:

- **R** — `tidyverse`, `terra`, `sf`, `gbm` / `dismo` (`gbm.step`),
  plus modelling/validation helpers. Primary language.
- **Python** — `pandas`, `numpy`, ArcPy, geospatial libraries.
- **Google Earth Engine (JavaScript)** — covariate extraction and web
  app deployment.
- **Remote sensing inputs** — Landsat, Sentinel, MODIS, LiDAR.
- **Core outputs** — spatial predictions, maps, models, figures,
  tables, manuscripts, and documentation.

**Pipeline flow (general):** clean & format data (R) → extract spatial
covariates (R & GEE) → train & validate models → export deliverables to
`3_output/`.

---

## 2. Repository structure

Place files according to this structure. Match an existing project's
layout when one is already established. New repos are scaffolded from
[`bgcasey/project_template`](https://github.com/bgcasey/project_template)
via GitHub's **"Use this template"** button.

| Directory              | Purpose                                                 |
| ---------------------- | ------------------------------------------------------- |
| `0_data/external/`     | Raw, unmodified data from external sources. Never overwrite. |
| `0_data/processed/`    | Cleaned, analysis-ready data.                           |
| `1_code/r/`            | R scripts and function files (+ `r_module.R`, `r_function.R`). |
| `1_code/python/`       | Python scripts and function files.                      |
| `1_code/javascript/`   | JavaScript / GEE scripts and function files.            |
| `2_pipeline/`          | Intermediate files — logs, checkpoints, partial outputs. |
| `3_output/<version>/`  | Top-level version folder (e.g., `v0.1/`, `v0.2/`) preserving each results iteration. |
| `3_output/<version>/data/`    | Final data products.                             |
| `3_output/<version>/figures/` | Publication-ready figures.                       |
| `3_output/<version>/maps/`    | Map products and GIS layers.                     |
| `3_output/<version>/models/`  | Final model objects, predictions, performance metrics. |
| `3_output/<version>/tables/`  | Summary and statistical tables.                  |
| `4_writing/`           | Manuscripts (`manuscript/`) and reports (`reports/`).   |
| `README.md`            | Project overview, setup, dependencies, and run order.   |

**Rules of thumb:**

- `1_code/` is grouped by language (`r/`, `python/`, `javascript/`); add
  others (e.g., `bash/`) as needed.
- Read intermediate files from `2_pipeline/` rather than regenerating
  heavy outputs; don't clutter `0_data/` or `3_output/` with temporary
  work.
- `0_data/` and `2_pipeline/` are generally `.gitignore`d. Don't assume
  data files will be committed; refer to them by relative path.
- Anything meant to be archived, shared, or cited belongs in
  `3_output/`, grouped under a top-level version folder (e.g.,
  `v0.1/`, `v0.2/`). Increment the version when outputs are
  regenerated so prior results stay intact.
- Each `README.md` opens with two [shields.io](https://shields.io/)
  badges — a **status** badge and a **languages** badge.

---

## 3. Naming conventions

- **Files:** meaningful names, no special characters, **`snake_case`**
  (lowercase, underscore-separated). Objects too: concise, descriptive,
  consistent (`bird_data`, `pred_var`) — not `df1`, `x`, `tmp`.
- **Run order (single-level):** prefix scripts with numbers so
  execution order is obvious. Sufficient for small projects.

  ```
  00_process_response_data.R
  01_process_predictor_data.R
  09_generalized_linear_mixed_models.R
  10_visualize_results.R
  ```

- **Run order (two-level `MM_NN`):** for larger pipelines, prefix by
  **stage** (`MM`) and **step within stage** (`NN`). Example SDM stages:

  | `MM` | Stage                       | Purpose                                          |
  | ---- | --------------------------- | ------------------------------------------------ |
  | `01` | Data Acquisition & Cleaning | Bring in and clean response data                 |
  | `02` | Spatial Data Prep           | Process rasters, LiDAR, remote sensing data      |
  | `03` | Model Setup                 | Prep modelling inputs and cross-validation blocks |
  | `04` | Modelling                   | Fit models, summarize results, predict           |
  | `05` | Validation                  | Evaluate with independent / stratified field data |

  ```
  01_01_fetch_bird_data_from_WildTrax.R
  01_02_clean_bird_data.R
  02_01_mosaic_rasters.R
  02_05_calculate_lidar_derivatives.R
  03_02_define_spatio_temporal_blocks.R
  04_01_modelling_pipeline.R
  04_03_global_spatial_predictions.R
  05_02_validate_model_with_field_data.R
  ```

- **Files outside the processing sequence** (utilities, constants,
  shared config) get **no numeric prefix**. Either place them in a named
  subfolder (`utils/`, `shared/`, `common/`), or use a neutral prefix
  (`00_utils.R`, `99_constants.R`) if they must sit in the main script
  directory.

---

## 4. Code style

- Style R per the
  [tidyverse style guide](https://style.tidyverse.org/index.html)
  (Google's R style guide builds on it); PEP 8 for Python; keep
  JavaScript consistent and readable.
- **Line width: 70 characters** for readability, so code isn't cropped
  when printed or displayed. Break long or complex function arguments
  onto separate lines.
- Spaces after commas; a space after `()` in functions; inner spaces in
  `{{ }}`; spaces around operators (`==`, `+`, `-`, `<-`, etc.). For
  curly brackets `{}`, end a line with `{` and start a line with `}`.
- Use `<-` for assignment (not `=`). Default to `%>%` for pipes in R
  unless a project standardizes on `|>`.
- Comments begin with `#` followed by a space and explain **why**, not
  just what — purpose, inputs, outputs, rationale.
- No commented-out, unused, or duplicate code in committed files.
- Auto-format R with `styler`:

  ```r
  library(styler)
  styler::style_file("file/path/file.R", style = tidyverse_style)
  ```

---

## 5. Script headers, sections, and templates

### 5.1 Header

Every script starts with a header:

| Field       | Content                                                     |
| ----------- | ----------------------------------------------------------- |
| **Title**   | Brief, descriptive name summarizing the script's purpose.   |
| **Author**  | Person or team responsible.                                 |
| **Date**    | Creation / last-modification date, `YYYY-MM-DD` (written as `created:` in the template). |
| **Inputs**  | Required input files, paths, formats, or parameters.        |
| **Outputs** | Files produced — names, formats, what they represent.       |
| **Notes**   | What the code does, key details, and proposed future improvements. |

### 5.2 Body

- Divide into **numbered, foldable sections** with descriptive headings
  (`# 1. Setup ----`, `## 1.1 Load packages ----`,
  `### 1.1.1 … ----`). Four trailing dashes (`----`) create sections
  navigable in RStudio's *Jump To* menu.
- Section 1 is always **Setup**: load packages (comment what each is
  for; note versions for reproducibility) then import data.
- Under each heading, a short comment describing the section's purpose,
  its inputs, main steps, and output.
- End R modules with `# End of script ----`.

### 5.3 R module template

```r
# ---
# title: [Title]
# author: [Your Name]
# created: [YYYY-MM-DD]
# inputs: [list the required input files]
# outputs: [list the output files produced by the script]
# notes:
#   [A concise explanation of what the code does, its purpose,
#   and any important details about its function. You can also use
#   this section to list proposed improvements for the code for
#   future iterations.]
# ---

# 1. Setup ----

## 1.1 Load packages ----
# Include comments for what the packages are used for.
# Specify the package version for reproducibility.
library(tidyverse) # data manipulation, visualization (version: 1.3.1)
library(lubridate) # manipulating date times (version: 1.7.10)

## 1.2 Import data ----
# Describe the data being loaded
# data <- read.csv("path/to/your/data.csv")

# 2. [heading] ----
# [briefly describe this section, its purpose, data or object
# inputs, the main steps or processes, and outputs].

## 2.1 [subheading] ----

# (Sections 3+ repeat the same numbered pattern.)

# End of script ----
```

### 5.4 R function template (roxygen2)

```r
#' [Title of the Function]
#'
#' [Brief description of what the function does]
#'
#' @param [param_name] [Type and description of the parameter]
#' @param [param_name] [Type and description of the parameter]
#' @return [Description of the return value or object]
#'
#' @example # Example usage of the function
#' [Example data]
#' [Example function call]
#' [Example result printing]
[function_name] <- function([param1], [param2],
                            [param3] = [default_value],
                            [param4]) {
  # [Step 1: Description of what this step does]
  [code for step 1]

  # [Step 2: Description of what this step does]
  [code for step 2]

  # (Further steps follow the same pattern.)

  return([result])
}
```

### 5.5 Python and JavaScript

Same header + numbered-section structure. Full templates live in
`templates/` (`python_module.py`, `python_function.py`,
`javascript_module.js`, `javascript_function.js`).

- **Python** — module header in a triple-quoted `--- … ---` block;
  numbered sections (`# 1. Setup`, `## 1.1 Import Required Libraries`)
  with versioned import comments; document functions with **numpydoc**
  docstrings (`Parameters`, `Returns`, `Examples`) and an
  `if __name__ == "__main__":` usage example.
- **GEE / JavaScript** — module header in a `/* --- … --- */` block;
  numbered sections in block comments (Setup → processing → Export
  Outputs); document functions with **JSDoc** (`@param {Type}`,
  `@return`, `@example`). GEE function files export via
  `exports.functionName = function functionName(...) { … }`.

### 5.6 Scaffolding new R scripts

New R scripts can be created from the canonical `r_module.R` template
using a `new_r_module()` helper added to your global `.Rprofile`
(`file.edit("~/.Rprofile")`). It downloads the current template from
`raw.githubusercontent.com/bgcasey/code_standards/main/templates/r_module.R`
and opens the new file:

```r
new_r_module("my_new_script.R")
```

See the `code_standards` README for the full function definition.

---

## 6. Working principles

> *Extends beyond `code_standards`.* These are personal working
> principles, not part of the standards repo — a candidate for the
> global `~/.claude/CLAUDE.md` if you'd rather keep this file purely to
> code standards.

Accuracy and epistemic transparency come first.

- **Never fabricate** citations, datasets, packages, function
  arguments, parameters, or results. If a reference is needed but
  unknown, write `[citation needed]`.
- State **uncertainty explicitly**; don't paper over gaps with plausible
  guesses.
- When a task requires assumptions, add a short **Assumptions** section
  and proceed on the stated assumptions rather than stalling.
- For methodological or statistical choices, note **alternatives and
  pitfalls**; avoid presenting one approach as universally correct. Flag
  contested methods or interpretations that warrant deeper verification.
- For non-trivial methodological answers, include a **Confidence**
  indicator (High / Moderate / Low); for Moderate or Low, add a one-line
  rationale.
- **Ask clarifying questions** before proceeding on ambiguous or open
  writing/analysis tasks.
- Use **Canadian English** spelling.
- Validate inputs (type, length, `NA`s) and outputs; handle edge cases;
  keep the environment and dependencies reproducible and documented.

---

## 7. Code review protocol

Reviews set the standard code is held to, and double as a checklist when
reviewing others' code. Assess five areas:

1. **Code formatting** — consistency in style, naming, readability
   (tidyverse style, ≤70-char lines, descriptive `snake_case` names, no
   dead code, logical ordering).
2. **Project structure** — files and folders follow the conventions in
   this guide (`snake_case` names with numeric prefixes, `0_data/`,
   `1_code/` grouped by language `r/`/`python/`, `2_pipeline/`,
   `3_output/`, `4_writing/`, `README.md`, appropriate repo visibility).
3. **Functional correctness** — runs without errors and produces valid
   results (input validation, edge cases, reproducible environment,
   validated outputs, informative logging/error handling).
4. **Efficiency** — scales appropriately and avoids unnecessary work
   (no redundant computation, appropriate data structures,
   parallel/batch where suitable, function reuse).
5. **Intelligibility** — clear, documented, easy to understand (header
   present, modular single-purpose units, comments explain *why*,
   complete docs, code in the right location, logical numbered flow).

**Output format:**

1. A concise summary — key findings and overall status.
2. A markdown table:

| Section | Standard | Meets | Needs Improvement | Not Met | Comments |
| ------- | -------- | ----- | ----------------- | ------- | -------- |

---

## 8. New-script checklist

Before finishing a new or edited script, confirm:

- [ ] Header complete (Title, Author, Date, Inputs, Outputs, Notes).
- [ ] Numbered, foldable sections with descriptive `----` headings.
- [ ] Setup section loads packages (with version comments) and imports
      data.
- [ ] Correct location and `snake_case` naming (numeric prefix if
      run-order matters; `MM_NN` for staged pipelines).
- [ ] Styled to the guide; ≤70-char lines; no dead code.
- [ ] Functions documented (roxygen / numpydoc / JSDoc) with an example.
- [ ] Inputs validated, outputs checked, paths relative.
- [ ] `README.md` updated if inputs, outputs, or run order changed.