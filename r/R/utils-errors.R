# utils-errors.R -- classed condition constructors (internal)
#
# Contract error taxonomy (config/grammar.md section 6). The machine-readable
# mapping is tests/error_taxonomy.csv, asserted by test-taxonomy.R:
#
#   contract name        -> R class vector (most specific first)
#   input_invalid        -> datalib_error_input
#   not_found            -> datalib_error_not_found      + datalib_error_input
#   config_file_missing  -> datalib_error_config_missing
#   user_block_missing   -> datalib_error_user_missing
#   root_unset           -> datalib_error_root_unset     + datalib_error_input
#
# All classes inherit from "datalib_error".
#
# `dl_stop` takes a class VECTOR, most specific first. A specific class always
# keeps the general one after it, so a handler written against
# datalib_error_input before v0.9.7 keeps firing for a not_found or root_unset
# condition -- adding a subclass is never a breaking change in R. Verified:
#   tryCatch(err_not_found("x"), datalib_error_input = function(e) "caught")
# still returns "caught".

dl_stop <- function(class, message, call = sys.call(-1)) {
  cond <- structure(
    class = c(class, "datalib_error", "error", "condition"),
    list(message = message, call = call)
  )
  stop(cond)
}

err_input <- function(message, call = sys.call(-1)) {
  dl_stop("datalib_error_input", message, call)
}

# The requested country / survey / vintage / file is absent. Specific class
# first, general one retained for backward compatibility.
err_not_found <- function(message, call = sys.call(-1)) {
  dl_stop(c("datalib_error_not_found", "datalib_error_input"), message, call)
}

# No library root could be resolved from any precedence step.
err_root_unset <- function(message, call = sys.call(-1)) {
  dl_stop(c("datalib_error_root_unset", "datalib_error_input"), message, call)
}

err_config_missing <- function(message, call = sys.call(-1)) {
  dl_stop("datalib_error_config_missing", message, call)
}

err_user_missing <- function(message, call = sys.call(-1)) {
  dl_stop("datalib_error_user_missing", message, call)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# TRUE when x is a single non-empty, non-NA string-able value
nz_arg <- function(x) {
  !is.null(x) && length(x) == 1L && !is.na(x) && nzchar(trimws(as.character(x)))
}
