# utils-collections.R -- collection registry loader (internal)
#
# The registry (modules, module levels, linevars, merge keys) is the single
# source of truth at <repo>/config/collections.yml; the copy bundled at
# inst/collections.yml must match it byte-for-byte (asserted by the test
# suite). All merge semantics flow from here -- never hardcode module lists.

# Path to the bundled registry. The option `datalib.collections.path` is a
# development/test hook for running from a source tree without installation.
datalib_registry_path <- function() {
  opt <- getOption("datalib.collections.path", "")
  if (nz_arg(opt) && file.exists(opt)) return(opt)
  p <- system.file("collections.yml", package = "datalib")
  if (nzchar(p) && file.exists(p)) return(p)
  err_config_missing(paste0(
    "collections.yml not found: install the datalib package or set ",
    "options(datalib.collections.path = ...)."
  ))
}

# Parsed registry (full YAML document).
datalib_registry <- function() {
  yaml::read_yaml(datalib_registry_path())
}

# Registry block for one collection (NULL when the collection is unknown).
registry_collection <- function(collection) {
  reg <- datalib_registry()
  reg$collections[[toupper(trimws(collection))]]
}
