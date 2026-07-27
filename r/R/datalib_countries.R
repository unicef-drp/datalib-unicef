# datalib_countries -- enumerate countries in the library

#' Enumerate countries in the library
#'
#' Lists the country folders directly under the library root, mirroring
#' Stata `_ctrycheck`: one row per country folder, uppercased, unique, in
#' directory-listing order.
#'
#' @param root Library root path. When `NULL`, resolved by [datalib_root()]
#'   in contract precedence order: explicit argument, then the
#'   `DATALIB_ROOT` environment variable, then `option(datalib.root)`, then
#'   the `datalib:` key in the user block of `~/.config/user_config.yml`.
#'
#' @return A data.frame with a single column:
#'   \describe{
#'     \item{country}{character; unique uppercased country folder names.}
#'   }
#'   Zero rows when the root has no country folders.
#'
#' @examples
#' \dontrun{
#' datalib_countries()
#' datalib_countries(root = "C:/data/library")
#' }
#' @export
datalib_countries <- function(root = NULL) {
  root <- datalib_root(root)
  dirs <- dl_list_dirs(root)
  data.frame(country = unique(toupper(dirs)), stringsAsFactors = FALSE)
}
