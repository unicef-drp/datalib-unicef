# datalib_update -- is the datalib you are running the current one?

# Internal: compare two version strings and name the direction. Split out of
# datalib_update() so it is testable: on a machine where datalib is SOURCED rather
# than installed there is no running version, so the report path can never reach
# the comparison -- and the comparison is the part that must not be wrong.
# numeric_version compares component-wise, so 0.9.10 > 0.9.9; a text comparison
# gets that backwards, and it is the whole reason for comparing rather than
# eyeballing.
.dl_version_status <- function(running, source_version) {
  if (is.na(running) || is.na(source_version)) return("unknown")
  tryCatch({
    a <- numeric_version(running)
    b <- numeric_version(source_version)
    if (b > a) "newer_available" else if (b < a) "source_behind" else "current"
  }, error = function(e) "unknown")
}

#' Check whether a newer datalib is available
#'
#' Reports three coordinates: the version of `datalib` you are running, the
#' version published at the net site, and which way they differ. It is the R
#' counterpart of Stata's `datalib , update`, and reads the **same** version
#' manifest, so one publish serves all three languages.
#'
#' **It does not install anything.** `install.packages()` over a namespace that
#' is already loaded is unsafe on Windows -- the package's files are locked by
#' the running session -- so this function prints the exact command to run
#' instead of running it. That is a deliberate difference from Stata, where
#' `datalib , update install` can replace ado-files in place because Stata has no
#' package manager and no loaded-namespace problem.
#'
#' Why this exists at all, given R has `install.packages()` and
#' `update.packages()`: this package is **not on CRAN**, and the repository it
#' lives in is private, so there is no registry for the usual machinery to query.
#' The net site is the only place a version can be discovered.
#'
#' The net site is resolved in this order: the `netsource` argument, then
#' `options(datalib.netsource=)`, then the `DATALIB_NETSOURCE` environment
#' variable, then `Z:/_pkg/datalib`.
#'
#' @param netsource Directory holding the published `VERSION` manifest. When
#'   `NULL`, the option, then the environment variable, then `Z:/_pkg/datalib`.
#' @param quiet When `TRUE`, return the result without printing the report.
#'
#' @return Invisibly, a named list with elements `running`, `source`,
#'   `source_version` and `status`. `status` is one of `"current"`,
#'   `"newer_available"`, `"source_behind"` or `"unknown"`. `running` is `NA`
#'   when `datalib` is not installed as a package -- for instance when it has
#'   been sourced from a clone, in which case there is no installed version to
#'   report.
#'
#' @examples
#' \dontrun{
#' datalib_update()
#' datalib_update(netsource = "Z:/_pkg/datalib")
#' r <- datalib_update(quiet = TRUE)
#' r$status
#' }
#' @export
datalib_update <- function(netsource = NULL, quiet = FALSE) {
  # What are we running? packageVersion() is authoritative when the package is
  # installed. When datalib has been sourced from a clone there is no installed
  # version at all, and saying so is more useful than guessing from DESCRIPTION.
  running <- tryCatch(as.character(utils::packageVersion("datalib")),
                      error = function(e) NA_character_)

  src <- if (nz_arg(netsource)) {
    as.character(netsource)
  } else if (nz_arg(getOption("datalib.netsource"))) {
    as.character(getOption("datalib.netsource"))
  } else if (nzchar(Sys.getenv("DATALIB_NETSOURCE"))) {
    Sys.getenv("DATALIB_NETSOURCE")
  } else {
    "Z:/_pkg/datalib"
  }
  src <- sub("/+$", "", gsub("\\\\", "/", src))

  vfile <- file.path(src, "VERSION")
  source_version <- NA_character_
  if (file.exists(vfile)) {
    first <- tryCatch(trimws(readLines(vfile, warn = FALSE)[[1]]),
                      error = function(e) NA_character_)
    if (length(first) == 1L && !is.na(first) && nzchar(first)) {
      source_version <- first
    }
  }

  status <- .dl_version_status(running, source_version)

  out <- list(running = running, source = src,
              source_version = source_version, status = status)

  if (!quiet) {
    cat("\n", strrep("-", 68), "\n", sep = "")
    cat("datalib update (R)\n")
    cat(strrep("-", 68), "\n", sep = "")
    cat("  running        : ", if (is.na(running)) "not installed as a package" else running, "\n", sep = "")
    cat("  net site       : ", src, "\n", sep = "")
    cat("  site version   : ",
        if (is.na(source_version)) paste0("no VERSION file at ", src) else source_version,
        "\n", sep = "")
    if (status == "newer_available") {
      cat("\n  A newer datalib is published. This function does not install it --\n")
      cat("  install.packages() over a loaded namespace is unsafe on Windows.\n")
      cat("  In a FRESH R session, run:\n")
      # Name the ARTEFACT, not the directory. The net site holds one built source
      # tarball per version, and install.packages() pointed at the containing
      # folder fails. The filename is R CMD build's own convention, so it is
      # derivable from the version just read off the manifest.
      cat('    install.packages("', src, '/R/datalib_', source_version, '.tar.gz",\n',
          sep = "")
      cat('                     repos = NULL, type = "source")\n', sep = "")
    } else if (status == "current") {
      cat("\n  Up to date - running and published are both ", running, ".\n", sep = "")
    } else if (status == "source_behind") {
      cat("\n  The net site is OLDER than what you are running (", source_version,
          " < ", running, ").\n", sep = "")
      cat("  Do not reinstall from it: that would downgrade you. A stale snapshot\n")
      cat("  on this net site once reinstated a data-mutation bug.\n")
    } else if (is.na(running)) {
      cat("\n  Cannot compare: datalib is not installed as a package here, so there\n")
      cat("  is no installed version to compare. This is normal when the package\n")
      cat("  has been sourced from a clone.\n")
    } else {
      cat("\n  Cannot compare: no VERSION manifest at the net site.\n")
      cat("  Pass netsource=, or set options(datalib.netsource=) / DATALIB_NETSOURCE.\n")
    }
    cat(strrep("-", 68), "\n", sep = "")
  }

  invisible(out)
}
