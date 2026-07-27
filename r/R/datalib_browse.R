# datalib_browse -- programmatic library navigation (choices only, v0.1)

#' Browse the library tree programmatically
#'
#' Programmatic library navigation (choices only, v0.1). Replaces Stata
#' `_foldernav`'s stateful SMCL click-chain with an explicit node: every
#' call returns a data.frame of choices; pass a returned `path` back as
#' `path =` to descend. No interactive menu in v0.1.
#'
#' With no arguments, lists the country folders under the resolved root.
#' With `country`, lists that country's survey folders (country is trimmed
#' and uppercased once, then matched exactly against folder names). With
#' `path`, lists the sub-directories and files of that node, classifying
#' each directory by the contract-v1 folder grammar.
#'
#' @param country Country code (e.g. `"MWI"`). Trimmed and uppercased once;
#'   matched exactly against country folder names (never substring).
#'   Ignored when `path` is given.
#' @param path An absolute path previously returned in the `path` column;
#'   when given, its children are listed and `country` is ignored.
#' @param root Library root path. When `NULL`, resolved by [datalib_root()]
#'   in contract precedence order: explicit argument, then the
#'   `DATALIB_ROOT` environment variable, then `option(datalib.root)`, then
#'   the `datalib:` key in the user block of `~/.config/user_config.yml`.
#'   Ignored when `path` is given.
#'
#' @return A data.frame with one row per choice and columns:
#'   \describe{
#'     \item{name}{character; display name (directories uppercased, file
#'       names verbatim).}
#'     \item{kind}{character; one of `"country"`, `"survey"`, `"vintage"`,
#'       `"section"` (`Data`/`Doc`/`Programs`/`Original`/`Stata`/`R`/`Other`),
#'       `"folder"`, or `"file"`.}
#'     \item{path}{character; absolute path to pass back as `path =`.}
#'   }
#'   Zero rows when the node is empty.
#'
#' @examples
#' \dontrun{
#' datalib_browse()                          # countries under the root
#' datalib_browse("MWI")                     # MWI survey folders
#' node <- datalib_browse("MWI")
#' datalib_browse(path = node$path[1])       # descend one level
#' }
#' @export
datalib_browse <- function(country = NULL, path = NULL, root = NULL) {
  choices <- function(name, kind, path) {
    data.frame(name = name, kind = kind, path = path, stringsAsFactors = FALSE)
  }
  empty <- choices(character(0), character(0), character(0))

  if (nz_arg(path)) {
    node <- as.character(fs::path_norm(fs::path_expand(path)))
    if (!fs::dir_exists(node)) {
      err_not_found(sprintf("Path not found: %s", path))
    }
    dirs <- dl_list_dirs(node)
    files <- dl_list_files(node)
    classify <- function(d) {
      if (!is.null(parse_vintage_folder(d))) return("vintage")
      toks <- strsplit(toupper(d), "_", fixed = TRUE)[[1]]
      if (length(toks) == 3L) return("survey")
      if (toupper(d) %in% c("DATA", "DOC", "PROGRAMS", "ORIGINAL", "STATA", "R", "OTHER")) {
        return("section")
      }
      "folder"
    }
    out <- empty
    if (length(dirs)) {
      out <- rbind(out, choices(
        toupper(dirs),
        vapply(dirs, classify, character(1)),
        as.character(fs::path(node, dirs))
      ))
    }
    if (length(files)) {
      out <- rbind(out, choices(
        files, rep("file", length(files)),
        as.character(fs::path(node, files))
      ))
    }
    rownames(out) <- NULL
    return(out)
  }

  root <- datalib_root(root)
  if (!nz_arg(country)) {
    dirs <- dl_list_dirs(root)
    if (!length(dirs)) return(empty)
    return(choices(toupper(dirs), rep("country", length(dirs)),
                   as.character(fs::path(root, dirs))))
  }

  country <- toupper(trimws(as.character(country)))
  cdirs <- dl_list_dirs(root)
  chit <- cdirs[toupper(cdirs) == country]
  if (!length(chit)) {
    err_not_found(sprintf("Country %s not found in datalib (%s).", country, root))
  }
  dirs <- dl_list_dirs(fs::path(root, chit[1]))
  if (!length(dirs)) return(empty)
  choices(toupper(dirs), rep("survey", length(dirs)),
          as.character(fs::path(root, chit[1], dirs)))
}
