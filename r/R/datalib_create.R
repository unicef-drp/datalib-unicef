# datalib_create -- vintage-tree creator (check-mode by default)

#' Create (or preview) a vintage folder tree
#'
#' Vintage-tree creator, check-mode by default. Mirrors
#' `stata/d/datalib_create.ado`: without `create = TRUE` it only reports the
#' paths that WOULD be made (zero side effects); with `create = TRUE` it
#' builds `<vintage>/{Data/{Original,Stata,R,Other},Doc,Programs}`.
#'
#' Inputs are trimmed and uppercased once at the boundary (contract v1).
#' Unlike [datalib_resolve()], vintages default to `v01` for creation (not
#' the latest on disk), and `kind` defaults to `"adaptation"` when a
#' `collection` is given, `"master"` otherwise.
#'
#' @param country Country code (e.g. `"MWI"`). Trimmed and uppercased once.
#' @param year Survey year, an integer (or integer-like string) such as
#'   `2019`.
#' @param survey Survey acronym (e.g. `"MICS6"`). Trimmed and uppercased
#'   once.
#' @param kind `"master"` or `"adaptation"`. When `NULL`, defaults to
#'   `"adaptation"` when `collection` is given, `"master"` otherwise.
#' @param collection Adaptation collection code (e.g. `"HLT"`). Trimmed and
#'   uppercased once. Required when `kind = "adaptation"`.
#' @param master_version Master vintage, accepted as `1`, `"01"`, `"v01"`,
#'   or `"V01"` (normalized to the `v%02d` display form). Defaults to
#'   `"v01"` when omitted.
#' @param adaptation_version Adaptation vintage, same spellings as
#'   `master_version`. Defaults to `"v01"` when omitted (adaptations only).
#' @param root Library root path. When `NULL`, resolved by [datalib_root()]
#'   in contract precedence order: explicit argument, then the
#'   `DATALIB_ROOT` environment variable, then `option(datalib.root)`, then
#'   the `datalib:` key in the user block of `~/.config/user_config.yml`.
#' @param create Logical; when `TRUE` the folder tree is created on disk.
#'   The default `FALSE` is a dry run that only reports paths.
#'
#' @return A named list:
#'   \describe{
#'     \item{root}{character; resolved library root.}
#'     \item{survey_folder}{character; `<CCC>_<YYYY>_<SSSS>` folder name.}
#'     \item{vintage_folder}{character; vintage folder name per the
#'       contract grammar.}
#'     \item{paths}{named list of character paths: `path`, `data`,
#'       `data_original`, `data_stata`, `data_r`, `data_other`, `doc`,
#'       `programs`.}
#'     \item{created}{logical; `TRUE` when this call created the tree.}
#'     \item{existed}{logical; `TRUE` when the vintage folder already
#'       existed before the call.}
#'   }
#'
#' Errors with condition class `datalib_error_input` (Stata 198) on invalid
#' input.
#'
#' @examples
#' \dontrun{
#' # dry run: report the paths that would be created
#' datalib_create("MWI", 2019, "MICS6", collection = "HLT")
#' # actually create a master vintage tree
#' datalib_create("MWI", 2019, "MICS6", kind = "master", create = TRUE)
#' }
#' @export
datalib_create <- function(country, year, survey, kind = NULL,
                           collection = NULL, master_version = NULL,
                           adaptation_version = NULL, root = NULL,
                           create = FALSE) {
  root <- datalib_root(root)
  if (!nz_arg(country) || !nz_arg(year) || !nz_arg(survey)) {
    err_input("country, year, and survey must be specified.")
  }
  country <- toupper(trimws(as.character(country)))
  survey <- toupper(trimws(as.character(survey)))
  collection <- if (nz_arg(collection)) toupper(trimws(as.character(collection))) else ""
  kind <- if (nz_arg(kind)) {
    tolower(trimws(as.character(kind)))
  } else if (collection != "") {
    "adaptation"
  } else {
    "master"
  }
  if (!kind %in% c("master", "adaptation")) {
    err_input("kind must be master or adaptation.")
  }
  if (kind == "adaptation" && collection == "") {
    err_input("kind = adaptation requires collection.")
  }
  yi <- suppressWarnings(as.integer(trimws(as.character(year))))
  if (is.na(yi)) err_input("year must be an integer year such as 2019.")

  mv <- if (nz_arg(master_version)) format_version(master_version, "master_version") else "v01"
  av <- if (kind == "adaptation") {
    if (nz_arg(adaptation_version)) format_version(adaptation_version, "adaptation_version") else "v01"
  } else {
    ""
  }

  svyfld <- paste(country, yi, survey, sep = "_")
  vfolder <- if (kind == "adaptation") {
    paste0(svyfld, "_", mv, "_M_", av, "_A_", collection)
  } else {
    paste0(svyfld, "_", mv, "_M")
  }
  base <- fs::path(root, country, svyfld, vfolder)
  existed <- fs::dir_exists(base)

  paths <- list(
    path = as.character(base),
    data = as.character(fs::path(base, "Data")),
    data_original = as.character(fs::path(base, "Data", "Original")),
    data_stata = as.character(fs::path(base, "Data", "Stata")),
    data_r = as.character(fs::path(base, "Data", "R")),
    data_other = as.character(fs::path(base, "Data", "Other")),
    doc = as.character(fs::path(base, "Doc")),
    programs = as.character(fs::path(base, "Programs"))
  )

  created <- FALSE
  if (isTRUE(create)) {
    for (p in paths[c("data_original", "data_stata", "data_r", "data_other",
                      "doc", "programs")]) {
      fs::dir_create(p, recurse = TRUE)
    }
    created <- !existed
  }

  list(
    root = as.character(root),
    survey_folder = svyfld,
    vintage_folder = vfolder,
    paths = paths,
    created = created,
    existed = as.logical(existed)
  )
}
