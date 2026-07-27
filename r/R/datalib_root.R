# datalib_root -- resolve the library root

#' Resolve the library root
#'
#' Resolves the datalib library root in the contract-v1 precedence order
#' (`config/grammar.md` section 7):
#'
#' 1. explicit `root` argument;
#' 2. environment variable `DATALIB_ROOT`;
#' 3. R option `datalib.root` (set via `options(datalib.root = ...)`);
#' 4. the `datalib:` key in the current user's block of the config files,
#'    searched in order: `~/.config/user_config.yml` (the file shared with
#'    the CSO Toolkit), then `~/.config/datalib_config.yml`. The first file
#'    whose user block carries a non-empty `datalib:` key wins (key-presence,
#'    block-level -- keys are never merged across files);
#' 5. otherwise, an error.
#'
#' The returned path carries two attributes recording where it came from:
#' `source_stage` (one of `argument`, `env`, `option`, `config_generic`,
#' `config_package`) and `source_file` (the config file, when the root came
#' from a file; `""` otherwise). The `source_stage` strings are identical in
#' the R, Python, and Stata implementations.
#'
#' Test/isolation hooks: set `DATALIB_CONFIG` to consult exactly one file
#' (fallback disabled), or `DATALIB_CONFIG_DIR` to search the two-file list
#' in a directory other than `~/.config` (fallback preserved).
#'
#' @param root Explicit root path (highest precedence). When `NULL`, empty,
#'   or `NA`, the remaining precedence chain is consulted.
#' @param user User name whose config block to read at the config stage.
#'   When `NULL`, the logged-in user.
#' @param config Path to a single config file; when given, pins that file and
#'   disables the two-file fallback.
#' @param configdir Directory in which to search the two-file list, instead of
#'   `~/.config`. Ignored when `config` is given.
#'
#' @return A length-1 character path, expanded and normalized with forward
#'   slashes, carrying `source_stage` and `source_file` attributes.
#'
#' Errors with condition class `datalib_error_input` (Stata 198) when no
#' source in the chain yields a root.
#'
#' @examples
#' \dontrun{
#' datalib_root("C:/data/library")           # explicit argument wins
#' Sys.setenv(DATALIB_ROOT = "C:/data/library")
#' datalib_root()                            # from the environment
#' r <- datalib_root()
#' attr(r, "source_stage")                   # where it resolved from
#' }
#' @export
datalib_root <- function(root = NULL, user = NULL, config = NULL,
                         configdir = NULL) {
  norm <- function(p) as.character(fs::path_norm(fs::path_expand(p)))
  mk <- function(path, stage, file = "") {
    out <- norm(path)
    attr(out, "source_stage") <- stage
    attr(out, "source_file") <- file
    out
  }
  if (nz_arg(root)) return(mk(root, "argument"))
  env <- Sys.getenv("DATALIB_ROOT", "")
  if (nzchar(env)) return(mk(env, "env"))
  opt <- getOption("datalib.root", NULL)
  if (nz_arg(opt)) return(mk(opt, "option"))
  # The config stage is the public reader's job: it owns the two-file search
  # and the isolation hooks, so there is one resolver rather than two that can
  # disagree about where configuration lives.
  cfg <- tryCatch(
    datalib_config(user = user, config = config, configdir = configdir),
    datalib_error_config_missing = function(e) NULL,
    datalib_error_user_missing = function(e) NULL
  )
  if (!is.null(cfg) && nz_arg(cfg$datalib)) {
    return(mk(cfg$datalib, cfg$source_stage, cfg$source_file))
  }
  err_root_unset(paste0(
    "datalib root not set: pass root, set DATALIB_ROOT, set ",
    "options(datalib.root = ...), or add a datalib key to your user block in ",
    "~/.config/user_config.yml (or ~/.config/datalib_config.yml)."
  ))
}
