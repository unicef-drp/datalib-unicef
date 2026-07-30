# datalib-package.R -- package-level documentation and namespace imports
#
# Two jobs:
#   1. the single home for @importFrom tags, so the roxygen-generated NAMESPACE
#      reproduces the contract-v1 import set exactly (fs, haven, yaml)
#   2. the package overview page -- ?datalib -- which is the entry point a new user
#      lands on, so it carries the function index, the how-to, and runnable examples
#      rather than deferring all of that to 16 separate pages

#' datalib: access the UNICEF survey-microdata library from R
#'
#' Resolves, lists and loads survey microdata held in a **datalib library** -- a
#' folder tree whose names encode the survey, its version and its provenance, so
#' the library needs no database and no index. `datalib` is the R port of the
#' language-neutral **datalib contract v1**, shared byte-for-byte with the Stata
#' and Python implementations.
#'
#' @details
#' # The grammar, in one line
#'
#' \preformatted{<root>/<CCC>/<CCC>_<YYYY>_<SURVEY>/<vintage>/<section>/}
#'
#' A **vintage** is either a *master* (`_vNN_M`) or an *adaptation*
#' (`_vNN_M_vNN_A_<COLLECTION>`). An adaptation names the master it derives from,
#' which is what lets [datalib_resolve()] answer "the HLT adaptation of the latest
#' master" from the folder names alone. **Sections** are `Data/Stata`,
#' `Data/Original`, `Data/R`, `Data/Other`, `Doc` and `Programs`.
#'
#' \preformatted{Z:/datalib/ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M_v01_A_HLT/Data/Stata/
#'                                            |    |    |   |   |   |
#'                                    country_|    |    |   |   |   |_ collection
#'                                        year_____|    |   |   |
#'                                          survey______|   |   |_ adaptation v01
#'                                              master v02______|}
#'
#' # The functions
#'
#' Thirteen commands are the **contract** -- identical in name and meaning across
#' Stata, R and Python. Three more are R-and-Python conveniences.
#'
#' \strong{Where is the library?}
#' \tabular{ll}{
#'   [datalib_config()]  \tab read the resolved configuration, and report which
#'                            precedence stage supplied it \cr
#'   [datalib_root()]    \tab resolve the library root; also `mark`/`set` a root \cr
#'   [datalib_map_drive()] \tab mount the LAN share on a drive letter (Windows) \cr
#' }
#'
#' \strong{What is in it?} These walk the grammar and return data frames.
#' \tabular{ll}{
#'   [datalib_countries()]   \tab country codes present \cr
#'   [datalib_surveys()]     \tab surveys for a country \cr
#'   [datalib_vintages()]    \tab every vintage of one survey, master and adaptation \cr
#'   [datalib_adaptations()] \tab just the adaptations, with their collections \cr
#'   [datalib_catalog()]     \tab the whole library, or one country, as one table \cr
#'   [datalib_browse()]      \tab the choices available at one point, for building a picker \cr
#' }
#'
#' \strong{Which files, and give me the data.}
#' \tabular{ll}{
#'   [datalib_resolve()] \tab the paths of exactly one vintage -- everything below
#'                            is built on this \cr
#'   [datalib_files()]   \tab one row per file in one section, with the module parsed
#'                            from each name \cr
#'   [datalib_load()]    \tab read modules into R, merged on registry-declared keys \cr
#'   [datalib_create()]  \tab propose (or create) the next vintage's folders \cr
#' }
#'
#' \strong{Trees that do not follow the grammar.} Everything above reads a folder's
#' ancestry out of its *name*. These two parse nothing, for archives nobody has
#' renamed yet.
#' \tabular{ll}{
#'   [datalib_explorer()] \tab one node: its folders, files, sizes and extensions \cr
#'   [datalib_index()]    \tab a whole subtree as a data frame, one row per file \cr
#' }
#'
#' \strong{Housekeeping.}
#' \tabular{ll}{
#'   [datalib_update()] \tab report whether the net site holds a newer version \cr
#' }
#'
#' # How to use it
#'
#' **1. Point at a library.** Every function takes `root =`. Omit it and the root is
#' resolved through a documented precedence chain whose *winning stage* is reported,
#' so a machine that resolves the wrong root can be diagnosed instead of guessed at:
#'
#' \preformatted{cfg <- datalib_config()
#' cfg$datalib       # the root
#' cfg$source_stage  # argument | env | option | config_generic | config_package | unset}
#'
#' **2. Find the vintage you want.** Version defaults are *numeric-latest*, never
#' alphabetical, and omitting `year` or `survey` means "the newest":
#'
#' \preformatted{datalib_resolve("ZWE", 2019, "MICS", collection = "HLT")   # latest HLT adaptation
#' datalib_resolve("ZWE", 2019, "MICS", kind = "master")      # latest master
#' datalib_resolve("KEN")                                     # latest survey, latest vintage}
#'
#' **3. Load it.** Merge keys come from the collection registry
#' (`config/collections.yml`), never from guessing. Person-level modules chain 1:1,
#' then household-level modules attach m:1; a module whose keys do not uniquely
#' identify its rows stops the merge rather than silently multiplying rows:
#'
#' \preformatted{datalib_load("ZWE", 2019, "MICS", collection = "HLT",
#'              module = c("household", "children"))}
#'
#' # Two rules worth knowing before you rely on the results
#'
#' **Enumerators return empty; resolvers raise.** Asking a country for a survey it
#' does not have is a legitimate question with the answer "none", so
#' [datalib_surveys()] gives you zero rows. Asking [datalib_resolve()] for a vintage
#' that does not exist is a mistake, so it errors. "No results" and "you asked about
#' something that does not exist" are different problems and must not look the same.
#'
#' **Errors are typed.** Every failure carries a condition class -- match on the
#' class, not on the English message:
#'
#' \preformatted{tryCatch(datalib_resolve("XXX", 2019, "MICS"),
#'          datalib_error_not_found = function(e) NULL)}
#'
#' Classes: `datalib_error_input`, `datalib_error_not_found`,
#' `datalib_error_root_unset`, `datalib_error_config_missing`,
#' `datalib_error_user_missing`, all inheriting `datalib_error`.
#'
#' # Installing and upgrading
#'
#' Not on CRAN; the LAN share is the supported path. **Note the `utils::` prefix** --
#' plain `install.packages()` installs correctly but then errors in RStudio, whose
#' hook mistakes the tarball path for an installed-package directory:
#'
#' \preformatted{utils::install.packages("Z:/_pkg/datalib/R/datalib_0.9.28.tar.gz",
#'                         repos = NULL, type = "source")}
#'
#' `repos = NULL` resolves no dependencies, so on a fresh machine install
#' `yaml`, `haven` and `fs` first. [datalib_update()] reports whether something newer
#' exists but deliberately does **not** install: `install.packages()` over a loaded
#' namespace is unsafe on Windows, where the running session locks the package's own
#' files. Install, then restart the session -- the R equivalent of Stata's
#' `discard`. See the R README for the full account.
#'
#' # A guided tour
#'
#' A runnable demo exercises **every** exported function against a throwaway library
#' it builds under `tempdir()`, so it needs no share mounted and prints the same
#' thing every time. Its final section asserts that nothing was missed:
#'
#' \preformatted{source(system.file("examples", "datalib_demo.R", package = "datalib"))}
#'
#' @section Relationship to the Stata and Python ports:
#' The thirteen contract commands carry the same names and semantics in all three
#' languages, and one shared corpus of golden cases (`tests/cases_*.csv`) is run by
#' all three suites. Differences that remain are recorded in `tests/DIVERGENCES.md`
#' rather than left to be discovered. The largest is deliberate: Stata's
#' `datalib_explorer` prints a *clickable* listing, and there is no console hyperlink
#' in R -- so R returns the file-type dispatch as the `open_with` data frame instead
#' of pretending to offer links.
#'
#' @examples
#' # Every example below is self-contained: it builds a small library under
#' # tempdir(), so nothing needs Z:/datalib to be mounted.
#' root <- file.path(tempdir(), "datalib_example_lib")
#' survey <- file.path(root, "ZWE", "ZWE_2019_MICS")
#'
#' # BOTH a master and its adaptation. An adaptation derives from a master, so a
#' # library holding one without the other is malformed -- and datalib says so
#' # rather than guessing.
#' master  <- file.path(survey, "ZWE_2019_MICS_v02_M")
#' adapted <- file.path(survey, "ZWE_2019_MICS_v02_M_v01_A_HLT")
#' for (v in c(master, adapted)) {
#'   dir.create(file.path(v, "Data", "Stata"), recursive = TRUE, showWarnings = FALSE)
#'   dir.create(file.path(v, "Doc"), recursive = TRUE, showWarnings = FALSE)
#' }
#'
#' # Modules are <vintage-stem>_<module>.dta -- the suffix IS the module name.
#' # HLT keys, from the collection registry: svy_id, cluster_id, household_id.
#' hh <- data.frame(svy_id = 1L, cluster_id = 1L, household_id = 1:3, hh_size = 4:6)
#' for (v in c(master, adapted)) {
#'   haven::write_dta(hh, file.path(v, "Data", "Stata",
#'                                  paste0(basename(v), "_household.dta")))
#' }
#'
#' # -- Where is the library, and what is in it? -------------------------------
#' datalib_countries(root = root)
#' datalib_surveys("ZWE", root = root)
#' datalib_vintages("ZWE", 2019, "MICS", root = root)
#' datalib_catalog(root = root)
#'
#' # -- Which files? -----------------------------------------------------------
#' res <- datalib_resolve("ZWE", 2019, "MICS", collection = "HLT", root = root)
#' res$file_stem
#' datalib_files("ZWE", 2019, "MICS", collection = "HLT", section = "data",
#'               root = root)
#'
#' # -- Read the data ----------------------------------------------------------
#' datalib_load("ZWE", 2019, "MICS", collection = "HLT", module = "household",
#'              root = root)
#'
#' # -- Enumerators return empty; resolvers raise ------------------------------
#' nrow(datalib_surveys("ZWE", survey = "DHS", root = root))   # 0, not an error
#' tryCatch(datalib_resolve("XXX", 2019, "MICS", root = root),
#'          datalib_error = function(e) conditionMessage(e))
#'
#' # -- Trees that ignore the grammar ------------------------------------------
#' node <- datalib_explorer(root = root)
#' node$n_dirs
#' idx <- datalib_index(root = root)
#' idx[, c("relpath", "ext", "depth")]
#'
#' unlink(root, recursive = TRUE)
#'
#' @seealso
#' [datalib_resolve()] to start with one vintage, [datalib_catalog()] for the whole
#' library at once, [datalib_explorer()] and [datalib_index()] for trees that do not
#' follow the grammar. The contract itself is `config/grammar.md`; the collection
#' registry `config/collections.yml`.
#'
#' @keywords internal
#' @importFrom fs dir_create dir_exists dir_ls file_exists path path_expand path_norm
#' @importFrom haven read_dta
#' @importFrom yaml read_yaml
"_PACKAGE"
