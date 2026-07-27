# datalib-package.R -- package-level documentation and namespace imports
#
# Single home for the package's @importFrom tags so the roxygen-generated
# NAMESPACE reproduces the contract-v1 import set exactly (fs, haven, yaml).

#' @keywords internal
#' @importFrom fs dir_create dir_exists dir_ls file_exists path path_expand path_norm
#' @importFrom haven read_dta
#' @importFrom yaml read_yaml
"_PACKAGE"
