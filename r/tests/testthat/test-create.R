# datalib_create: check mode (the default) must have ZERO side effects
# (contract divergence #7: pre-0.5 Stata _mkdir created directories while
# "checking"); create = TRUE builds the full vintage skeleton.

test_that("datalib_create default check mode has zero side effects", {
  tmp <- file.path(tempdir(),
                   paste0("datalib-create-", format(Sys.time(), "%H%M%OS3")))
  dir.create(tmp, recursive = TRUE)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  before <- list.files(tmp, recursive = TRUE, all.files = TRUE,
                       include.dirs = TRUE)
  res <- datalib_create("zwe", 2030, "mics", root = tmp)
  after <- list.files(tmp, recursive = TRUE, all.files = TRUE,
                      include.dirs = TRUE)

  expect_identical(after, before)
  expect_false(res$created)
  expect_false(res$existed)
  expect_identical(res$vintage_folder, "ZWE_2030_MICS_v01_M")
  expect_identical(res$survey_folder, "ZWE_2030_MICS")
})

test_that("datalib_create create = TRUE builds the vintage skeleton", {
  tmp <- file.path(tempdir(),
                   paste0("datalib-create2-", format(Sys.time(), "%H%M%OS3")))
  dir.create(tmp, recursive = TRUE)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  res <- datalib_create("zwe", 2030, "mics", collection = "HLT",
                        root = tmp, create = TRUE)
  expect_true(res$created)
  expect_false(res$existed)
  expect_identical(res$vintage_folder, "ZWE_2030_MICS_v01_M_v01_A_HLT")
  base <- file.path(tmp, "ZWE", "ZWE_2030_MICS", "ZWE_2030_MICS_v01_M_v01_A_HLT")
  for (s in c("Data/Original", "Data/Stata", "Data/R", "Data/Other",
              "Doc", "Programs")) {
    expect_true(dir.exists(file.path(base, s)), label = paste("dir", s))
  }

  # re-running on an existing vintage reports existed, not created
  res2 <- datalib_create("ZWE", 2030, "MICS", collection = "HLT",
                         root = tmp, create = TRUE)
  expect_true(res2$existed)
  expect_false(res2$created)
})
