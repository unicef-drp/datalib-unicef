# ---------------------------------------------------------------------------
# datalib for R -- a tour of every exported function
#
#   source(system.file("examples", "datalib_demo.R", package = "datalib"))
#
# Self-contained. It builds a small library under tempdir() rather than pointing at
# Z:/datalib, so it runs on a laptop with no share mounted, produces the same output
# every time, and doubles as a worked example of the naming grammar. The real share is
# used only where it is the point -- the arbitrary-tree functions -- and is skipped when
# absent.
#
# Self-verifying. Section 14 asserts that every function datalib exports was actually
# called. A demo that claims to show "all features" and quietly misses one is worse than
# a demo that admits its scope, so the claim is checked rather than asserted.
#
# Side-effect-safe. Two functions can change your machine, and both are demonstrated in
# their harmless mode, called out where they appear:
#   datalib_create()     create = FALSE (the default) -- reports the path, writes nothing
#   datalib_map_drive()  dry_run = TRUE (NOT the default) -- would really map a drive
# ---------------------------------------------------------------------------

library(datalib)

`%||%` <- function(x, y) if (is.null(x)) y else x
.shown <- character(0)
show_fn <- function(...) .shown <<- union(.shown, c(...))

hdr <- function(n, title) cat(sprintf("\n%s\n== %s. %s\n%s\n", strrep("=", 74), n, title,
                                      strrep("=", 74)))
note <- function(...) cat("   ", ..., "\n", sep = "")

# ---------------------------------------------------------------------------
hdr(0, "Build a throwaway library, so this runs anywhere")
# ---------------------------------------------------------------------------
# The grammar: <root>/<CCC>/<CCC>_<YYYY>_<SURVEY>/<vintage>/<section>/
# A vintage is either a MASTER  (_vNN_M) or an ADAPTATION (_vNN_M_vNN_A_<COLLECTION>).
# The adaptation names the master it derives from, which is what lets datalib resolve
# "the HLT adaptation of the latest master" without a database.

root <- file.path(tempdir(), "datalib_demo_lib")
unlink(root, recursive = TRUE)

vintages <- c(
  "ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v01_M",                    # an older master
  "ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M",                    # the latest master
  "ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M_v01_A_HLT",          # health adaptation
  "ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M_v01_A_IPUMS",        # a second collection
  # KEN has TWO surveys, so "omit the year and survey" has something to choose between.
  # Each carries its own master: an adaptation derives from a master, so a library with
  # an adaptation and no master is malformed -- and datalib says so rather than guessing.
  "KEN/KEN_2014_DHS/KEN_2014_DHS_v01_M",
  "KEN/KEN_2014_DHS/KEN_2014_DHS_v01_M_v01_A_HLT",
  "KEN/KEN_2022_MICS/KEN_2022_MICS_v01_M",
  "KEN/KEN_2022_MICS/KEN_2022_MICS_v01_M_v01_A_HLT",
  "BRA/BRA_2015_PNAD/BRA_2015_PNAD_v09_M"
)
sections <- c("Data/Stata", "Data/Original", "Data/R", "Data/Other", "Doc", "Programs")
for (v in vintages) {
  for (s in sections) dir.create(file.path(root, v, s), recursive = TRUE, showWarnings = FALSE)
}

# Modules are <vintage-stem>_<module>.dta -- the suffix IS the module name, which is how
# datalib_files() and datalib_load() find them without an index.
#
# The demo data has to satisfy the COLLECTION REGISTRY (config/collections.yml), which
# declares each module's level and the merge keys for that level:
#
#   HLT   keys_hh     svy_id cluster_id household_id
#         keys_person svy_id cluster_id household_id line_number
#         household = hh   hhmembers/adult/children = person
#         hhmembers reads its line variable from hh_line_number
#
# Keys must UNIQUELY identify rows (isid-equivalent) or datalib_load(merge = TRUE)
# refuses -- which is the point: keys are read from the registry, never guessed, and a
# module whose identifiers do not hold up stops the merge instead of silently
# multiplying rows. Writing this demo got that wrong first, and the error said so.
HLT_SPEC   <- list(household = list(level = "hh"),
                   hhmembers = list(level = "person", linevar = "hh_line_number"),
                   adult     = list(level = "person"),
                   children  = list(level = "person"))
