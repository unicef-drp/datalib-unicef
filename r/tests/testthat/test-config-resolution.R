# CFG golden cases -- the two-file config-root resolution contract
# (config/grammar.md section 7). Mirrored by python/tests/test_config_resolution.py
# and the Stata harness; the source_stage strings are identical across languages.

# Helper: write a per-user config block to <dir>/<name>.
write_cfg <- function(dir, name, body) {
  writeLines(body, file.path(dir, name))
}

# Each case runs in a temp dir wired as DATALIB_CONFIG_DIR, with the higher
# precedence sources (arg, env, option) cleared unless the case sets them.
local_cfg_env <- function(dir, env = list()) {
  withr::local_envvar(c(
    list(DATALIB_ROOT = "", DATALIB_CONFIG = "", DATALIB_CONFIG_DIR = dir),
    env
  ), .local_envir = parent.frame())
  withr::local_options(datalib.root = NULL, .local_envir = parent.frame())
}

U <- "testuser"
GEN <- "user_config.yml"
PKG <- "datalib_config.yml"

test_that("CFG-01 generic file only -> config_generic", {
  d <- withr::local_tempdir()
  write_cfg(d, GEN, c(paste0(U, ":"), '  datalib: "Z:/from_generic"'))
  local_cfg_env(d)
  r <- datalib_root(user = U)
  expect_equal(as.character(r), "Z:/from_generic")
  expect_equal(attr(r, "source_stage"), "config_generic")
  expect_equal(basename(attr(r, "source_file")), GEN)
})

test_that("CFG-02 package file only -> config_package", {
  d <- withr::local_tempdir()
  write_cfg(d, PKG, c(paste0(U, ":"), '  datalib: "Z:/from_package"'))
  local_cfg_env(d)
  r <- datalib_root(user = U)
  expect_equal(as.character(r), "Z:/from_package")
  expect_equal(attr(r, "source_stage"), "config_package")
})

test_that("CFG-03 both files carry the key -> generic wins", {
  d <- withr::local_tempdir()
  write_cfg(d, GEN, c(paste0(U, ":"), '  datalib: "Z:/from_generic"'))
  write_cfg(d, PKG, c(paste0(U, ":"), '  datalib: "Z:/from_package"'))
  local_cfg_env(d)
  r <- datalib_root(user = U)
  expect_equal(as.character(r), "Z:/from_generic")
  expect_equal(attr(r, "source_stage"), "config_generic")
})

test_that("CFG-04 generic block WITHOUT datalib key -> falls through to package (key-presence)", {
  d <- withr::local_tempdir()
  # generic has the user block but no datalib key:
  write_cfg(d, GEN, c(paste0(U, ":"), '  githubFolder: "C:/GitHub"'))
  write_cfg(d, PKG, c(paste0(U, ":"), '  datalib: "Z:/from_package"'))
  local_cfg_env(d)
  r <- datalib_root(user = U)
  expect_equal(as.character(r), "Z:/from_package")
  expect_equal(attr(r, "source_stage"), "config_package")
})

test_that("CFG-05 no datalib key anywhere -> root-unset error", {
  d <- withr::local_tempdir()
  write_cfg(d, GEN, c(paste0(U, ":"), '  githubFolder: "C:/GitHub"'))
  local_cfg_env(d)
  expect_error(datalib_root(user = U), class = "datalib_error_input")
})

test_that("CFG-06 DATALIB_ROOT env beats both files -> env", {
  d <- withr::local_tempdir()
  write_cfg(d, GEN, c(paste0(U, ":"), '  datalib: "Z:/from_generic"'))
  local_cfg_env(d, env = list(DATALIB_ROOT = "Z:/from_env"))
  r <- datalib_root(user = U)
  expect_equal(as.character(r), "Z:/from_env")
  expect_equal(attr(r, "source_stage"), "env")
})

test_that("CFG-07 DATALIB_CONFIG pins one file, fallback disabled", {
  d <- withr::local_tempdir()
  # generic in the dir has a key, but DATALIB_CONFIG points ONLY at the package file:
  write_cfg(d, GEN, c(paste0(U, ":"), '  datalib: "Z:/from_generic"'))
  write_cfg(d, PKG, c(paste0(U, ":"), '  datalib: "Z:/pinned"'))
  local_cfg_env(d, env = list(DATALIB_CONFIG = file.path(d, PKG)))
  r <- datalib_root(user = U)
  expect_equal(as.character(r), "Z:/pinned")
  expect_equal(attr(r, "source_stage"), "config_package")
})

test_that("CFG-08 parser floor: comments + multiple user blocks -> correct block read", {
  d <- withr::local_tempdir()
  write_cfg(d, GEN, c(
    "# shared operator config",
    "otheruser:",
    '  datalib: "Z:/WRONG"',
    paste0(U, ":"),
    "  githubFolder: \"C:/GitHub\"   # inline comment",
    '  datalib: "Z:/correct"'
  ))
  local_cfg_env(d)
  r <- datalib_root(user = U)
  expect_equal(as.character(r), "Z:/correct")
  expect_equal(attr(r, "source_stage"), "config_generic")
})

test_that("CFG-09 empty datalib value in generic -> treated as absent, falls through", {
  d <- withr::local_tempdir()
  write_cfg(d, GEN, c(paste0(U, ":"), '  datalib: ""'))
  write_cfg(d, PKG, c(paste0(U, ":"), '  datalib: "Z:/from_package"'))
  local_cfg_env(d)
  r <- datalib_root(user = U)
  expect_equal(as.character(r), "Z:/from_package")
  expect_equal(attr(r, "source_stage"), "config_package")
})

test_that("argument and option stages report correctly", {
  d <- withr::local_tempdir()
  local_cfg_env(d)
  ra <- datalib_root("Z:/explicit", user = U)
  expect_equal(attr(ra, "source_stage"), "argument")
  withr::local_options(datalib.root = "Z:/opt")
  ro <- datalib_root(user = U)
  expect_equal(attr(ro, "source_stage"), "option")
})
