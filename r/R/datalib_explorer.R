# datalib_explorer -- inspect one node of an arbitrary folder tree

#' Inspect one node of any folder tree
#'
#' Reports the contents of a single directory, whether or not it belongs to a
#' datalib library. Every other navigation function in this package
#' reconstructs a folder's ancestry from its own *name* --
#' [datalib_browse()] rebuilds `CCC/CCC_YYYY_SURVEY/` by counting
#' underscores -- which is correct inside the naming grammar and useless
#' outside it: a folder called `raw datasets` says nothing about which survey
#' it belongs to. `datalib_explorer()` applies no library test and no name
#' parsing; the only precondition is that the directory exists.
#'
#' @section Difference from the Stata implementation:
#' Stata's `datalib_explorer` prints a *clickable* SMCL listing, and that
#' half does not port: there is no console hyperlink in R. What ports is the
#' data, which was always the substantive half -- the Stata version's own
#' documentation calls its `r()` surface "as much the point as the display".
#' Where a Stata user clicks a folder, an R user calls this function again
#' with a longer `path`, which the returned `dirs` supports directly. The
#' file-type dispatch behind Stata's hyperlinks is reported here as
#' `open_with`, so a caller can act on it without reimplementing it.
#'
#' @param path Node to inspect, relative to `root`, used **exactly** as
#'   given: no case folding, no separator guessing. `NULL` (default) inspects
#'   the root itself. Forward and backward slashes are both accepted.
#' @param root Tree to walk. Defaults to [datalib_root()], but unlike every
#'   other function here it does **not** require that root to be a library.
#' @param sizes Measure each file's size. `FALSE` by default: a size needs
#'   an `file.info()` call per file, and on the network share this package
#'   targets that costs about 1.4 seconds each. When `FALSE` the `bytes`
#'   column is `NA` rather than 0, because 0 is a real size.
#' @param max_items Cap on how many folders and how many files are returned.
#'   Default 400. `n_dirs` and `n_files` always report the *true* totals, and
#'   `truncated` says when the cap bit.
#'
#' @return A list with:
#'   \describe{
#'     \item{root, path, fullpath, parent}{character. `parent` is `"."` at
#'       depth 1 and `""` at the root.}
#'     \item{depth}{integer, 0 at the root.}
#'     \item{dirs, files}{character vectors, original casing, capped at
#'       `max_items`.}
#'     \item{n_dirs, n_files}{integer, the true totals.}
#'     \item{exts, n_exts}{distinct extensions among the files returned,
#'       lowercased and dot-free; `"none"` for a file without one.}
#'     \item{bytes, largest, largest_bytes}{`NA` unless `sizes = TRUE`.}
#'     \item{is_empty, truncated, looks_grammar}{logical.}
#'     \item{open_with}{a data.frame of `file`, `ext` and `kind`
#'       (`describe`/`view`/`open`), the same dispatch Stata's hyperlinks
#'       use.}
#'   }
#'
#' @seealso [datalib_index()] to walk a whole subtree into a data.frame
#'   instead of one node into a list.
#'
#' @examples
#' \dontrun{
#' node <- datalib_explorer(root = "<staging-tree>")
#' node$n_dirs
#' # descend: what a Stata user does by clicking
#' datalib_explorer("Afghanistan", root = "<staging-tree>")
#' }
#' @export
datalib_explorer <- function(path = NULL, root = NULL, sizes = FALSE,
                             max_items = 400L) {
  if (!is.numeric(max_items) || length(max_items) != 1L || max_items < 1) {
    err_input("`max_items` must be a single positive number.")
  }
  max_items <- as.integer(max_items)

  # Deliberately NOT via the library test. dl_islib is precisely the gate this
  # function exists to bypass, so the root is taken as given.
  r <- root %||% dl_explorer_root()
  r <- dl_explorer_norm(r)

  rel <- dl_explorer_rel(path)
  full <- if (nzchar(rel)) file.path(r, rel) else r

  if (!dir.exists(full)) {
    err_not_found(paste0(
      "Not a directory: ", full,
      if (nzchar(rel)) {
        " (`path` is relative to `root` and is used exactly as given)"
      } else ""
    ))
  }

  dirs_all <- dl_list_dirs(full)
  files_all <- dl_list_files(full)
  n_dirs <- length(dirs_all)
  n_files <- length(files_all)

  truncated <- n_dirs > max_items || n_files > max_items
  dirs <- utils::head(dirs_all, max_items)
  files <- utils::head(files_all, max_items)

  exts <- dl_file_ext(files)
  bytes <- NA_real_
  largest <- NA_character_
  largest_bytes <- NA_real_
  if (isTRUE(sizes) && length(files)) {
    sz <- file.info(file.path(full, files))$size
    sz[is.na(sz)] <- 0
    bytes <- sum(sz)
    largest <- files[which.max(sz)]
    largest_bytes <- max(sz)
  } else if (isTRUE(sizes)) {
    bytes <- 0
    largest_bytes <- 0
  }

  depth <- if (nzchar(rel)) length(strsplit(rel, "/", fixed = TRUE)[[1]]) else 0L
  parent <- ""
  if (depth == 1L) {
    parent <- "."
  } else if (depth > 1L) {
    parent <- sub("/[^/]+$", "", rel)
  }
  leaf <- if (nzchar(rel)) basename(rel) else basename(r)

  list(
    root = r,
    path = rel,
    fullpath = full,
    parent = parent,
    depth = depth,
    dirs = dirs,
    n_dirs = n_dirs,
    files = files,
    n_files = n_files,
    exts = sort(unique(exts)),
    n_exts = length(unique(exts)),
    bytes = bytes,
    largest = largest,
    largest_bytes = largest_bytes,
    is_empty = n_dirs == 0L && n_files == 0L,
    truncated = truncated,
    looks_grammar = dl_looks_grammar(leaf),
    open_with = data.frame(
      file = files,
      ext = exts,
      kind = dl_file_kind(exts),
      stringsAsFactors = FALSE
    )
  )
}
