# Behavioural tests for the four enumerators, against the committed fixture.
#
# Added in v0.9.6 to close a real gap: before this file, datalib_countries,
# datalib_surveys, datalib_vintages and datalib_adaptations -- four of the
# thirteen canonical commands -- had NO behavioural coverage at all in either
# CI-runnable language. The only references in the suite were the name-surface
# lists in test-docs.R (that the function exists and is documented), which
# cannot catch a wrong return value.
#
# These are deliberately NOT shared golden cases. The three ports return
# structurally different objects for the same query: Stata's datalib_vintages
# returns bare integers in r(masters) = "9 10" and its datalib_adaptations
# returns r(collections) = "HLT IPUMS", Python returns VintageCatalog /
# AdaptationInfo objects, and R (below) returns data frames whose `folder`
# column holds full vintage folder names. One shared expect_items column could
# match at most one of the three. Whether the shapes should converge is a
# contract question for config/grammar.md, not something a CSV can paper over.

fixture <- datalib_test_fixture_root()

test_that("datalib_countries returns the fixture countries, uppercased", {
  got <- datalib_countries(root = fixture)
  expect_s3_class(got, "data.frame")
  expect_identical(names(got), "country")
  expect_identical(got$country, c("BRA", "KEN", "ZWE"))
})

test_that("datalib_surveys lists the survey folder with its parts", {
  got <- datalib_surveys("ZWE", root = fixture)
  expect_identical(got$folder, "ZWE_2019_MICS")
  expect_identical(got$country, "ZWE")
  expect_identical(got$survey, "MICS")
})

test_that("country is uppercased and trimmed at the boundary (contract rule 1)", {
  expect_identical(datalib_surveys("zwe", root = fixture)$folder, "ZWE_2019_MICS")
  expect_identical(datalib_surveys("  ZWE  ", root = fixture)$folder, "ZWE_2019_MICS")
})

test_that("datalib_vintages reports masters and adaptations with parsed parts", {
  got <- datalib_vintages("ZWE", 2019, "MICS", root = fixture)
  expect_identical(got$folder,
                   c("ZWE_2019_MICS_v01_M",
                     "ZWE_2019_MICS_v02_M",
                     "ZWE_2019_MICS_v02_M_v01_A_HLT",
                     "ZWE_2019_MICS_v02_M_v01_A_IPUMS"))
  expect_identical(got$kind,
                   c("master", "master", "adaptation", "adaptation"))
  expect_identical(got$master_version, c(1L, 2L, 2L, 2L))
})

test_that("latest master is the numeric maximum, not alphabetical (contract rule 2)", {
  # BRA_2015_PNAD carries v09 and v10 precisely so this cannot pass by accident:
  # directory-listing or alphabetical order would pick v09.
  got <- datalib_vintages("BRA", 2015, "PNAD", root = fixture)
  expect_identical(got$master_version, c(9L, 10L))
  expect_identical(got$folder[got$is_latest], "BRA_2015_PNAD_v10_M")
  expect_identical(max(got$master_version), 10L)
})

test_that("datalib_adaptations lists collections under the chosen master", {
  got <- datalib_adaptations("ZWE", 2019, "MICS", root = fixture)
  expect_identical(got$collection, c("HLT", "IPUMS"))
  expect_identical(got$master_version, c(2L, 2L))
})

test_that("a country with no adaptations returns zero rows, not an error", {
  got <- datalib_adaptations("BRA", 2015, "PNAD", root = fixture)
  expect_identical(nrow(got), 0L)
})

test_that("an unknown country is a typed input error", {
  # R already conforms here; Stata exits 198 and Python still returns empty
  # (tracked in the config/grammar.md Alignment status table, and marked
  # xfail(strict) in python/tests/test_enumerators.py).
  expect_error(datalib_surveys("XXX", root = fixture),
               class = "datalib_error_input")
})

test_that("a root that exists but holds no countries is an empty listing", {
  tmp <- file.path(tempdir(), "datalib-empty-root")
  dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  expect_identical(nrow(datalib_countries(root = tmp)), 0L)
})
