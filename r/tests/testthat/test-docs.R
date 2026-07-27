# test-docs.R -- documentation-parity guards
#
# Mechanically verifies that the package documentation cannot drift:
#  a) every NAMESPACE export has a man/<name>.Rd page;
#  b) the \arguments of each page exactly equal the function's formals;
#  c) the exported surface equals the contract-v1 public surface.

# The contract's public surface used to be hand-typed here as a character
# vector, citing config/grammar.md in a comment while nothing actually read it --
# a third copy of the list (after grammar.md's prose and Python's own hand-typed
# copy), free to drift from both. It now lives once, in config/surface.yml, and
# "exports == the declared commands" is asserted in test-surface.R. The tests
# below keep their own job: that each export has a man page, and that its
# \arguments match formals() exactly.

datalib_ns_exports <- function() {
  ns <- readLines(file.path(datalib_test_pkg_root(), "NAMESPACE"), warn = FALSE)
  sub("^export\\(([^)]+)\\)$", "\\1", grep("^export\\(", ns, value = TRUE))
}

# Argument names documented in the \arguments section of an .Rd file,
# in order (multi-name \item{a, b}{...} entries are split on commas).
datalib_rd_arg_names <- function(rd_file) {
  rd <- tools::parse_Rd(rd_file)
  tag_of <- function(x) {
    t <- attr(x, "Rd_tag")
    if (is.null(t)) "" else t
  }
  idx <- which(vapply(rd, tag_of, character(1)) == "\\arguments")
  if (!length(idx)) return(character(0))
  items <- Filter(function(x) identical(tag_of(x), "\\item"), rd[[idx[1]]])
  nms <- vapply(items, function(it) {
    paste(vapply(it[[1]], function(el) paste(as.character(el), collapse = ""),
                 character(1)), collapse = "")
  }, character(1))
  trimws(unlist(strsplit(nms, ",", fixed = TRUE)))
}

test_that("every NAMESPACE export has a man/<name>.Rd page", {
  man <- file.path(datalib_test_pkg_root(), "man")
  for (fn in datalib_ns_exports()) {
    expect_true(file.exists(file.path(man, paste0(fn, ".Rd"))),
                info = sprintf("man/%s.Rd is missing", fn))
  }
})

test_that("documented arguments exactly match each export's formals", {
  man <- file.path(datalib_test_pkg_root(), "man")
  for (fn in datalib_ns_exports()) {
    rd_file <- file.path(man, paste0(fn, ".Rd"))
    f <- get(fn, mode = "function")
    expect_identical(datalib_rd_arg_names(rd_file), names(formals(f)),
                     info = sprintf("\\arguments of man/%s.Rd", fn))
  }
})