IPUMS_SPEC <- list(hh = list(level = "hh"), ch = list(level = "person"))
HH_ONLY    <- list(household = list(level = "hh"))

write_modules <- function(vintage, spec, nhh = 3L, nper = 2L) {
  stem <- basename(vintage)
  for (m in names(spec)) {
    linevar <- spec[[m]]$linevar %||% "line_number"
    if (identical(spec[[m]]$level, "hh")) {
      d <- data.frame(svy_id = 1L, cluster_id = 1L, household_id = seq_len(nhh))
    } else {
      g <- expand.grid(line = seq_len(nper), household_id = seq_len(nhh))
      d <- data.frame(svy_id = 1L, cluster_id = 1L, household_id = g$household_id)
      d[[linevar]] <- g$line
    }
    d[[paste0(m, "_value")]] <- round(seq_len(nrow(d)) * 1.5, 1)
    haven::write_dta(d, file.path(root, vintage, "Data", "Stata",
                                  paste0(stem, "_", m, ".dta")))
  }
}
write_modules("ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M",               HH_ONLY)
write_modules("ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M_v01_A_HLT",     HLT_SPEC)
write_modules("ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M_v01_A_IPUMS",   IPUMS_SPEC)
write_modules("KEN/KEN_2014_DHS/KEN_2014_DHS_v01_M",                 HH_ONLY)
write_modules("KEN/KEN_2014_DHS/KEN_2014_DHS_v01_M_v01_A_HLT",       HLT_SPEC["household"])
write_modules("KEN/KEN_2022_MICS/KEN_2022_MICS_v01_M",               HH_ONLY)
write_modules("KEN/KEN_2022_MICS/KEN_2022_MICS_v01_M_v01_A_HLT",     HLT_SPEC[c("household", "children")])
write_modules("BRA/BRA_2015_PNAD/BRA_2015_PNAD_v09_M",               HH_ONLY)

# A codebook, so the Doc section is not empty when we list it.
writeLines(c("ZWE 2019 MICS -- demo codebook", "household: one row per household"),
           file.path(root, "ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M_v01_A_HLT/Doc",
                     "codebook.txt"))

note("library root : ", root)
note("vintages     : ", length(vintages), "   files: ",
     length(list.files(root, recursive = TRUE)))

# ---------------------------------------------------------------------------
hdr(1, "datalib_config() and datalib_root() -- where does the root come from?")
# ---------------------------------------------------------------------------
# Every function takes root = explicitly. When you omit it, the root is resolved through
# a documented precedence chain, and the WINNING STAGE is reported -- so a machine that
# resolves the wrong root can be diagnosed instead of guessed at.

cfg <- datalib_config()
show_fn("datalib_config")
note("source_stage : ", cfg$source_stage %||% "<unset>")
note("source_file  : ", cfg$source_file %||% "<none>")
note("datalib key  : ", cfg$datalib %||% "<unset>")

resolved <- datalib_root(root)
show_fn("datalib_root")
note("datalib_root(explicit) -> ", resolved)
note("returned as given, not normalised: a path is an identity, not a spelling")

# ---------------------------------------------------------------------------
hdr(2, "Enumerate: countries -> surveys -> vintages -> adaptations")
# ---------------------------------------------------------------------------
# These are the read-only walk of the grammar. An absent PARENT is an error; a present
# but EMPTY container is an empty answer with count 0. The distinction matters: "no
# adaptations yet" and "you asked about a survey that does not exist" are different
# problems and must not look the same.

print(datalib_countries(root = root));                     show_fn("datalib_countries")
print(datalib_surveys("ZWE", root = root));                show_fn("datalib_surveys")
print(datalib_vintages("ZWE", 2019, "MICS", root = root)); show_fn("datalib_vintages")
print(datalib_adaptations("ZWE", 2019, "MICS", root = root)); show_fn("datalib_adaptations")

note("")
note("BRA has a master but no adaptation -- an empty answer, not an error:")
print(datalib_adaptations("BRA", 2015, "PNAD", root = root))

# ---------------------------------------------------------------------------
hdr(3, "datalib_resolve() -- the one function everything else is built on")
# ---------------------------------------------------------------------------
# Given a survey it returns the paths of one vintage. Defaults are numeric-latest, so
# omitting year/version means "the newest", never "the alphabetically last".

