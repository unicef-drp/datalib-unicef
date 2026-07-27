# The error taxonomy has an enforcer, for R's column (grammar.md section 6).
#
# tests/error_taxonomy.csv is the machine-readable mapping; this file asserts
# R's share of it. Two things matter and neither was asserted before v0.9.7:
#
#   1. Every class the CSV names for a row is actually on the condition R raises
#      -- asserting the constructor exists is not enough, because a name can
#      survive a rename while nothing raises it any more.
#   2. The class vector is ordered specific-then-general, so a handler written
#      against datalib_error_input before the subclasses existed keeps firing.
#      That property is what makes adding an R subclass a non-breaking change,
#      and it is the reason the subclasses could land outside a major release.
#
# Python's column is asserted in test_taxonomy.py (which also checks grammar.md
# against the CSV); Stata's in run_conformance.do Part 8. Only the language
# itself can trigger its own errors.

rows <- read.csv(file.path(datalib_test_repo_tests(), "error_taxonomy.csv"),
                 colClasses = "character")
fixture <- datalib_test_fixture_root()

# One real trigger per contract error. Each returns a zero-argument function.
dl_trigger <- function(error_name) {
  switch(
    error_name,
    input_invalid = function() {
      datalib_vintages("ZWE", "notayear", "MICS", root = fixture)
    },
    not_found = function() {
      datalib_surveys("XXX", root = fixture)
    },
    config_file_missing = function() {
      datalib_config(config = file.path(tempdir(), "dl_no_such_config.yml"))
    },
    user_block_missing = function() {
      d <- file.path(tempdir(), "dl_tax_block")
      dir.create(d, recursive = TRUE, showWarnings = FALSE)
      f <- file.path(d, "user_config.yml")
      writeLines(c("someoneelse:", '  datalib: "Z:/x"'), f)
      datalib_config(user = "nobody", config = f)
    },
    root_unset = function() {
      # An empty config dir with no env var and no option: nothing can resolve.
      d <- file.path(tempdir(), "dl_tax_emptycfg")
      dir.create(d, recursive = TRUE, showWarnings = FALSE)
      withr::with_envvar(
        c(DATALIB_ROOT = NA, DATALIB_CONFIG = NA, DATALIB_CONFIG_DIR = NA),
        withr::with_options(
          list(datalib.root = NULL),
          datalib_root(configdir = d)
        )
      )
    },
    stop("no trigger defined for ", error_name)
  )
}

for (i in seq_len(nrow(rows))) {
  row <- rows[i, ]
  classes <- strsplit(trimws(row$r_classes), "[[:space:]]+")[[1]]

  label <- paste0("taxonomy ", row$error_name, ": documented classes are raised")
  test_that(label, {
    cond <- tryCatch(dl_trigger(row$error_name)(),
                     condition = function(c) c)
    expect_s3_class(cond, "condition")
    expect_s3_class(cond, "datalib_error")
    for (cl in classes) {
      expect_true(inherits(cond, cl),
                  info = paste0(row$error_name, " must carry class ", cl,
                                "; got: ", paste(class(cond), collapse = " ")))
    }
    # specific-then-general: the documented order is the class-vector order
    expect_identical(class(cond)[seq_along(classes)], classes)
  })
}

test_that("a subclassed error is still caught by a pre-v0.9.7 handler", {
  # The backward-compatibility property, asserted directly rather than assumed:
  # code written against datalib_error_input before datalib_error_not_found
  # existed must keep working.
  caught <- tryCatch(
    datalib_surveys("XXX", root = fixture),
    datalib_error_input = function(e) "general handler fired",
    error = function(e) "fell through"
  )
  expect_identical(caught, "general handler fired")
})

test_that("the taxonomy covers every contract error, in order", {
  expect_identical(rows$error_name,
                   c("input_invalid", "not_found", "config_file_missing",
                     "user_block_missing", "root_unset"))
})
