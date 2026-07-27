# datalib_surveys -- enumerate survey folders for a country

#' Enumerate survey folders for a country
#'
#' Lists the `<CCC>_<YYYY>_<SSSS>` survey folders of one country, mirroring
#' Stata `_svycheck` with real lists and counts (no sentinels). Inputs are
#' trimmed and uppercased once at the boundary; the country is matched
#' exactly against folder names (never substring). Folders that do not
#' follow the three-token grammar are skipped.
#'
#' @param country Country code (e.g. `"MWI"`). Trimmed and uppercased once;
#'   matched exactly against country folder names (never substring).
#' @param root Library root path. When `NULL`, resolved by [datalib_root()]
#'   in contract precedence order: explicit argument, then the
#'   `DATALIB_ROOT` environment variable, then `option(datalib.root)`, then
#'   the `datalib:` key in the user block of `~/.config/user_config.yml`.
#' @param survey Optional survey acronym filter (e.g. `"MICS6"`). Trimmed
#'   and uppercased once; rows must match it exactly.
#' @param year Optional survey year filter (integer or string); rows must
#'   match it exactly.
#'
#' @return A data.frame with one row per survey folder and columns:
#'   \describe{
#'     \item{country}{character; uppercased country code.}
#'     \item{year}{integer; survey year from the folder name.}
#'     \item{survey}{character; uppercased survey acronym.}
#'     \item{folder}{character; on-disk folder name.}
#'   }
#'   When any row has a non-missing year, the attributes `latest_year`
#'   (integer) and `latest_survey` (character) identify the numerically
#'   latest year and its survey -- numeric maximum, never listing order.
#'   Zero rows when nothing matches.
#'
#' @examples
#' \dontrun{
#' datalib_surveys("MWI")
#' datalib_surveys("MWI", survey = "MICS6")
#' s <- datalib_surveys("MWI")
#' attr(s, "latest_year")
#' }
#' @export
datalib_surveys <- function(country, root = NULL, survey = NULL, year = NULL) {
  root <- datalib_root(root)
  if (!nz_arg(country)) err_input("country must be specified.")
  country <- toupper(trimws(as.character(country)))
  cdirs <- dl_list_dirs(root)
  chit <- cdirs[toupper(cdirs) == country]
  if (!length(chit)) {
    err_not_found(sprintf("Country %s not found in datalib (%s).", country, root))
  }
  flist <- dl_list_dirs(fs::path(root, chit[1]))

  out <- data.frame(
    country = character(0), year = integer(0), survey = character(0),
    folder = character(0), stringsAsFactors = FALSE
  )
  for (f in flist) {
    toks <- strsplit(toupper(f), "_", fixed = TRUE)[[1]]
    if (length(toks) != 3L) next
    out <- rbind(out, data.frame(
      country = country,
      year = suppressWarnings(as.integer(toks[2])),
      survey = toks[3],
      folder = f,
      stringsAsFactors = FALSE
    ))
  }
  if (nz_arg(survey)) {
    out <- out[out$survey == toupper(trimws(as.character(survey))), , drop = FALSE]
  }
  if (nz_arg(year)) {
    yi <- suppressWarnings(as.integer(year))
    out <- out[!is.na(out$year) & out$year == yi, , drop = FALSE]
  }
  rownames(out) <- NULL
  if (nrow(out) && any(!is.na(out$year))) {
    ly <- max(out$year, na.rm = TRUE)
    attr(out, "latest_year") <- ly
    attr(out, "latest_survey") <- out$survey[which(out$year == ly)[1]]
  }
  out
}
