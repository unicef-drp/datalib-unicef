# Conformance: the SHARED golden resolve cases (tests/cases_resolve.csv at
# repo level) must pass unmodified. Empty cells mean "omitted -> default per
# contract"; expect_error rows name the expected condition class suffix.

test_that("shared resolve conformance cases pass unmodified", {
  cases <- read.csv(file.path(datalib_test_repo_tests(), "cases_resolve.csv"),
                    colClasses = "character")
  expect_gt(nrow(cases), 0)
  root <- datalib_test_fixture_root()
  expect_true(dir.exists(root))

  nz <- function(x) !is.na(x) && nzchar(x)
  for (i in seq_len(nrow(cases))) {
    cs <- cases[i, ]
    args <- list(country = cs$country, kind = cs$kind, root = root)
    if (nz(cs$year)) args$year <- cs$year
    if (nz(cs$survey)) args$survey <- cs$survey
    if (nz(cs$collection)) args$collection <- cs$collection
    if (nz(cs$master_version)) args$master_version <- cs$master_version
    if (nz(cs$adaptation_version)) args$adaptation_version <- cs$adaptation_version

    if (nz(cs$expect_error)) {
      expect_error(do.call(datalib_resolve, args),
                   class = paste0("datalib_error_", cs$expect_error),
                   info = paste("case", cs$case_id))
    } else {
      res <- do.call(datalib_resolve, args)
      expect_identical(res$vintage_folder, cs$expect_vintage_folder,
                       info = paste("case", cs$case_id))
    }
  }
})
