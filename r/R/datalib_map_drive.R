# datalib_map_drive -- Windows `net use` wrapper

#' Map a Windows network drive
#'
#' Windows `net use` wrapper mirroring the Stata `mapzdrive` alias (plus
#' private `_mzremote`). Maps `letter` to `unc`, defaulting both from the
#' user configuration block (`zDrive` / `zDriveUNC`, see
#' [datalib_config()]). Mapping FAILURE is a status, not an error (parity
#' with Stata); calling on a non-Windows platform raises a condition of
#' class `datalib_error_input` (Stata 198), as does an invalid `letter` or
#' a missing UNC path.
#'
#' @param letter Drive letter to map, accepted as `"Z"`, `"z:"`, or
#'   `"Z:/"` (normalized to `"Z:"`). When `NULL`, the user config `zDrive`
#'   (default `"Z:/"`).
#' @param unc UNC path to map (e.g. `"\\\\server\\share"`). When `NULL`,
#'   the user config `zDriveUNC`.
#' @param user User name whose configuration block supplies the defaults;
#'   passed to [datalib_config()]. When `NULL`, the logged-in user. Only
#'   consulted when `letter` or `unc` is missing.
#' @param config Path to the configuration YAML file; passed to
#'   [datalib_config()]. When `NULL`, `~/.config/user_config.yml`. Only
#'   consulted when `letter` or `unc` is missing.
#' @param persistent Logical; when `TRUE` (default) the mapping is made
#'   with `/persistent:yes`, otherwise `/persistent:no`.
#' @param force Logical; when `TRUE`, an existing mapping of `letter` to a
#'   DIFFERENT remote is deleted and remapped. When `FALSE` (default), the
#'   call returns status `"failed"` instead.
#' @param dry_run Logical; when `TRUE`, nothing is executed and status
#'   `"dryrun"` is returned with the normalized `letter` and `unc`.
#'
#' @return A named list:
#'   \describe{
#'     \item{status}{character; one of `"mapped"`, `"already-mapped"`,
#'       `"dryrun"`, or `"failed"`.}
#'     \item{letter}{character; normalized drive letter (e.g. `"Z:"`).}
#'     \item{unc}{character; the UNC path involved (for
#'       `"already-mapped"`/blocked `"failed"`, the currently mapped
#'       remote).}
#'   }
#'
#' @examples
#' \dontrun{
#' datalib_map_drive()                                   # config defaults
#' datalib_map_drive("Z", "\\\\server\\share")
#' datalib_map_drive("Z", "\\\\server\\share", dry_run = TRUE)
#' datalib_map_drive("Z", "\\\\server\\other", force = TRUE)
#' }
#' @export
datalib_map_drive <- function(letter = NULL, unc = NULL, user = NULL,
                              config = NULL, persistent = TRUE, force = FALSE,
                              dry_run = FALSE) {
  if (.Platform$OS.type != "windows") {
    err_input("datalib_map_drive is only available on Windows.")
  }
  if (!nz_arg(letter) || !nz_arg(unc)) {
    cfg <- datalib_config(user = user, config = config)
    if (!nz_arg(letter)) letter <- cfg$zDrive
    if (!nz_arg(unc)) unc <- cfg$zDriveUNC
  }
  # normalize "Z", "z:", "Z:/" -> "Z:"
  letter <- toupper(substr(trimws(as.character(letter)), 1L, 1L))
  if (!grepl("^[A-Z]$", letter)) {
    err_input("letter must be a drive letter such as Z or Z:.")
  }
  letter <- paste0(letter, ":")
  if (!nz_arg(unc)) {
    err_input("No UNC path available: pass unc or set zDriveUNC in the user config.")
  }
  unc <- trimws(as.character(unc))

  if (isTRUE(dry_run)) {
    return(list(status = "dryrun", letter = letter, unc = unc))
  }

  existing <- dl_drive_remote(letter)
  if (!is.na(existing)) {
    if (toupper(existing) == toupper(unc)) {
      return(list(status = "already-mapped", letter = letter, unc = existing))
    }
    if (!isTRUE(force)) {
      return(list(status = "failed", letter = letter, unc = existing))
    }
    suppressWarnings(system2("net", c("use", letter, "/delete", "/y"),
                             stdout = FALSE, stderr = FALSE))
  }

  args <- c("use", letter, unc,
            paste0("/persistent:", if (isTRUE(persistent)) "yes" else "no"))
  rc <- suppressWarnings(system2("net", args, stdout = FALSE, stderr = FALSE))
  if (identical(rc, 0L)) {
    list(status = "mapped", letter = letter, unc = unc)
  } else {
    list(status = "failed", letter = letter, unc = unc)
  }
}

# Current remote (UNC) of a mapped drive letter, or NA when not mapped.
# Parses `net use <letter>` output (locale caveat: matches "Remote name").
dl_drive_remote <- function(letter) {
  out <- suppressWarnings(tryCatch(
    system2("net", c("use", letter), stdout = TRUE, stderr = TRUE),
    error = function(e) character(0)
  ))
  ln <- grep("^\\s*Remote name", out, value = TRUE)
  if (!length(ln)) return(NA_character_)
  val <- trimws(sub("^\\s*Remote name\\s*", "", ln[1]))
  if (nzchar(val)) val else NA_character_
}
