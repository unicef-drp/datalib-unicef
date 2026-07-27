# datalib_catalog -- one-pass tree scan of the whole library

#' Catalog every survey vintage in the library
#'
#' One-pass tree scan of the whole library: one row per survey vintage
#' (master or adaptation), mirroring Stata `datalib_catalog`. Folder names
#' are parsed with the contract-v1 `"_"`-split grammar
#' (`config/grammar.md`); folders that do not follow the grammar are
#' skipped. The optional `country` filter is trimmed and uppercased once
#' and matched exactly (never substring).
#'
#' @param root Library root path. When `NULL`, resolved by [datalib_root()]
#'   in contract precedence order: explicit argument, then the
#'   `DATALIB_ROOT` environment variable, then `option(datalib.root)`, then
#'   the `datalib:` key in the user block of `~/.config/user_config.yml`.
#' @param country Optional country code filter (e.g. `"MWI"`). Trimmed and
#'   uppercased once; matched exactly against country folder names. When
#'   `NULL`, all countries are scanned.
#'
#' @return A data.frame with one row per survey vintage, sorted by country,
#'   year, survey, kind, collection and version, with columns:
#'   \describe{
#'     \item{country}{character; uppercased country code.}
#'     \item{year}{integer; survey year from the folder name.}
#'     \item{survey}{character; uppercased survey acronym.}
#'     \item{kind}{character; `"master"` or `"adaptation"`.}
#'     \item{master_version}{integer; master vintage number.}
#'     \item{adaptation_version}{integer; adaptation vintage number
#'       (`NA` for masters).}
#'     \item{collection}{character; collection code (`NA` for masters).}
#'     \item{survey_folder}{character; on-disk survey folder name.}
#'     \item{vintage_folder}{character; on-disk vintage folder name.}
#'   }
#'   Zero rows when nothing matches.
#'
#' @examples
#' \dontrun{
#' datalib_catalog()                      # the whole library
#' datalib_catalog(country = "MWI")       # one country
#' datalib_catalog(root = "C:/data/library")
#' }
#' @export
datalib_catalog <- function(root = NULL, country = NULL) {
  root <- datalib_root(root)
  empty <- data.frame(
    country = character(0), year = integer(0), survey = character(0),
    kind = character(0), master_version = integer(0),
    adaptation_version = integer(0), collection = character(0),
    survey_folder = character(0), vintage_folder = character(0),
    stringsAsFactors = FALSE
  )
  clist <- dl_list_dirs(root)
  if (nz_arg(country)) {
    cc <- toupper(trimws(as.character(country)))
    clist <- clist[toupper(clist) == cc]
  }
  rows <- list()
  for (cc in clist) {
    slist <- dl_list_dirs(fs::path(root, cc))
    for (s in slist) {
      toks <- strsplit(toupper(s), "_", fixed = TRUE)[[1]]
      if (length(toks) != 3L) next
      yr <- suppressWarnings(as.integer(toks[2]))
      vlist <- dl_list_dirs(fs::path(root, cc, s))
      vlist <- vlist[startsWith(toupper(vlist), paste0(toupper(s), "_"))]
      for (v in vlist) {
        p <- parse_vintage_folder(v)
        if (is.null(p)) next
        rows[[length(rows) + 1L]] <- data.frame(
          country = toupper(cc), year = yr, survey = toks[3], kind = p$kind,
          master_version = p$master_version,
          adaptation_version = p$adaptation_version,
          collection = p$collection,
          survey_folder = s, vintage_folder = v,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  if (!length(rows)) return(empty)
  out <- do.call(rbind, rows)
  out <- out[order(out$country, out$year, out$survey, out$kind,
                   out$collection, out$master_version, out$adaptation_version,
                   na.last = TRUE), , drop = FALSE]
  rownames(out) <- NULL
  out
}
