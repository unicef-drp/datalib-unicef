# helper-datalib.R -- test bootstrap (sourced automatically by testthat)
#
# 1. Locates the package root (r/) and the SHARED repo-level tests/ directory
#    (the golden conformance CSVs and fixture library) by walking up from the
#    test directory.
# 2. When the package is not installed/loaded, sources all R/*.R files so the
#    suite runs headlessly without devtools or installation.
# 3. Pins the collection registry to the source-tree inst/collections.yml.

datalib_test_pkg_root <- function() {
  p <- normalizePath(getwd(), winslash = "/")
  repeat {
    if (file.exists(file.path(p, "DESCRIPTION"))) return(p)
    parent <- dirname(p)
    if (parent == p) stop("datalib package root (DESCRIPTION) not found above ", getwd())
    p <- parent
  }
}

# Shared repo tests/ dir: walk up until <dir>/tests/cases_resolve.csv exists.
datalib_test_repo_tests <- function() {
  p <- datalib_test_pkg_root()
  repeat {
    cand <- file.path(p, "tests", "cases_resolve.csv")
    if (file.exists(cand)) {
      return(normalizePath(file.path(p, "tests"), winslash = "/"))
    }
    parent <- dirname(p)
    if (parent == p) {
      stop("Shared repo tests/ directory (tests/cases_resolve.csv) not found above ",
           datalib_test_pkg_root())
    }
    p <- parent
  }
}

datalib_test_fixture_root <- function() {
  file.path(datalib_test_repo_tests(), "fixtures", "library")
}

local({
  pkg <- datalib_test_pkg_root()
  if (!"datalib" %in% loadedNamespaces()) {
    for (f in sort(list.files(file.path(pkg, "R"), pattern = "\\.[Rr]$",
                              full.names = TRUE))) {
      sys.source(f, envir = globalenv())
    }
  }
  options(datalib.collections.path = file.path(pkg, "inst", "collections.yml"))
})
