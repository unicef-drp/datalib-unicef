# helper-datalib.R -- test bootstrap (sourced automatically by testthat)
#
# Runs in two very different situations, which is what this file is really about:
#
#   SOURCE TREE (local, `testthat::test_local("r")`). The package may not be
#   installed, so R/*.R is sourced directly, and the SHARED repo-level tests/
#   directory -- the golden conformance CSVs and the fixture library -- is found by
#   walking up from the test directory.
#
#   INSTALLED PACKAGE (`R CMD check`, and CRAN). The package IS installed, so
#   nothing needs sourcing. But the shared corpus lives at the REPO root and is
#   deliberately not part of the R package: it is one set of cases that Stata, R and
#   Python must all pass, and duplicating it into inst/ would create a second copy
#   to drift. On a CRAN machine the repo does not exist at all.
#
# Until v0.9.19 this file assumed the first case and hard-stopped in the second, so
# `R CMD check` died before a single test ran -- one ERROR, the whole suite, from a
# missing DESCRIPTION above datalib.Rcheck/tests/testthat. That is a CRAN blocker
# and it was not on the publication checklist, because nobody had run the check.
#
# So: locating things now FAILS SOFT, and the corpus accessor SKIPS rather than
# errors. Nine of thirteen test files need the corpus; on CRAN they skip and the
# four self-contained files still run. The full suite remains the repo-level gate,
# which is what CONTRIBUTING.md already says.

# Package SOURCE root, or NULL. Never stops: absence is a legitimate state, and it is
# the normal state under R CMD check -- an installed package has no NAMESPACE beside
# a man/ beside an inst/, because install converts them.
datalib_test_pkg_root_or_null <- function() {
  p <- normalizePath(getwd(), winslash = "/")
  repeat {
    if (file.exists(file.path(p, "DESCRIPTION"))) return(p)
    parent <- dirname(p)
    if (parent == p) return(NULL)
    p <- parent
  }
}

# The accessor source-tree tests use. Symmetric with datalib_test_repo_tests(): one
# choke point that skips, rather than a NULL guard in every caller. Without this the
# seven tests that read NAMESPACE, man/*.Rd or inst/collections.yml passed NULL into
# file.path(), producing character(0) and the opaque
# "invalid 'description' argument" from file() -- an error that says nothing about
# the actual cause.
datalib_test_pkg_root <- function() {
  pkg <- datalib_test_pkg_root_or_null()
  if (is.null(pkg)) {
    testthat::skip(paste(
      "package source tree not available: no DESCRIPTION above the working",
      "directory. Expected under R CMD check, where the package is installed and",
      "NAMESPACE / man/ / inst/ are not present as source files."
    ))
  }
  pkg
}

# Shared repo tests/ dir, or NULL. Walks up from the WORKING DIRECTORY rather than
# from the package root, so it still resolves under R CMD check -- where the check
# runs inside the repo but the package root is not an ancestor of the test dir.
datalib_test_repo_tests_or_null <- function() {
  p <- normalizePath(getwd(), winslash = "/")
  repeat {
    if (file.exists(file.path(p, "tests", "cases_resolve.csv"))) {
      return(normalizePath(file.path(p, "tests"), winslash = "/"))
    }
    parent <- dirname(p)
    if (parent == p) return(NULL)
    p <- parent
  }
}

# The accessor tests use. Skipping HERE rather than in each caller is deliberate:
# it is one choke point instead of a guard in nine files that someone would forget
# to add to the tenth.
datalib_test_repo_tests <- function() {
  rt <- datalib_test_repo_tests_or_null()
  if (is.null(rt)) {
    testthat::skip(paste(
      "shared conformance corpus not available: tests/cases_resolve.csv was not",
      "found above the working directory. Expected when the package is installed",
      "away from the repository (R CMD check on CRAN)."
    ))
  }
  rt
}

datalib_test_fixture_root <- function() {
  file.path(datalib_test_repo_tests(), "fixtures", "library")
}

local({
  pkg <- datalib_test_pkg_root_or_null()
  if (!"datalib" %in% loadedNamespaces()) {
    if (is.null(pkg)) {
      stop("datalib is neither installed nor locatable as a source tree; ",
           "cannot run tests")
    }
    for (f in sort(list.files(file.path(pkg, "R"), pattern = "\\.[Rr]$",
                              full.names = TRUE))) {
      sys.source(f, envir = globalenv())
    }
  }
  # Pin the registry: the source tree's copy when there is one, otherwise the
  # installed package's.
  cfg <- if (!is.null(pkg) && file.exists(file.path(pkg, "inst", "collections.yml"))) {
    file.path(pkg, "inst", "collections.yml")
  } else {
    system.file("collections.yml", package = "datalib")
  }
  if (nzchar(cfg) && file.exists(cfg)) options(datalib.collections.path = cfg)
})
