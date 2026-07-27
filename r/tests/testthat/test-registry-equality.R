# The bundled inst/collections.yml must be a byte-copy of the canonical
# registry at <repo>/config/collections.yml (single source of truth).

test_that("bundled collections.yml is byte-identical to config/collections.yml", {
  bundled <- file.path(datalib_test_pkg_root(), "inst", "collections.yml")
  canonical <- file.path(dirname(datalib_test_repo_tests()),
                         "config", "collections.yml")
  expect_true(file.exists(bundled))
  expect_true(file.exists(canonical))
  a <- readBin(bundled, what = "raw", n = file.size(bundled))
  b <- readBin(canonical, what = "raw", n = file.size(canonical))
  expect_identical(a, b)
})