r_adapt <- datalib_resolve("ZWE", 2019, "MICS", collection = "HLT", root = root)
show_fn("datalib_resolve")
note("kind               : ", r_adapt$kind)
note("master_version     : ", r_adapt$master_version)
note("adaptation_version : ", r_adapt$adaptation_version)
note("file_stem          : ", r_adapt$file_stem)
note("data_stata         : ", r_adapt$data_stata)

note("")
note("the MASTER of the same survey -- v02 wins over v01 numerically:")
r_master <- datalib_resolve("ZWE", 2019, "MICS", kind = "master", root = root)
note("file_stem          : ", r_master$file_stem)

note("")
note("a second collection of the same master, resolved by name:")
note("file_stem          : ",
     datalib_resolve("ZWE", 2019, "MICS", collection = "IPUMS", root = root)$file_stem)

note("")
note("year and survey omitted -- the latest of each is chosen:")
note("file_stem          : ", datalib_resolve("KEN", root = root)$file_stem)

# ---------------------------------------------------------------------------
hdr(4, "datalib_files() -- list one section of one vintage")
# ---------------------------------------------------------------------------
# One row per file. In the data section the `module` column carries the suffix parsed
# from <stem>_<module>.dta, which is NA for a file that does not follow the grammar.

f_data <- datalib_files("ZWE", 2019, "MICS", collection = "HLT", section = "data",
                        root = root)
show_fn("datalib_files")
print(f_data[, c("file", "module", "section")])

note("")
note("the doc section of the same vintage:")
print(datalib_files("ZWE", 2019, "MICS", collection = "HLT", section = "doc",
                    root = root)[, c("file", "section")])

note("")
note("a section that exists but holds nothing -- 0 rows, not an error:")
note("rows in Data/R: ",
     nrow(datalib_files("ZWE", 2019, "MICS", collection = "HLT", section = "data-r",
                        root = root)))

# ---------------------------------------------------------------------------
hdr(5, "datalib_catalog() -- the whole library as one table")
# ---------------------------------------------------------------------------
cat_all <- datalib_catalog(root = root)
show_fn("datalib_catalog")
print(cat_all)
note("")
note("filtered to one country:")
print(datalib_catalog(country = "ZWE", root = root))

# ---------------------------------------------------------------------------
hdr(6, "datalib_load() -- read the data, one module or several merged")
# ---------------------------------------------------------------------------
one <- datalib_load("ZWE", 2019, "MICS", collection = "HLT", module = "household",
                    root = root)
show_fn("datalib_load")
note("one module      : ", nrow(one), " rows x ", ncol(one), " cols")
note("columns         : ", paste(names(one), collapse = ", "))

merged <- datalib_load("ZWE", 2019, "MICS", collection = "HLT",
                       module = c("household", "children"), merge = TRUE, root = root)
note("")
note("two modules merged: ", nrow(merged), " rows x ", ncol(merged), " cols")
note("columns           : ", paste(names(merged), collapse = ", "))
note("merge keys come from the collection registry (config/collections.yml), not guessed")

unmerged <- datalib_load("ZWE", 2019, "MICS", collection = "HLT",
                         module = c("household", "children"), merge = FALSE, root = root)
note("")
note("merge = FALSE returns them separately: ",
     if (is.list(unmerged) && !is.data.frame(unmerged))
       paste0(length(unmerged), " tables") else paste0(nrow(unmerged), " rows"))

# ---------------------------------------------------------------------------
hdr(7, "datalib_browse() -- step through the grammar one level at a time")
# ---------------------------------------------------------------------------
# Returns the choices available at a point, so a caller can build a picker. This is the
# GRAMMAR-AWARE navigator: it knows a country holds surveys and a survey holds vintages.
print(datalib_browse(root = root));                 show_fn("datalib_browse")
note("")
note("inside one country:")
print(datalib_browse(country = "ZWE", root = root))

# ---------------------------------------------------------------------------
hdr(8, "datalib_create() -- propose the NEXT vintage (dry run)")
# ---------------------------------------------------------------------------
# create = FALSE is the default and writes nothing: it reports the path a new vintage
# WOULD take, so the name can be checked before any directory exists.
proposed <- datalib_create("ZWE", 2019, "MICS", collection = "HLT", root = root)
show_fn("datalib_create")
str(proposed, max.level = 1)
note("")
note("nothing was written -- pass create = TRUE to actually make the directories")

