# datalib_files -- list the files of one vintage section

#' List the files of one vintage section
#'
#' Lists the files of one section (`Data/Stata`, `Data/Original`, `Data/R`,
#' `Data/Other`, `Doc`, or `Programs`) of a resolved vintage, replacing Stata
#' `_foldernav`'s DATA/DOC/PROGRAMS branches with a plain data.frame: one row
#' per file. The vintage itself is resolved with [datalib_resolve()] under
#' contract-v1 semantics (uppercase-once normalization, exact matching,
#' numeric latest defaults). Section names are shared across the three
#' implementations.
#'
#' For `section = "data"`, the `module` column carries the module suffix
#' parsed from `<vintage-stem>_<module>.dta` (`NA` when the file does not
#' follow the grammar); `module` is `NA` outside the data section.
#'
#' @param country Country code (e.g. `"MWI"`). Trimmed and uppercased once;
#'   matched exactly against country folder names (never substring).
#' @param year Survey year (integer or string). When `NULL`, the
#'   numerically latest year among the country's matching survey folders.
#' @param survey Survey acronym (e.g. `"MICS6"`). Trimmed and uppercased
#'   once; survey folders match on the exact suffix `_<SURVEY>` (never
#'   substring). When `NULL`, taken from the numerically latest survey-year
#'   folder.
#' @param section Which vintage section to list: `"data"` (default,
#'   `Data/Stata`), `"data-original"` (`Data/Original`), `"data-r"`
#'   (`Data/R`), `"data-other"` (`Data/Other`), `"doc"` (`Doc`), or
#'   `"programs"` (`Programs`).
#' @param kind `"master"` or `"adaptation"`. Defaults to `"adaptation"`.
#' @param collection Adaptation collection code (e.g. `"HLT"`, the default
#'   when `kind = "adaptation"`). Trimmed and uppercased once; applies only
#'   to adaptations.
#' @param master_version Master vintage, accepted as `1`, `"01"`, `"v01"`,
#'   or `"V01"`. When `NULL`, the numerically latest master on disk
#'   (numeric maximum, never alphabetical or listing order).
#' @param adaptation_version Adaptation vintage, same spellings. When
#'   `NULL`, the numerically latest adaptation of the requested collection
#'   under the chosen master.
#' @param root Library root path. When `NULL`, resolved by [datalib_root()]
#'   in contract precedence order: explicit argument, then the
#'   `DATALIB_ROOT` environment variable, then `option(datalib.root)`, then
#'   the `datalib:` key in the user block of `~/.config/user_config.yml`.
#'
#' @return A data.frame with one row per file and columns:
#'   \describe{
#'     \item{file}{character; file name as on disk.}
#'     \item{module}{character; module suffix for grammar-conforming `.dta`
#'       files in the data section, otherwise `NA`.}
#'     \item{path}{character; absolute path to the file.}
#'     \item{section}{character; the requested section.}
#'   }
#'   Zero rows when the section is empty or missing.
#'
#' @examples
#' \dontrun{
#' datalib_files("MWI", 2019, "MICS6")                      # data files
#' datalib_files("MWI", 2019, "MICS6", section = "doc")     # documentation
#' datalib_files("MWI", kind = "master", section = "programs")
#' }
#' @export
datalib_files <- function(country, year = NULL, survey = NULL,
                          section = c("data", "data-original", "data-r",
                                      "data-other", "doc", "programs"),
                          kind = NULL, collection = NULL,
                          master_version = NULL, adaptation_version = NULL,
                          root = NULL) {
  section <- match.arg(tolower(section[1]),
                       c("data", "data-original", "data-r", "data-other",
                         "doc", "programs"))
  res <- datalib_resolve(
    country = country, year = year, survey = survey, kind = kind,
    collection = collection, master_version = master_version,
    adaptation_version = adaptation_version, root = root
  )
  dir <- switch(section,
    "data"          = res$data_stata,
    "data-original" = res$data_original,
    "data-r"        = res$data_r,
    "data-other"    = res$data_other,
    "doc"           = res$doc,
    "programs"      = res$programs
  )
  files <- dl_list_files(dir)
  mods <- rep(NA_character_, length(files))
  if (section == "data" && length(files)) {
    prefix <- paste0(res$file_stem, "_")
    is_mod <- startsWith(files, prefix) & grepl("\\.dta$", files, ignore.case = TRUE)
    mods[is_mod] <- sub("\\.dta$", "",
                        substring(files[is_mod], nchar(prefix) + 1L),
                        ignore.case = TRUE)
  }
  data.frame(
    file = files,
    module = mods,
    path = if (length(files)) as.character(fs::path(dir, files)) else character(0),
    section = rep(section, length(files)),
    stringsAsFactors = FALSE
  )
}
