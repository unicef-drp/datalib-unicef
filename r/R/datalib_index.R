# datalib_index -- walk a subtree recursively into a data.frame

#' Walk a subtree recursively into a data.frame
#'
#' Returns one row per file -- and with `dirs = TRUE` one per folder -- for a
#' whole branch of any folder tree, whether or not it follows the datalib
#' naming grammar. Where [datalib_explorer()] answers "what is in *this*
#' folder", this answers "what is in this whole branch", which is the form you
#' can `table()`, `merge()` or `write.csv()`.
#'
#' @section The cost is real, and it is not this code:
#' Measured on the network share this package targets, a recursive walk costs
#' about **0.35 seconds per folder**, near-constant across subtrees of very
#' different size (a large branch in about nine minutes; a mid-sized branch faster still; a small branch faster again). That is
#' SMB round-trip latency on each directory open, and a single bulk
#' enumeration is no faster -- PowerShell's `Get-ChildItem -Recurse` took
#' 538 s on the same subtree and found the same folders and files. There is no
#' fast path from one thread.
#'
#' So `max_nodes` defaults to 400 rather than infinity, and hitting it is
#' reported rather than silent: the `truncated` attribute is `TRUE` and the
#' result is a *prefix* of the subtree. For whole-archive work use the
#' scheduled catalogue, which pays the same per-folder cost in parallel and
#' off-hours and stores checksums this function deliberately does not compute.
#'
#' @section Difference from the Stata implementation:
#' None that matters. Stata's `datalib_index` returns a dataset and so does
#' this; the columns and their meanings are identical, which is what makes the
#' shared conformance cases possible. Stata prints progress because a
#' nine-minute walk needs feedback in an interactive console; here that is
#' `verbose`.
#'
#' @param path Subtree to start from, relative to `root`, used exactly as
#'   given. `NULL` walks from the root -- read the cost section first.
#' @param root Tree to walk; defaults to the configured datalib root. No
#'   library test is applied.
#' @param max_nodes Stop after this many folders. Default 400.
#' @param max_depth Stop descending past this depth; the children of the
#'   starting node are depth 1. `0` (default) means no limit.
#' @param dirs Also emit a row per folder. Folders are traversed and counted
#'   either way.
#' @param sizes Measure each file. Off by default; see the cost section.
#' @param pattern Optional regular expression; only files whose **name**
#'   matches are indexed. Folders are always traversed regardless, or the walk
#'   could not reach a nested match.
#' @param verbose Report progress every 25 folders.
#'
#' @return A data.frame with columns `relpath`, `parent`, `name`, `ext`,
#'   `depth`, `is_dir`, `bytes`, `looks_grammar`, and attributes `nodes`,
#'   `n_files`, `n_dirs`, `truncated`, `seconds`, `root`, `path`.
#'
#'   There are deliberately **no** country or survey columns. The reason this
#'   function and [datalib_explorer()] exist is that these trees do *not*
#'   follow the naming grammar, so a built-in "component 1 is a country" would
#'   smuggle back the assumption they were written to avoid. Where a tree does
#'   follow it, splitting `relpath` on `/` is one line and yours to name.
#'
#' @seealso [datalib_explorer()] for a single node.
#'
#' @examples
#' \dontrun{
#' idx <- datalib_index("Afghanistan", root = "<staging-tree>")
#' table(idx$ext)
#' attr(idx, "truncated")
#' }
#' @export
datalib_index <- function(path = NULL, root = NULL, max_nodes = 400L,
                          max_depth = 0L, dirs = FALSE, sizes = FALSE,
                          pattern = NULL, verbose = FALSE) {
  if (!is.numeric(max_nodes) || length(max_nodes) != 1L || max_nodes < 1) {
    err_input("`max_nodes` must be a single positive number.")
  }
  if (!is.numeric(max_depth) || length(max_depth) != 1L || max_depth < 0) {
    err_input("`max_depth` must be a single non-negative number; 0 means no limit.")
  }
  max_nodes <- as.integer(max_nodes)
  max_depth <- as.integer(max_depth)

  r <- dl_explorer_norm(root %||% dl_explorer_root())
  rel <- dl_explorer_rel(path)
  start <- if (nzchar(rel)) file.path(r, rel) else r
  if (!dir.exists(start)) {
    err_not_found(paste0("Not a directory: ", start))
  }

  started <- Sys.time()

  # A worklist, not recursion: R's expression nesting limit is finite and a
  # 193-country tree is not, and a queue makes the node cap exact.
  queue_rel <- rel
  queue_depth <- 0L

  out <- list()
  nodes <- 0L
  n_files <- 0L
  n_dirs <- 0L
  truncated <- FALSE

  while (length(queue_rel)) {
    cur <- queue_rel[1]
    cur_depth <- queue_depth[1]
    queue_rel <- queue_rel[-1]
    queue_depth <- queue_depth[-1]

    if (nodes >= max_nodes) {
      truncated <- TRUE
      break
    }
    nodes <- nodes + 1L

    here <- if (nzchar(cur)) file.path(r, cur) else r
    kids <- dl_list_dirs(here)
    fs_here <- dl_list_files(here)
    if (!is.null(pattern) && length(fs_here)) {
      fs_here <- fs_here[grepl(pattern, fs_here)]
    }

    n_files <- n_files + length(fs_here)
    n_dirs <- n_dirs + length(kids)

    parent_lab <- if (nzchar(cur)) cur else "."

    if (length(fs_here)) {
      sz <- rep(NA_real_, length(fs_here))
      if (isTRUE(sizes)) {
        sz <- file.info(file.path(here, fs_here))$size
        sz[is.na(sz)] <- 0
      }
      out[[length(out) + 1L]] <- data.frame(
        relpath = if (nzchar(cur)) file.path(cur, fs_here) else fs_here,
        parent = parent_lab,
        name = fs_here,
        ext = dl_file_ext(fs_here),
        depth = cur_depth + 1L,
        is_dir = FALSE,
        bytes = sz,
        looks_grammar = vapply(fs_here, dl_looks_grammar, logical(1),
                               USE.NAMES = FALSE),
        stringsAsFactors = FALSE
      )
    }

    if (length(kids)) {
      if (isTRUE(dirs)) {
        out[[length(out) + 1L]] <- data.frame(
          relpath = if (nzchar(cur)) file.path(cur, kids) else kids,
          parent = parent_lab,
          name = kids,
          ext = "",
          depth = cur_depth + 1L,
          is_dir = TRUE,
          bytes = NA_real_,
          looks_grammar = vapply(kids, dl_looks_grammar, logical(1),
                                 USE.NAMES = FALSE),
          stringsAsFactors = FALSE
        )
      }
      if (max_depth == 0L || cur_depth + 1L < max_depth) {
        queue_rel <- c(queue_rel,
                       if (nzchar(cur)) file.path(cur, kids) else kids)
        queue_depth <- c(queue_depth, rep(cur_depth + 1L, length(kids)))
      }
    }

    if (isTRUE(verbose) && nodes %% 25L == 0L) {
      message(sprintf("  %6d folders visited, %7d files, %6d queued",
                      nodes, n_files, length(queue_rel)))
    }
  }

  res <- if (length(out)) {
    do.call(rbind, out)
  } else {
    data.frame(relpath = character(0), parent = character(0),
               name = character(0), ext = character(0),
               depth = integer(0), is_dir = logical(0),
               bytes = numeric(0), looks_grammar = logical(0),
               stringsAsFactors = FALSE)
  }
  rownames(res) <- NULL

  attr(res, "nodes") <- nodes
  attr(res, "n_files") <- n_files
  attr(res, "n_dirs") <- n_dirs
  attr(res, "truncated") <- truncated
  attr(res, "seconds") <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  attr(res, "root") <- r
  attr(res, "path") <- rel

  if (truncated) {
    # Say what the number IS. The walk is breadth-first, so the queue holds only
    # the frontier already discovered -- the children of folders never visited
    # were never enumerated, so the true remainder is larger and unknowable
    # until the walk finishes. Reporting the queue length as the remainder
    # understates it badly.
    warning(sprintf(paste0(
      "stopped at the max_nodes cap of %d folders. At least %d more were ",
      "already queued, and the children of unvisited folders were never ",
      "listed, so the true remainder is larger. This result is a prefix of ",
      "the subtree."), max_nodes, length(queue_rel)), call. = FALSE)
  }

  res
}