# ---------------------------------------------------------------------------
hdr(9, "datalib_explorer() -- ANY folder tree, grammar or not")
# ---------------------------------------------------------------------------
# Everything above reads a folder's ancestry out of its NAME. That is right inside the
# grammar and useless outside it, so explorer parses nothing: it lists what is there.
# Use it on trees nobody has renamed yet.
node <- datalib_explorer(root = root)
show_fn("datalib_explorer")
note("depth ", node$depth, "  dirs ", node$n_dirs, "  files ", node$n_files,
     "  looks_grammar ", node$looks_grammar)
note("dirs          : ", paste(node$dirs, collapse = ", "))

deep <- datalib_explorer("ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M_v01_A_HLT/Data/Stata",
                         root = root, sizes = TRUE)
note("")
note("a leaf, measured: ", deep$n_files, " files, ", deep$bytes, " bytes")
note("largest         : ", deep$largest, " (", deep$largest_bytes, " bytes)")
note("extensions      : ", paste(deep$exts, collapse = " "))
note("open_with       : what a caller can DO with each file --")
print(head(deep$open_with, 4))
note("  describe = read its metadata; view = it is text; open = hand to the OS.")
note("  Stata renders this column as clickable links; R returns it as data.")

note("")
note("looks_grammar separates renamed branches from untouched ones:")
note("  ZWE_2019_MICS_v02_M_v01_A_HLT -> ",
     datalib_explorer("ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M_v01_A_HLT",
                      root = root)$looks_grammar)
note("  Data/Stata                    -> ",
     datalib_explorer("ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M_v01_A_HLT/Data/Stata",
                      root = root)$looks_grammar)

# ---------------------------------------------------------------------------
hdr(10, "datalib_index() -- a whole subtree as a data.frame")
# ---------------------------------------------------------------------------
# explorer answers "what is in THIS folder". index answers "what is in this whole
# branch", which is the form you can table(), merge() or write.csv().
idx <- datalib_index(root = root)
show_fn("datalib_index")
note("rows ", nrow(idx), "  folders walked ", attr(idx, "nodes"),
     "  truncated ", attr(idx, "truncated"),
     "  seconds ", round(attr(idx, "seconds"), 2))
print(utils::head(idx[, c("relpath", "ext", "depth", "is_dir")], 5))
note("")
note("what is in here, by type:")
print(table(idx$ext))
note("")
note("only the Stata files, with sizes:")
dta <- datalib_index(root = root, pattern = "[.]dta$", sizes = TRUE)
note("  ", nrow(dta), " files, ", sum(dta$bytes), " bytes total")
note("  pattern filters FILES but never the traversal -- otherwise a match three")
note("  levels down could never be reached.")
note("")
note("max_depth for a cheap look at shape before committing to a full walk.")
note("Ask for folders too -- in a datalib tree the FILES sit five levels down, so")
note("a shallow file-only index is legitimately empty:")
note("  depth <= 2, files only  -> ", nrow(datalib_index(root = root, max_depth = 2)),
     " rows")
note("  depth <= 2, with dirs   -> ",
     nrow(datalib_index(root = root, max_depth = 2, dirs = TRUE)), " rows")
note("max_nodes caps the walk and WARNS that the result is a prefix:")
capped <- withCallingHandlers(
  datalib_index(root = root, max_nodes = 2),
  warning = function(w) { note("  warning: ", conditionMessage(w)); invokeRestart("muffleWarning") }
)
note("  truncated = ", attr(capped, "truncated"), " -- check this before trusting a total")

# ---------------------------------------------------------------------------
hdr(11, "datalib_update() -- am I running the current version?")
# ---------------------------------------------------------------------------
# Reports; deliberately does not install. install.packages() over a loaded namespace is
# unsafe on Windows, where the running session locks the package's own files.
u <- datalib_update(quiet = TRUE)
show_fn("datalib_update")
note("running   : ", u$running %||% "<unknown>")
note("available : ", u$available %||% "<site unreadable>")
note("status    : ", u$status)
note("")
note("statuses: current | newer_available | source_behind | unknown")
note("to upgrade, run the install line yourself, then restart the session")
note("(the R equivalent of Stata's -discard-):")
note('  utils::install.packages("Z:/_pkg/datalib/R/datalib_<v>.tar.gz",')
note("                          repos = NULL, type = \"source\")")
note("the utils:: prefix skips an RStudio hook that errors on local tarballs.")

