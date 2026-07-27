# datalib_vintages -- enumerate vintage folders of one survey

#' Enumerate vintage folders of one survey
#'
#' Lists every vintage folder (masters and adaptations) of one survey,
#' mirroring Stata `_vcheck` with integer vintage columns (no MMAA
#' encoding). Inputs are trimmed and uppercased once at the boundary and
#' matched exactly against folder names; folders that do not follow the
#' contract-v1 vintage grammar are skipped.
#'
#' `is_latest` is the NUMERIC maximum (`v10` > `v09`, never alphabetical or
#' listing order): among masters for master rows, and per
#' `(master_version, collection)` group for adaptation rows.
#'
#' @param country Country code (e.g. `"MWI"`). Trimmed and uppercased once;
#'   matched exactly against country folder names (never substring).
#' @param year Survey year, an integer (or integer-like string) such as
#'   `2019`.
#' @param survey Survey acronym (e.g. `"MICS6"`). Trimmed and uppercased
#'   once; the survey folder `<CCC>_<YYYY>_<SSSS>` must match exactly.
#' @param root Library root path. When `NULL`, resolved by [datalib_root()]
#'   in contract precedence order: explicit argument, then the
#'   `DATALIB_ROOT` environment variable, then `option(datalib.root)`, then
#'   the `datalib:` key in the user block of `~/.config/user_config.yml`.
#'
#' @return A data.frame with one row per vintage folder and columns:
#'   \describe{
#'     \item{folder}{character; on-disk vintage folder name.}
#'     \item{kind}{character; `"master"` or `"adaptation"`.}
#'     \item{master_version}{integer; master vintage number.}
#'     \item{adaptation_version}{integer; adaptation vintage number
#'       (`NA` for masters).}
#'     \item{collection}{character; collection code (`NA` for masters).}
#'     \item{is_latest}{logical; numerically latest within its group (see
#'       Details).}
#'   }
#'   Zero rows when the survey has no grammar-conforming vintages.
#'
#' @examples
#' \dontrun{
#' v <- datalib_vintages("MWI", 2019, "MICS6")
#' v[v$is_latest, ]
#' }
#' @export
datalib_vintages <- function(country, year, survey, root = NULL) {
  root <- datalib_root(root)
  if (!nz_arg(country) || !nz_arg(year) || !nz_arg(survey)) {
    err_input("country, year, and survey must be specified.")
  }
  country <- toupper(trimws(as.character(country)))
  survey <- toupper(trimws(as.character(survey)))
  yi <- suppressWarnings(as.integer(trimws(as.character(year))))
  if (is.na(yi)) err_input("year must be an integer year such as 2019.")

  cdirs <- dl_list_dirs(root)
  chit <- cdirs[toupper(cdirs) == country]
  if (!length(chit)) {
    err_not_found(sprintf("Country %s not found in datalib (%s).", country, root))
  }
  svyfld <- paste(country, yi, survey, sep = "_")
  sdirs <- dl_list_dirs(fs::path(root, chit[1]))
  shit <- sdirs[toupper(sdirs) == svyfld]
  if (!length(shit)) {
    err_not_found(sprintf("Survey folder %s not found.", svyfld))
  }
  vdirs <- dl_list_dirs(fs::path(root, chit[1], shit[1]))
  vdirs <- vdirs[startsWith(toupper(vdirs), paste0(svyfld, "_"))]

  out <- data.frame(
    folder = character(0), kind = character(0), master_version = integer(0),
    adaptation_version = integer(0), collection = character(0),
    is_latest = logical(0), stringsAsFactors = FALSE
  )
  for (v in vdirs) {
    p <- parse_vintage_folder(v)
    if (is.null(p)) next
    out <- rbind(out, data.frame(
      folder = v, kind = p$kind, master_version = p$master_version,
      adaptation_version = p$adaptation_version, collection = p$collection,
      is_latest = FALSE, stringsAsFactors = FALSE
    ))
  }
  if (nrow(out)) {
    m <- out$kind == "master"
    if (any(m)) {
      out$is_latest[m] <- !is.na(out$master_version[m]) &
        out$master_version[m] == max(out$master_version[m], na.rm = TRUE)
    }
    a <- which(out$kind == "adaptation")
    for (i in a) {
      grp <- a[out$collection[a] == out$collection[i] &
                 out$master_version[a] == out$master_version[i]]
      out$is_latest[i] <- !is.na(out$adaptation_version[i]) &&
        out$adaptation_version[i] == max(out$adaptation_version[grp], na.rm = TRUE)
    }
  }
  rownames(out) <- NULL
  out
}
