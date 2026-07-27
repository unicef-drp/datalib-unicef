# Conformance: the SHARED golden load cases (tests/cases_load.csv at repo
# level) must pass unmodified. expect_n pins the merged (or per-module) row
# count; expect_windex8 pins the count of windex5 == 8 surviving the load
# (the no-mutation contract). nomerge means merge = FALSE (named list).

test_that("shared load conformance cases pass unmodified", {
  cases <- read.csv(file.path(datalib_test_repo_tests(), "cases_load.csv"),
                    colClasses = "character")
  expect_gt(nrow(cases), 0)
  root <- datalib_test_fixture_root()
  expect_true(dir.exists(root))

  nz <- function(x) !is.na(x) && nzchar(x)
  count_windex8 <- function(df) {
    if (!"windex5" %in% names(df)) return(0L)
    w <- as.numeric(df$windex5)
    as.integer(sum(!is.na(w) & w == 8))
  }

  for (i in seq_len(nrow(cases))) {
    cs <- cases[i, ]
    args <- list(country = cs$country, kind = cs$kind, root = root,
                 merge = !nz(cs$nomerge))
    if (nz(cs$year)) args$year <- cs$year
    if (nz(cs$survey)) args$survey <- cs$survey
    if (nz(cs$collection)) args$collection <- cs$collection
    if (nz(cs$master_version)) args$master_version <- cs$master_version
    if (nz(cs$modules)) {
      args$module <- strsplit(trimws(cs$modules), "\\s+")[[1]]
    }

    if (nz(cs$expect_error)) {
      expect_error(do.call(datalib_load, args),
                   class = paste0("datalib_error_", cs$expect_error),
                   info = paste("case", cs$case_id))
      next
    }

    res <- do.call(datalib_load, args)
    if (is.data.frame(res)) {
      n <- nrow(res)
      w8 <- count_windex8(res)
    } else {
      expect_true(is.list(res), info = paste("case", cs$case_id))
      n <- sum(vapply(res, nrow, integer(1)))
      w8 <- sum(vapply(res, count_windex8, integer(1)))
    }
    expect_identical(as.integer(n), as.integer(cs$expect_n),
                     info = paste("case", cs$case_id, "row count"))
    if (nz(cs$expect_windex8)) {
      expect_identical(as.integer(w8), as.integer(cs$expect_windex8),
                       info = paste("case", cs$case_id, "windex5==8 count"))
    }
    if (nz(cs$expect_provenance) && cs$expect_provenance == "1") {
      frames <- if (is.data.frame(res)) list(res) else res
      for (f in frames) {
        expect_true(all(c("ctrycode", "year") %in% names(f)),
                    info = paste("case", cs$case_id, "provenance columns"))
      }
    }
  }
})