# ---------------------------------------------------------------------------
hdr(12, "datalib_map_drive() -- mount the share (DRY RUN)")
# ---------------------------------------------------------------------------
# dry_run = TRUE is NOT the default. Called without it this really maps a drive letter,
# so the demo passes it explicitly.
if (.Platform$OS.type == "windows") {
  m <- datalib_map_drive(letter = "Y", unc = "\\\\example\\share", dry_run = TRUE)
  show_fn("datalib_map_drive")
  str(m, max.level = 1)
  note("")
  note("nothing was mounted. Drop dry_run = TRUE to act for real.")
} else {
  note("skipped: Windows only")
}

# ---------------------------------------------------------------------------
hdr(13, "Errors are typed, so callers can branch on them")
# ---------------------------------------------------------------------------
# Every failure carries a condition class. Matching on a class is stable; matching on an
# English message is not.
demo_err <- function(label, expr) {
  cls <- tryCatch({ force(expr); "<no error -- returned a value>" },
                  error = function(e) paste(setdiff(class(e), c("error", "condition")),
                                            collapse = " / "))
  note(sprintf("%-34s -> %s", label, cls))
}
demo_err('country not in the library', datalib_resolve("XXX", 2019, "MICS", root = root))
demo_err('vintage that does not exist',
         datalib_resolve("ZWE", 2019, "MICS", master_version = 99, root = root))
demo_err('explorer on a missing node', datalib_explorer("no/such/node", root = root))
note("")
note("catch them by class, e.g.:")
note('  tryCatch(datalib_resolve(...), datalib_error_not_found = function(e) NULL)')

note("")
note("But note what is deliberately NOT an error. ENUMERATORS return empty; only")
note("RESOLVERS raise. Asking BRA for a survey it does not have is a legitimate")
note("question with the answer 'none':")
demo_err('enumerator, no match', datalib_surveys("BRA", survey = "MICS", root = root))
note("  rows returned: ", nrow(datalib_surveys("BRA", survey = "MICS", root = root)))
note("That is the contract: 'no results' and 'you asked about something that does")
note("not exist' are different problems and must not look the same.")

# ---------------------------------------------------------------------------
hdr(14, "Coverage check -- was every exported function actually shown?")
# ---------------------------------------------------------------------------
exports <- sort(getNamespaceExports("datalib"))
missing <- setdiff(exports, .shown)
extra   <- setdiff(.shown, exports)
note("exported : ", length(exports))
note("exercised: ", length(intersect(exports, .shown)))
if (length(missing)) {
  note("NOT SHOWN: ", paste(missing, collapse = ", "))
} else {
  note("every exported function was called by this demo.")
}
if (length(extra)) note("recorded but not exported (bug in the demo): ",
                        paste(extra, collapse = ", "))

# ---------------------------------------------------------------------------
hdr(15, "The real share, if it is mounted")
# ---------------------------------------------------------------------------
# The arbitrary-tree functions exist for trees like <staging-tree>, where
# nothing follows the grammar. Skipped when the share is absent so the demo stays
# runnable on a laptop.
staging <- "<staging-tree>"
if (dir.exists(staging)) {
  top <- datalib_explorer(root = staging)
  note("staging root: ", top$n_dirs, " folders, ", top$n_files, " files")
  note("first few   : ", paste(utils::head(top$dirs, 5), collapse = ", "))
  note("")
  note("one survey branch, indexed:")
  sub <- datalib_index("Tajikistan/2012 DHS", root = staging)
  note("  ", nrow(sub), " files across ", attr(sub, "nodes"), " folders in ",
       round(attr(sub, "seconds"), 1), "s")
  print(utils::head(sort(table(sub$ext), decreasing = TRUE), 5))
  note("")
  note("a walk costs ~0.35 s per FOLDER on this share -- SMB latency, not this code.")
  note("The whole 193-country tree is a 6-8 hour walk, which is why max_nodes")
  note("defaults to 400 and says when it stopped early. For the whole archive use")
  note("the scheduled catalogue under <catalogue> instead.")
} else {
  note("skipped: ", staging, " is not mounted")
}

# ---------------------------------------------------------------------------
cat(sprintf("\n%s\n", strrep("=", 74)))
unlink(root, recursive = TRUE)
note("throwaway library removed: ", root)
note("done.")
