# utils-paths.R -- folder-grammar parsing and path helpers (internal)
#
# The single place the "_"-split vintage-folder grammar lives
# (config/grammar.md): 5 tokens = master vintage, 8 tokens = adaptation.

# Parse a vintage folder name. Returns a list(kind, country, year, survey,
# master_version, adaptation_version, collection) or NULL when the name does
# not follow the grammar. Matching is done on the uppercased name
# (uppercase-once contract; tolerant of case on disk).
parse_vintage_folder <- function(name) {
  toks <- strsplit(toupper(name), "_", fixed = TRUE)[[1]]
  n <- length(toks)
  ver <- function(tok) {
    if (grepl("^V[0-9]+$", tok)) as.integer(sub("^V", "", tok)) else NA_integer_
  }
  if (n == 5L && toks[5] == "M") {
    return(list(
      kind = "master",
      country = toks[1],
      year = suppressWarnings(as.integer(toks[2])),
      survey = toks[3],
      master_version = ver(toks[4]),
      adaptation_version = NA_integer_,
      collection = NA_character_
    ))
  }
  if (n == 8L && toks[5] == "M" && toks[7] == "A") {
    return(list(
      kind = "adaptation",
      country = toks[1],
      year = suppressWarnings(as.integer(toks[2])),
      survey = toks[3],
      master_version = ver(toks[4]),
      adaptation_version = ver(toks[6]),
      collection = toks[8]
    ))
  }
  NULL
}

# Normalize a vintage spelling (1 / 01 / v01 / V01 / integer) to "v%02d".
format_version <- function(x, what = "vintage") {
  if (is.numeric(x)) {
    if (length(x) != 1L || is.na(x) || x != trunc(x)) {
      err_input(sprintf("%s must be a vintage number such as 01 or v01.", what))
    }
    n <- as.integer(x)
  } else {
    raw <- tolower(trimws(as.character(x)[1]))
    if (grepl("^v", raw)) raw <- sub("^v", "", raw)
    if (!grepl("^[0-9]+$", raw)) {
      err_input(sprintf("%s must be a vintage number such as 01 or v01.", what))
    }
    n <- as.integer(raw)
  }
  sprintf("v%02d", n)
}

# Basenames of the immediate subdirectories of `path` (empty when none/missing).
dl_list_dirs <- function(path) {
  if (!fs::dir_exists(path)) return(character(0))
  basename(as.character(fs::dir_ls(path, type = "directory")))
}

# Basenames of the immediate files of `path` (empty when none/missing).
dl_list_files <- function(path) {
  if (!fs::dir_exists(path)) return(character(0))
  basename(as.character(fs::dir_ls(path, type = "file")))
}
