# The repo carries one version, in VERSION. Until v0.9.4 r/DESCRIPTION said
# 0.1.0 and python/pyproject.toml said 0.1.0 while the repo shipped 0.9.3 --
# nothing pinned them, unlike CONTRACT_VERSION which two Python tests pin.

test_that("DESCRIPTION Version equals the repo VERSION file", {
  # datalib_test_repo_tests() returns <repo>/tests, so the repo is its parent
  repo <- dirname(datalib_test_repo_tests())
  vfile <- file.path(repo, "VERSION")
  skip_if_not(file.exists(vfile), "VERSION not found (running outside the repo)")
  want <- trimws(readLines(vfile, warn = FALSE)[[1]])
  # read.dcf keeps a names attribute ("Version"), which expect_identical
  # treats as a difference -- unname before comparing.
  got <- unname(trimws(read.dcf(file.path(datalib_test_pkg_root(), "DESCRIPTION"),
                                fields = "Version")[1, 1]))
  expect_identical(got, want)
})
