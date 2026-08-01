# Helpers shared by datalib_explorer() and datalib_index().
#
# Kept together and unexported because they encode decisions the two functions
# must agree on: what counts as an extension, which extensions a caller can open
# with what, and what "follows the grammar" means. Two copies of any of those
# would be free to drift, and the Stata leg has already been bitten by exactly
# that (datalib.sthlp sat five releases behind the code it documented).

# The root for the arbitrary-tree functions. Deliberately NOT datalib_root(),
# which applies the structural library test -- the gate these two exist to
# bypass -- so this reads the same config without demanding a library.
dl_explorer_root <- function() {
  cfg <- tryCatch(datalib_config(), error = function(e) NULL)
  candidate <- cfg$datalib %||% Sys.getenv("DATALIB_ROOT", "")
  if (!nzchar(candidate %||% "")) {
    err_root_unset(paste0(
      "No tree to walk: pass `root`, or set the datalib root. ",
      "Unlike the other navigation functions this one does not require a ",
      "datalib library -- any directory will do."
    ))
  }
  candidate
}

# Forward-slash, and drop a trailing separator without eating a drive root
# ("Z:/" must stay "Z:/", or file.path() would produce "Z:Afghanistan").
dl_explorer_norm <- function(p) {
  p <- gsub("\\\\", "/", p)
  while (nchar(p) > 1L && substring(p, nchar(p)) == "/" &&
         substring(p, nchar(p) - 1L, nchar(p) - 1L) != ":") {
    p <- substring(p, 1L, nchar(p) - 1L)
  }
  p
}

# The relative path, used verbatim apart from separator normalisation and
# stripping leading/trailing slashes.
dl_explorer_rel <- function(path) {
  if (is.null(path) || !length(path) || !nzchar(path[1])) {
    return("")
  }
  rel <- gsub("\\\\", "/", path[1])
  rel <- sub("^/+", "", rel)
  rel <- sub("/+$", "", rel)
  rel
}

# Extension of a BASENAME, lowercased and dot-free. "none" when there is none,
# so a caller branching on this can distinguish "no extension" from a directory
# row (which gets ""), rather than having both collapse to the empty string.
dl_file_ext <- function(files) {
  if (!length(files)) {
    return(character(0))
  }
  base <- basename(files)
  has_dot <- grepl(".", base, fixed = TRUE)
  ext <- ifelse(has_dot, tolower(sub("^.*\\.", "", base)), "none")
  ext
}

# Text formats R or Stata can read directly. The unobvious entries are the DHS
# and SPSS metadata companions -- dct frq frw map as var ivd sts inf -- which are
# plain text and make up about a fifth of the archive this package indexes.
DL_VIEW_EXT <- c(
  "txt", "csv", "tsv", "dct", "frq", "frw", "map", "as", "var", "ivd", "sts",
  "inf", "sps", "sas", "do", "ado", "mata", "log", "md", "json", "yml", "yaml",
  "xml", "html", "htm", "dat", "asc", "raw", "sthlp", "lst", "nfo", "r",
  "rmd", "qmd"
)

# What a caller can do with each file. Mirrors Stata's _dl_fileaction so the
# two legs classify identically: "describe" for Stata's own format, "view" for
# anything textual, "open" for formats neither language reads.
#
# An extensionless file is "view" DELIBERATELY, not by omission: in this archive
# the extensionless files are fixed-width text extracts (Spain's NACIA75 is 34
# MB of them), so text is the correct guess.
dl_file_kind <- function(exts) {
  vapply(exts, function(e) {
    if (identical(e, "none") || !nzchar(e)) {
      "view"
    } else if (identical(e, "dta")) {
      "describe"
    } else if (e %in% DL_VIEW_EXT) {
      "view"
    } else {
      "open"
    }
  }, character(1), USE.NAMES = FALSE)
}

# Does this name already follow CCC_YYYY_SURVEY? The useful test in a mixed
# tree: it separates branches someone has restructured from ones nobody has
# touched, without a second pass.
dl_looks_grammar <- function(name) {
  if (!length(name) || !nzchar(name[1])) {
    return(FALSE)
  }
  grepl("^[A-Za-z]{3}_[0-9]{4}_[A-Za-z0-9-]+", name[1])
}
