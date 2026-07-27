# datalib_adaptations -- enumerate adaptations of one survey

#' Enumerate adaptations of one survey
#'
#' Lists every adaptation vintage folder of one survey: the rows of
#' [datalib_vintages()] with `kind == "adaptation"`. Mirrors Stata
#' `_adaptcheck` with a zero-row data.frame instead of the `"0"` sentinel.
#' Inputs are trimmed and uppercased once at the boundary and matched
#' exactly against folder names (contract v1, `config/grammar.md`).
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
#' @return A data.frame with one row per adaptation vintage folder and
#'   columns:
#'   \describe{
#'     \item{collection}{character; adaptation collection code (e.g. `"HLT"`).}
#'     \item{master_version}{integer; master vintage the adaptation builds on.}
#'     \item{adaptation_version}{integer; adaptation vintage number.}
#'     \item{folder}{character; on-disk vintage folder name.}
#'   }
#'   Zero rows when the survey has no adaptations.
#'
#' @examples
#' \dontrun{
#' datalib_adaptations("MWI", 2019, "MICS6")
#' datalib_adaptations("mwi", "2019", "mics6", root = "C:/data/library")
#' }
#' @export
datalib_adaptations <- function(country, year, survey, root = NULL) {
  v <- datalib_vintages(country, year, survey, root = root)
  out <- v[v$kind == "adaptation",
           c("collection", "master_version", "adaptation_version", "folder"),
           drop = FALSE]
  rownames(out) <- NULL
  out
}
