# datalib_resolve -- contract v1 path resolution (pure; touches no data)

#' Resolve a survey vintage to folder names and paths
#'
#' Contract-v1 path resolution (pure; touches no data), mirroring
#' `stata/d/datalib_resolve.ado`:
#'
#' * inputs are trimmed and uppercased ONCE at the boundary (`kind` is
#'   lowercased);
#' * country folders match exactly; survey folders match on the exact
#'   suffix `_<SURVEY>` -- never substring;
#' * "latest" defaults for year, master vintage and adaptation vintage are
#'   the NUMERIC maximum (`v10` > `v09`), never alphabetical or
#'   directory-listing order;
#' * the resolved vintage folder is verified to exist before returning.
#'
#' @param country Country code (e.g. `"MWI"`). Trimmed and uppercased once;
#'   matched exactly against country folder names (never substring).
#' @param year Survey year (integer or string). When `NULL`, the
#'   numerically latest year among the country's matching survey folders.
#' @param survey Survey acronym (e.g. `"MICS6"`). Trimmed and uppercased
#'   once; survey folders match on the exact suffix `_<SURVEY>` (never
#'   substring). When `NULL`, taken from the numerically latest survey-year
#'   folder.
#' @param kind `"master"` or `"adaptation"`. Defaults to `"adaptation"`.
#' @param collection Adaptation collection code (e.g. `"HLT"`, the default
#'   when `kind = "adaptation"`). Trimmed and uppercased once; passing it
#'   with `kind = "master"` is an error.
#' @param master_version Master vintage, accepted as `1`, `"01"`, `"v01"`,
#'   or `"V01"` (normalized to the `v%02d` display form). When `NULL`, the
#'   numerically latest master on disk.
#' @param adaptation_version Adaptation vintage, same spellings. When
#'   `NULL`, the numerically latest adaptation of the requested collection
#'   under the chosen master.
#' @param root Library root path. When `NULL`, resolved by [datalib_root()]
#'   in contract precedence order: explicit argument, then the
#'   `DATALIB_ROOT` environment variable, then `option(datalib.root)`, then
#'   the `datalib:` key in the user block of `~/.config/user_config.yml`.
#'
#' @return A named list (folder NAMES, like Stata, plus absolute paths):
#'   \describe{
#'     \item{root}{character; resolved library root.}
#'     \item{country}{character; uppercased country code.}
#'     \item{year}{integer; resolved survey year.}
#'     \item{survey}{character; uppercased survey acronym.}
#'     \item{kind}{character; `"master"` or `"adaptation"`.}
#'     \item{collection}{character; collection code (`NA` for masters).}
#'     \item{master_version}{integer; resolved master vintage.}
#'     \item{adaptation_version}{integer; resolved adaptation vintage
#'       (`NA` for masters).}
#'     \item{survey_folder}{character; `<CCC>_<YYYY>_<SSSS>` folder name.}
#'     \item{vintage_folder}{character; resolved vintage folder name.}
#'     \item{file_stem}{character; prefix of module files
#'       (`<vintage_folder>` under contract v1).}
#'     \item{path}{character; absolute path of the vintage folder.}
#'     \item{data_stata, data_original, data_r, data_other}{character;
#'       absolute paths of the `Data/Stata`, `Data/Original`, `Data/R`, and
#'       `Data/Other` sections.}
#'     \item{doc, programs}{character; absolute paths of `Doc/` and
#'       `Programs/`.}
#'   }
#'
#' Errors with condition class `datalib_error_input` (Stata 198) on invalid
#' input or when the country, survey, or vintage folder is not found.
#'
#' @examples
#' \dontrun{
#' # latest HLT adaptation of the latest master
#' datalib_resolve("MWI", 2019, "MICS6")
#' # explicit master vintage
#' datalib_resolve("mwi", 2019, "mics6", kind = "master",
#'                 master_version = "v01")
#' # latest year for the country ("latest" is numeric, never alphabetical)
#' datalib_resolve("MWI", survey = "MICS6", collection = "HLT")
#' }
#' @export
datalib_resolve <- function(country, year = NULL, survey = NULL, kind = NULL,
                            collection = NULL, master_version = NULL,
                            adaptation_version = NULL, root = NULL) {
  root <- datalib_root(root)

  # ---- normalize inputs once at the boundary ----
  if (!nz_arg(country)) err_input("country must be specified.")
  country <- toupper(trimws(as.character(country)))
  survey <- if (nz_arg(survey)) toupper(trimws(as.character(survey))) else ""
  collection <- if (nz_arg(collection)) toupper(trimws(as.character(collection))) else ""
  kind <- if (nz_arg(kind)) tolower(trimws(as.character(kind))) else "adaptation"
  if (!kind %in% c("master", "adaptation")) {
    err_input("kind must be master or adaptation.")
  }
  if (kind == "adaptation" && collection == "") collection <- "HLT"
  if (kind == "master" && collection != "") {
    err_input("collection applies only to kind = adaptation.")
  }
  mv <- if (nz_arg(master_version)) format_version(master_version, "master_version") else ""
  av <- if (nz_arg(adaptation_version)) format_version(adaptation_version, "adaptation_version") else ""
  if (nz_arg(year)) {
    yi <- suppressWarnings(as.integer(trimws(as.character(year))))
    if (is.na(yi)) err_input("year must be an integer year such as 2019.")
    year <- as.character(yi)
  } else {
    year <- ""
  }

  # ---- country: exact folder match ----
  cdirs <- dl_list_dirs(root)
  chit <- cdirs[toupper(cdirs) == country]
  if (!length(chit)) {
    err_not_found(sprintf("Country %s not found in datalib (%s).", country, root))
  }
  cpath <- fs::path(root, chit[1])

  # ---- survey folders (exact suffix), latest-year default ----
  all_svy <- dl_list_dirs(cpath)
  if (survey != "") {
    flist <- all_svy[endsWith(toupper(all_svy), paste0("_", survey))]
  } else {
    flist <- all_svy
  }
  if (!length(flist)) {
    err_input(sprintf("%s for %s not available.", survey, country))
  }
  folder_year <- function(f) {
    suppressWarnings(as.integer(strsplit(toupper(f), "_", fixed = TRUE)[[1]][2]))
  }
  if (survey == "") {
    # pick numerically latest year, then that folder's survey
    yrs <- vapply(flist, folder_year, integer(1))
    if (all(is.na(yrs))) {
      err_input(sprintf("Could not determine the survey year for %s.", country))
    }
    pick <- which.max(ifelse(is.na(yrs), -1L, yrs))
    survey <- strsplit(toupper(flist[pick]), "_", fixed = TRUE)[[1]][3]
    if (year == "") year <- as.character(yrs[pick])
  }
  if (year == "") {
    yrs <- vapply(flist, folder_year, integer(1))
    if (all(is.na(yrs))) {
      err_input(sprintf("Could not determine the survey year for %s.", country))
    }
    year <- as.character(max(yrs, na.rm = TRUE))
  }

  svyfld <- paste(country, year, survey, sep = "_")
  shit <- all_svy[toupper(all_svy) == svyfld]
  if (!length(shit)) {
    err_not_found(sprintf("Survey folder %s not found.", svyfld))
  }
  spath <- fs::path(cpath, shit[1])

  # ---- vintage defaults: numeric latest on disk ----
  vdirs <- dl_list_dirs(spath)
  vdirs <- vdirs[startsWith(toupper(vdirs), paste0(svyfld, "_"))]
  parsed <- lapply(vdirs, parse_vintage_folder)
  if (mv == "") {
    best <- -1L
    for (p in parsed) {
      if (!is.null(p) && p$kind == "master" && !is.na(p$master_version) &&
          p$master_version > best) {
        best <- p$master_version
      }
    }
    if (best < 0L) {
      err_input(sprintf("No master vintage found under %s.", svyfld))
    }
    mv <- sprintf("v%02d", best)
  }
  mv_int <- as.integer(sub("^v", "", mv))
  if (kind == "adaptation" && av == "") {
    best <- -1L
    for (p in parsed) {
      if (!is.null(p) && p$kind == "adaptation" && !is.na(p$adaptation_version) &&
          identical(p$master_version, mv_int) && identical(p$collection, collection) &&
          p$adaptation_version > best) {
        best <- p$adaptation_version
      }
    }
    if (best < 0L) {
      err_input(sprintf(
        "No %s adaptation found under %s for master %s.", collection, svyfld, mv
      ))
    }
    av <- sprintf("v%02d", best)
  }

  # ---- vintage folder + existence check ----
  vfolder <- if (kind == "adaptation") {
    paste0(svyfld, "_", mv, "_M_", av, "_A_", collection)
  } else {
    paste0(svyfld, "_", mv, "_M")
  }
  vhit <- vdirs[toupper(vdirs) == toupper(vfolder)]
  if (!length(vhit)) {
    err_not_found(sprintf("Vintage folder %s not found under %s.", vfolder, svyfld))
  }
  base <- fs::path(spath, vhit[1])

  list(
    root = as.character(root),
    country = country,
    year = as.integer(year),
    survey = survey,
    kind = kind,
    collection = if (kind == "adaptation") collection else NA_character_,
    master_version = mv_int,
    adaptation_version = if (av == "") NA_integer_ else as.integer(sub("^v", "", av)),
    survey_folder = svyfld,
    vintage_folder = vfolder,
    file_stem = vfolder,
    path = as.character(base),
    data_stata = as.character(fs::path(base, "Data", "Stata")),
    data_original = as.character(fs::path(base, "Data", "Original")),
    data_r = as.character(fs::path(base, "Data", "R")),
    data_other = as.character(fs::path(base, "Data", "Other")),
    doc = as.character(fs::path(base, "Doc")),
    programs = as.character(fs::path(base, "Programs"))
  )
}
