# datalib_config -- read the per-user configuration block

# Internal: the config directory. `configdir` (argument) wins, then the
# DATALIB_CONFIG_DIR env var, then ~/.config under USERPROFILE on Windows /
# HOME elsewhere. The argument exists for parity with Stata's configdir()
# accommodation, and because a test cannot set an env var for a child process
# as cheaply as it can pass an argument.
.dl_config_dir <- function(configdir = NULL) {
  if (nz_arg(configdir)) return(as.character(configdir))
  dir <- Sys.getenv("DATALIB_CONFIG_DIR", "")
  if (nzchar(dir)) return(dir)
  home <- if (.Platform$OS.type == "windows") {
    Sys.getenv("USERPROFILE")
  } else {
    Sys.getenv("HOME")
  }
  file.path(home, ".config")
}

# Internal: the ordered list of config files to consult. An explicit `config`
# (or the DATALIB_CONFIG env var) pins a single file and disables the
# fallback; otherwise the two-file list (user_config.yml, then
# datalib_config.yml) is searched inside the config directory.
.dl_config_file_list <- function(config = NULL, configdir = NULL) {
  if (nz_arg(config)) return(as.character(config))          # explicit: single file
  env_file <- Sys.getenv("DATALIB_CONFIG", "")
  if (nzchar(env_file)) return(env_file)                    # DATALIB_CONFIG: single file
  dir <- .dl_config_dir(configdir)
  c(file.path(dir, "user_config.yml"),
    file.path(dir, "datalib_config.yml"))
}

#' Read the per-user configuration block
#'
#' Reads the current user's block from the configuration file(s) and returns
#' it. Mirrors the Stata `getuserconfig` command; unlike Stata, R sets no
#' globals -- callers hold the returned list.
#'
#' Configuration resolution is a **two-file, key-presence search**
#' (`config/grammar.md` section 7). The user's block is looked up first in
#' `~/.config/user_config.yml` (the file shared with the CSO Toolkit) and then
#' in `~/.config/datalib_config.yml`. The full block comes from the first file
#' that has the user block; for the library root, the **first file whose block
#' carries a non-empty `datalib:` key wins** (block-level -- keys are never
#' merged across files, and an empty value counts as absent). Where the root
#' came from is reported in `source_stage` / `source_file`.
#'
#' Passing `config` (or setting the `DATALIB_CONFIG` environment variable)
#' pins exactly one file and disables the fallback; `configdir` (or
#' `DATALIB_CONFIG_DIR`) searches the two-file list in another directory.
#'
#' Errors follow the contract-v1 taxonomy (`config/grammar.md`):
#' condition class `datalib_error_config_missing` (Stata 601) when no
#' configuration file exists, and `datalib_error_user_missing` (Stata 459)
#' when a file exists but carries no block for the user.
#'
#' @param user User name whose block to read. When `NULL`, the logged-in
#'   user reported by `Sys.info()[["user"]]`.
#' @param config Path to a single configuration YAML file. When given, it is
#'   the only file consulted and the two-file fallback is disabled.
#' @param configdir Directory in which to search the two-file list, instead of
#'   `~/.config`. Ignored when `config` is given.
#'
#' @return A named list with elements (missing keys default to `""`):
#'   \describe{
#'     \item{user}{character; the user name that was looked up.}
#'     \item{config}{character; path of the file the block was read from.}
#'     \item{githubFolder}{character; the user's GitHub folder.}
#'     \item{teamsRoot}{character; the user's Teams root.}
#'     \item{zDrive}{character; drive to map (defaults to `"Z:/"`).}
#'     \item{zDriveUNC}{character; UNC path behind the mapped drive.}
#'     \item{datalib}{character; optional library root (`datalib:` key).}
#'     \item{source_stage}{character; where the library root came from --
#'       `"config_generic"`, `"config_package"`, or `"unset"` when no file
#'       carried the key.}
#'     \item{source_file}{character; the file the library root came from, or
#'       `""` when unset.}
#'   }
#'
#' @examples
#' \dontrun{
#' datalib_config()                          # block of the logged-in user
#' datalib_config(user = "jdoe")
#' datalib_config(config = "C:/cfg/user_config.yml")   # pin one file
#' datalib_config(configdir = "C:/cfg")                # search elsewhere
#' }
#' @export
datalib_config <- function(user = NULL, config = NULL, configdir = NULL) {
  if (!nz_arg(user)) user <- Sys.info()[["user"]]
  files <- .dl_config_file_list(config = config, configdir = configdir)

  any_file <- FALSE
  block_file <- NULL
  blk <- NULL
  dl <- ""
  src_stage <- "unset"
  src_file <- ""
  read_err <- NULL

  for (f in files) {
    if (!file.exists(f)) next
    any_file <- TRUE
    # A malformed fallback file must not break a working primary one, so the
    # parse is per-file; the error is only surfaced if nothing else resolves.
    cfg <- tryCatch(yaml::read_yaml(f), error = function(e) {
      if (is.null(read_err)) read_err <<- e
      NULL
    })
    if (!is.list(cfg) || !(user %in% names(cfg))) next
    this <- cfg[[user]]
    if (!is.list(this)) next
    if (is.null(block_file)) {
      block_file <- f
      blk <- this
    }
    if (!nzchar(dl) && nz_arg(this$datalib)) {
      dl <- as.character(this$datalib)
      src_file <- f
      src_stage <- if (basename(f) == "user_config.yml") {
        "config_generic"
      } else {
        "config_package"
      }
    }
  }

  if (!any_file) {
    err_config_missing(sprintf(
      "Configuration file not found at expected path: %s.", files[[1]]))
  }
  if (is.null(block_file)) {
    if (!is.null(read_err)) stop(read_err)
    err_user_missing(sprintf(
      "Configuration file found at: %s, but it has no entry for user '%s'.",
      paste(files, collapse = ", "), user))
  }

  list(
    user = user,
    config = as.character(block_file),
    githubFolder = blk$githubFolder %||% "",
    teamsRoot = blk$teamsRoot %||% "",
    zDrive = if (is.null(blk$zDrive) || !nzchar(blk$zDrive)) "Z:/" else blk$zDrive,
    zDriveUNC = blk$zDriveUNC %||% "",
    datalib = dl,
    source_stage = src_stage,
    source_file = src_file
  )
}
