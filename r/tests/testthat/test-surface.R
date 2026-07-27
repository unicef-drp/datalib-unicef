# R's column of the declared public surface (config/surface.yml).
#
# The rule people want is "an argument may not be added until it is documented".
# That ordering cannot be tested -- a test sees a snapshot of the tree, not its
# history -- so what is tested is the equivalent invariant: at every commit, the
# implemented surface EQUALS the declared surface. With CI required on the branch,
# declaring first becomes the only way to land code.
#
# Ordered comparison, not set: R matches arguments positionally, and test-docs.R
# already pins each \arguments section to formals() IN ORDER. So this file plus
# test-docs.R together mean an undeclared argument cannot reach either the code or
# the documentation.
#
# Stata's and Python's columns are enforced in python/tests/test_surface.py --
# .ado and .sthlp are plain text, so Stata needs no licence to be checked, and it
# was previously the only completely unguarded surface in the repo.

surface_path <- file.path(dirname(datalib_test_repo_tests()), "config", "surface.yml")

test_that("config/surface.yml is present and readable", {
  expect_true(file.exists(surface_path))
})

surface <- yaml::read_yaml(surface_path)

test_that("the declared surface is exactly the exported surface", {
  # Replaces a hand-typed list that used to live in test-docs.R and cited
  # grammar.md in a comment while nothing read it -- a third copy, free to drift.
  #
  # Exports = the 13 canonical contract commands PLUS the maintenance function.
  # datalib_update is deliberately NOT in surface.yml `commands:`: which version you
  # are running, and where a newer one lives, is a question about deployment rather
  # than about the folder grammar. Folding it into `commands:` would make the
  # canonical count 14 and quietly destroy the meaning of the Stata-side guard
  # test_subcommands_are_exactly_the_canonical_commands.
  ns <- readLines(file.path(datalib_test_pkg_root(), "NAMESPACE"), warn = FALSE)
  exports <- sub("^export\\(([^)]+)\\)$", "\\1", grep("^export\\(", ns, value = TRUE))
  expected <- c(names(surface$commands), surface$maintenance$r$name)
  expect_setequal(exports, expected)
})

test_that("the maintenance function's formals match the declaration", {
  declared <- as.character(surface$maintenance$r$args)
  fn <- get(surface$maintenance$r$name, mode = "function")
  expect_identical(names(formals(fn)), declared)
})

test_that("the R maintenance function does not install", {
  # surface.yml declares installs: false, and it must stay false --
  # install.packages() over a loaded namespace is unsafe on Windows, where the
  # package's own files are locked by the running session. Assert against the
  # SOURCE rather than trusting the declaration.
  expect_false(isTRUE(surface$maintenance$r$installs))
  # Inspect the PARSE TREE, not the text. The function deliberately prints the
  # string "install.packages(...)" as the command for the user to run, so a grep
  # over the source matches that literal and reports a call that does not exist.
  # all.names() walks the expression tree, where a string literal is not a name --
  # so this is true only if the function really calls it.
  fn <- get(surface$maintenance$r$name, mode = "function")
  called <- all.names(body(fn))
  for (forbidden in c("install.packages", "remotes::install_github", "system",
                      "system2", "unlink", "file.remove")) {
    expect_false(forbidden %in% called,
                 info = paste0("datalib_update must not call ", forbidden))
  }
})

test_that("the version comparison is numeric, not textual", {
  # The trap: as TEXT "0.9.10" sorts BELOW "0.9.9", so a string comparison reports
  # a newer release as older. This is the reason the comparison exists at all, and
  # it is asserted here rather than through datalib_update() because on a machine
  # where the package is SOURCED there is no installed version, so the report path
  # can never reach the comparison.
  expect_identical(.dl_version_status("0.9.9",  "0.9.10"), "newer_available")
  expect_identical(.dl_version_status("0.9.10", "0.9.9"),  "source_behind")
  expect_identical(.dl_version_status("0.9.10", "0.9.10"), "current")
  expect_identical(.dl_version_status(NA_character_, "0.9.10"), "unknown")
  expect_identical(.dl_version_status("0.9.10", NA_character_), "unknown")
})

for (cmd in names(surface$commands)) {
  declared <- as.character(surface$commands[[cmd]]$r)
  test_that(paste0(cmd, ": formals match the declaration"), {
    expect_true(exists(cmd, mode = "function"),
                info = paste0(cmd, " is declared but not defined"))
    actual <- names(formals(get(cmd, mode = "function")))
    expect_identical(actual, declared)
  })
}

test_that("every source_stage R can report is declared", {
  # datalib_root attaches source_stage; the vocabulary is declared per language
  # because the mechanisms genuinely differ (an R option is not a Stata global).
  declared <- as.character(surface$source_stage$r)
  expect_true(all(declared %in% as.character(surface$source_stage$vocabulary)))
  # the stages R can actually produce, from the resolver's own source
  src <- readLines(file.path(datalib_test_pkg_root(), "R", "datalib_root.R"),
                   warn = FALSE)
  emitted <- unique(unlist(regmatches(
    src, gregexpr('"(argument|env|option|config_generic|config_package|unset)"', src))))
  emitted <- gsub('"', "", emitted)
  undeclared <- setdiff(emitted, declared)
  expect_identical(undeclared, character(0),
                   info = paste("stage(s) emitted by datalib_root.R but not",
                                "declared for R in config/surface.yml:",
                                paste(undeclared, collapse = " ")))
})
