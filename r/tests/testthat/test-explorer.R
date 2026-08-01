# datalib_explorer() and datalib_index() -- the arbitrary-tree functions.
#
# Hermetic: a throwaway tree under tempdir() carrying the properties that actually
# broke the Stata implementation -- a folder name with a SPACE, mixed casing, and a
# file with no extension. Nothing here needs the network share.
#
# The assertions deliberately mirror Stata's conformance cases x01-x18 and
# ix01-ix11, because the point of porting is that the three legs agree. Where a
# claim has to hold in more than one language it is read from the shared
# tests/cases_filekind.csv rather than typed out again here.

make_tree <- function() {
  root <- file.path(tempdir(), paste0("dl_expl_", as.integer(runif(1, 1, 1e9))))
  dir.create(file.path(root, "Alpha Land", "Deep One"), recursive = TRUE)
  dir.create(file.path(root, "SLV", "SLV_2014_MICS"), recursive = TRUE)
  writeLines("x", file.path(root, "notes.txt"))
  writeLines("x", file.path(root, "table.DTA"))
  writeLines("x", file.path(root, "Alpha Land", "NOEXT"))
  writeLines("x", file.path(root, "Alpha Land", "Deep One", "leaf.csv"))
  root
}

test_that("an arbitrary tree opens, and a non-library directory opens too", {
  root <- make_tree()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  node <- datalib_explorer(root = root)
  expect_equal(node$n_dirs, 2L)
  expect_equal(node$depth, 0L)
  expect_equal(node$parent, "")

  # "Alpha Land" holds no CCC/CCC_* pair, so it is emphatically not a library --
  # and must still open. (The root itself DOES satisfy the library test, because
  # SLV/SLV_2014_MICS is exactly that pair; the Stata suite learned this the hard
  # way when a case asserted the opposite.)
  inner <- datalib_explorer("Alpha Land", root = root)
  expect_equal(inner$depth, 1L)
  expect_equal(inner$parent, ".")
})

test_that("casing and spaces survive, and depth counts separators not words", {
  root <- make_tree()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  node <- datalib_explorer(root = root)
  expect_true("Alpha Land" %in% node$dirs)  # not "alpha land"

  deep <- datalib_explorer("Alpha Land/Deep One", root = root)
  expect_equal(deep$path, "Alpha Land/Deep One")
  expect_equal(deep$parent, "Alpha Land")
  # Three words, two components. Stata's first implementation reported depth 4
  # here because it counted words; the space is in the fixture for that reason.
  expect_equal(deep$depth, 2L)
})

test_that("bytes is NA until measured, because 0 is a real size", {
  root <- make_tree()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  expect_true(is.na(datalib_explorer(root = root)$bytes))
  measured <- datalib_explorer(root = root, sizes = TRUE)
  expect_gt(measured$bytes, 0)
  expect_false(is.na(measured$largest))
})

test_that("max_items caps the lists but never the counts", {
  root <- make_tree()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  capped <- datalib_explorer(root = root, max_items = 1L)
  expect_true(capped$truncated)
  expect_equal(length(capped$files), 1L)
  # The true totals must survive: a capped list beside an uncapped total with no
  # flag is how a caller comes to trust a partial answer.
  expect_equal(capped$n_files, 2L)
  expect_equal(capped$n_dirs, 2L)
})

test_that("looks_grammar separates a renamed branch from an untouched one", {
  root <- make_tree()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  expect_true(datalib_explorer("SLV/SLV_2014_MICS", root = root)$looks_grammar)
  expect_false(datalib_explorer("Alpha Land", root = root)$looks_grammar)
})

test_that("a missing node errors rather than returning an empty listing", {
  root <- make_tree()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  # An empty listing is indistinguishable from an empty folder, so this must throw.
  expect_error(datalib_explorer("no/such/node", root = root),
               class = "datalib_error_not_found")
})

test_that("the file-kind dispatch matches the shared corpus", {
  # The corpus lives at the repo root, deliberately outside the package: it is one
  # set of cases all three legs must pass, and a copy in inst/ would be a second
  # copy free to drift. Under R CMD check the repo does not exist, so this skips.
  tests_dir <- datalib_test_repo_tests_or_null()
  if (is.null(tests_dir)) {
    skip("tests/cases_filekind.csv lives at the repo root, not in the package")
  }
  cases_path <- file.path(tests_dir, "cases_filekind.csv")
  if (!file.exists(cases_path)) {
    skip("tests/cases_filekind.csv not found")
  }
  cases <- utils::read.csv(cases_path, stringsAsFactors = FALSE)
  expect_gt(nrow(cases), 10)
  got <- dl_file_kind(tolower(cases$ext))
  expect_identical(got, cases$kind)
})

test_that("index walks the whole subtree in one call", {
  root <- make_tree()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  idx <- datalib_index(root = root)
  expect_equal(nrow(idx), 4L)                  # every file, at every depth
  expect_equal(attr(idx, "n_files"), 4L)
  expect_false(attr(idx, "truncated"))
  expect_true("Alpha Land/Deep One/leaf.csv" %in% idx$relpath)
  expect_equal(idx$depth[idx$name == "leaf.csv"], 3L)
  expect_equal(idx$parent[idx$name == "notes.txt"], ".")
})

test_that("index: no extension is 'none' for a file and empty for a folder", {
  root <- make_tree()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  idx <- datalib_index(root = root, dirs = TRUE)
  expect_equal(idx$ext[idx$name == "NOEXT"], "none")
  expect_true(all(idx$ext[idx$is_dir] == ""))
})

test_that("index: the node cap is flagged, and bytes is NA until measured", {
  root <- make_tree()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  capped <- suppressWarnings(datalib_index(root = root, max_nodes = 1L))
  expect_true(attr(capped, "truncated"))
  expect_lt(attr(capped, "n_files"), 4L)
  # And it WARNS: a prefix returned silently is the defect the Stata leg shipped.
  expect_warning(datalib_index(root = root, max_nodes = 1L), "prefix")

  plain <- datalib_index(root = root)
  expect_true(all(is.na(plain$bytes)))
  measured <- datalib_index(root = root, sizes = TRUE)
  expect_true(all(measured$bytes >= 0))
})

test_that("index: max_depth caps the descent; pattern filters files not traversal", {
  root <- make_tree()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  shallow <- datalib_index(root = root, max_depth = 2L)
  expect_lte(max(shallow$depth), 2L)

  # The trap: filtering the TRAVERSAL as well would return nothing here, because
  # the only .csv sits three levels down.
  only_csv <- datalib_index(root = root, pattern = "\\.csv$")
  expect_equal(nrow(only_csv), 1L)
  expect_equal(only_csv$relpath, "Alpha Land/Deep One/leaf.csv")
})
