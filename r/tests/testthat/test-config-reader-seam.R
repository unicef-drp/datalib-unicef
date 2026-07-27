# The PUBLIC reader must honour the same config seam as datalib_root().
#
# Until v0.9.4 datalib_config() hardcoded ~/.config/user_config.yml: the
# two-file fallback and the DATALIB_CONFIG / DATALIB_CONFIG_DIR hooks lived
# only in datalib_root()'s private helpers. So the two public functions
# disagreed about where configuration lives -- datalib_root() worked on a
# machine configured via datalib_config.yml while datalib_config() reported
# datalib_error_config_missing. The CFG cases never caught it because they only
# ever called datalib_root().
#
# These cases call the reader DIRECTLY. Mirrors config/grammar.md section 7.

write_cfg2 <- function(dir, name, body) writeLines(body, file.path(dir, name))

clear_higher <- function(dir = NULL, env = list()) {
  withr::local_envvar(c(
    list(DATALIB_ROOT = "", DATALIB_CONFIG = "",
         DATALIB_CONFIG_DIR = if (is.null(dir)) "" else dir),
    env
  ), .local_envir = parent.frame())
  withr::local_options(datalib.root = NULL, .local_envir = parent.frame())
}

U2 <- "seamuser"
GEN2 <- "user_config.yml"
PKG2 <- "datalib_config.yml"

test_that("the reader falls back to datalib_config.yml (the v0.9.4 fix)", {
  d <- withr::local_tempdir()
  write_cfg2(d, PKG2, c(paste0(U2, ":"), '  datalib: "Z:/from_package"'))
  clear_higher(d)
  cfg <- datalib_config(user = U2)
  expect_equal(cfg$datalib, "Z:/from_package")
  expect_equal(cfg$source_stage, "config_package")
  expect_equal(basename(cfg$source_file), PKG2)
})

test_that("the reader prefers the generic file for the root", {
  d <- withr::local_tempdir()
  write_cfg2(d, GEN2, c(paste0(U2, ":"), '  datalib: "Z:/from_generic"'))
  write_cfg2(d, PKG2, c(paste0(U2, ":"), '  datalib: "Z:/from_package"'))
  clear_higher(d)
  cfg <- datalib_config(user = U2)
  expect_equal(cfg$datalib, "Z:/from_generic")
  expect_equal(cfg$source_stage, "config_generic")
})

test_that("key-presence, not file-presence: a generic file without the key falls through", {
  d <- withr::local_tempdir()
  write_cfg2(d, GEN2, c(paste0(U2, ":"), '  githubFolder: "C:/gh"'))
  write_cfg2(d, PKG2, c(paste0(U2, ":"), '  datalib: "Z:/from_package"'))
  clear_higher(d)
  cfg <- datalib_config(user = U2)
  # the BLOCK comes from the first file that has it ...
  expect_equal(basename(cfg$config), GEN2)
  expect_equal(cfg$githubFolder, "C:/gh")
  # ... while the ROOT comes from the first file whose block carries the key
  expect_equal(cfg$datalib, "Z:/from_package")
  expect_equal(cfg$source_stage, "config_package")
})

test_that("an empty value counts as absent", {
  d <- withr::local_tempdir()
  write_cfg2(d, GEN2, c(paste0(U2, ":"), '  datalib: ""'))
  write_cfg2(d, PKG2, c(paste0(U2, ":"), '  datalib: "Z:/from_package"'))
  clear_higher(d)
  expect_equal(datalib_config(user = U2)$source_stage, "config_package")
})

test_that("no key anywhere -> source_stage 'unset', not an error", {
  d <- withr::local_tempdir()
  write_cfg2(d, GEN2, c(paste0(U2, ":"), '  githubFolder: "C:/gh"'))
  clear_higher(d)
  cfg <- datalib_config(user = U2)
  expect_equal(cfg$datalib, "")
  expect_equal(cfg$source_stage, "unset")
  expect_equal(cfg$source_file, "")
})

test_that("configdir= searches another directory without touching env vars", {
  d <- withr::local_tempdir()
  write_cfg2(d, GEN2, c(paste0(U2, ":"), '  datalib: "Z:/from_configdir"'))
  clear_higher(NULL)          # no DATALIB_CONFIG_DIR at all
  cfg <- datalib_config(user = U2, configdir = d)
  expect_equal(cfg$datalib, "Z:/from_configdir")
  expect_equal(cfg$source_stage, "config_generic")
})

test_that("configdir= reaches datalib_root() too", {
  d <- withr::local_tempdir()
  write_cfg2(d, PKG2, c(paste0(U2, ":"), '  datalib: "Z:/via_root"'))
  clear_higher(NULL)
  r <- datalib_root(user = U2, configdir = d)
  expect_equal(as.character(r), "Z:/via_root")
  expect_equal(attr(r, "source_stage"), "config_package")
})

test_that("config= pins one file and disables the fallback", {
  d <- withr::local_tempdir()
  write_cfg2(d, GEN2, c(paste0(U2, ":"), '  datalib: "Z:/generic"'))
  write_cfg2(d, PKG2, c(paste0(U2, ":"), '  datalib: "Z:/package"'))
  clear_higher(d)
  cfg <- datalib_config(user = U2, config = file.path(d, PKG2))
  expect_equal(cfg$datalib, "Z:/package")
  # pinned to a file with no block for this user -> user_missing, not fallback
  write_cfg2(d, "lonely.yml", c("someone_else:", '  datalib: "Z:/x"'))
  expect_error(datalib_config(user = U2, config = file.path(d, "lonely.yml")),
               class = "datalib_error_user_missing")
})

test_that("no file at all -> config_missing naming the expected path", {
  d <- withr::local_tempdir()
  clear_higher(d)
  expect_error(datalib_config(user = U2), class = "datalib_error_config_missing")
})

test_that("a malformed fallback file does not break a working primary one", {
  d <- withr::local_tempdir()
  write_cfg2(d, GEN2, c(paste0(U2, ":"), '  datalib: "Z:/good"'))
  write_cfg2(d, PKG2, c("this: [is: not", "  valid yaml: ["))
  clear_higher(d)
  cfg <- datalib_config(user = U2)
  expect_equal(cfg$datalib, "Z:/good")
})
