# Pins the Stata/pandas merge rule for columns present in both sides:
# matched rows keep the accumulated (master) value EVEN WHEN IT IS NA;
# only rows that exist solely in the incoming (using) side take the
# incoming value. (The shared fixture cases cannot detect this — their
# overlapping non-key columns carry identical values — so it is pinned
# here as an R unit test against the internal merge helper.)

test_that("matched-row NA in the master survives the outer merge", {
  x <- data.frame(k = c(1L, 2L), v = c(NA_real_, 10))
  y <- data.frame(k = c(1L, 3L), v = c(99, 42))
  m <- dl_merge_outer(x, y, keys = "k")
  m <- m[order(m$k), ]
  # k=1 matched: master NA must NOT be filled from the using side
  expect_true(is.na(m$v[m$k == 1L]))
  # k=2 master-only: keeps its value
  expect_identical(m$v[m$k == 2L], 10)
  # k=3 using-only: takes the incoming value
  expect_identical(m$v[m$k == 3L], 42)
})

test_that("all six shared file sections are accepted", {
  root <- datalib_test_fixture_root()
  for (s in c("data", "data-original", "data-r", "data-other",
              "doc", "programs")) {
    res <- datalib_files("ZWE", 2019, "MICS", section = s,
                         collection = "HLT", root = root)
    expect_s3_class(res, "data.frame")
    expect_true(all(res$section == s))
  }
  # the data section of the HLT fixture has exactly the four modules
  d <- datalib_files("ZWE", 2019, "MICS", collection = "HLT", root = root)
  expect_identical(nrow(d), 4L)
})
