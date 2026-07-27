# datalib_load -- load (and merge) survey modules

#' Load (and merge) survey modules
#'
#' Loads one or more survey modules from a resolved vintage's `Data/Stata`
#' folder, mirroring Stata `_dlw` under contract v1 (`config/grammar.md`):
#'
#' * the vintage is resolved via [datalib_resolve()] (uppercase-once
#'   normalization, exact matching, numeric latest defaults);
#' * the module list defaults to the collection registry's full module set;
#' * loaders NEVER mutate values (no recodes, no drops). The single
#'   documented normalization: a person module whose registry `linevar`
#'   differs from `line_number` has that variable renamed to `line_number`
#'   on load (schema normalization for merging);
#' * `ctrycode` (character) and `year` (integer) columns are added when
#'   absent;
#' * merge: person modules chain `1:1` (outer) on the registry's
#'   `keys_person`, then hh-level modules attach `m:1` (outer) on
#'   `keys_hh` (`1:1` when only hh modules). Keys are validated per module
#'   (unique, no missings, `isid`-equivalent); failure is a typed error
#'   naming the module. Unmatched rows are kept (outer join); the merge
#'   indicator is not retained.
#'
#' @param country Country code (e.g. `"MWI"`). Trimmed and uppercased once;
#'   matched exactly against country folder names (never substring).
#' @param year Survey year (integer or string). When `NULL`, the
#'   numerically latest year among the country's matching survey folders.
#' @param survey Survey acronym (e.g. `"MICS6"`). Trimmed and uppercased
#'   once; survey folders match on the exact suffix `_<SURVEY>` (never
#'   substring). When `NULL`, taken from the numerically latest survey-year
#'   folder.
#' @param module Character vector of module suffixes (e.g. `c("hl", "hh")`)
#'   naming files `<vintage-stem>_<module>.dta`. When `NULL`, all modules
#'   of the collection registry. Ignored when `filename` is given.
#' @param kind `"master"` or `"adaptation"`. Defaults to `"adaptation"`.
#' @param collection Adaptation collection code (e.g. `"HLT"`, the default
#'   when `kind = "adaptation"`). Trimmed and uppercased once; applies only
#'   to adaptations.
#' @param master_version Master vintage, accepted as `1`, `"01"`, `"v01"`,
#'   or `"V01"`. When `NULL`, the numerically latest master on disk
#'   (numeric maximum, never alphabetical or listing order).
#' @param adaptation_version Adaptation vintage, same spellings. When
#'   `NULL`, the numerically latest adaptation of the requested collection
#'   under the chosen master.
#' @param filename Exact file name under the vintage's `Data/Stata` folder.
#'   When given, that single file is loaded and returned as-is (no registry
#'   lookup, no merge, no added columns).
#' @param merge Logical; when `TRUE` (default) the loaded modules are merged
#'   into one data.frame. When `FALSE`, a named list of per-module
#'   data.frames is returned instead.
#' @param root Library root path. When `NULL`, resolved by [datalib_root()]
#'   in contract precedence order: explicit argument, then the
#'   `DATALIB_ROOT` environment variable, then `option(datalib.root)`, then
#'   the `datalib:` key in the user block of `~/.config/user_config.yml`.
#' @param verbose Logical; when `TRUE`, a `message()` is emitted for each
#'   file loaded.
#'
#' @return With `merge = TRUE` (default), one merged data.frame
#'   (haven-labelled columns preserved; key and `ctrycode`/`year`/`source`
#'   columns first). With `merge = FALSE`, a named list of module
#'   data.frames. With `filename`, a single data.frame read as-is. In all
#'   cases the attributes `datalib_files` (character; file names loaded)
#'   and `datalib_resolve` (list; the full [datalib_resolve()] result)
#'   record provenance.
#'
#' Errors with condition class `datalib_error_input` (Stata 198) on invalid
#' input, missing files, or failed key validation.
#'
#' @examples
#' \dontrun{
#' # latest HLT adaptation, all registry modules, merged
#' df <- datalib_load("MWI", 2019, "MICS6")
#' # two modules, unmerged
#' lst <- datalib_load("MWI", 2019, "MICS6", module = c("hl", "hh"),
#'                     merge = FALSE)
#' # one raw file from a master vintage
#' raw <- datalib_load("MWI", 2019, "MICS6", kind = "master",
#'                     filename = "MWI_2019_MICS6_v01_M_hh.dta")
#' attr(df, "datalib_files")
#' }
#' @export
datalib_load <- function(country, year = NULL, survey = NULL, module = NULL,
                         kind = NULL, collection = NULL,
                         master_version = NULL, adaptation_version = NULL,
                         filename = NULL, merge = TRUE, root = NULL,
                         verbose = FALSE) {
  res <- datalib_resolve(
    country = country, year = year, survey = survey, kind = kind,
    collection = collection, master_version = master_version,
    adaptation_version = adaptation_version, root = root
  )

  # ---- filename branch: one named file, returned as-is (no registry) ----
  if (nz_arg(filename)) {
    fpath <- fs::path(res$data_stata, filename)
    if (!fs::file_exists(fpath)) {
      err_not_found(sprintf("File %s not found under %s.", filename, res$data_stata))
    }
    if (isTRUE(verbose)) message("Loading ", fpath)
    out <- as.data.frame(haven::read_dta(fpath))
    attr(out, "datalib_files") <- as.character(filename)
    attr(out, "datalib_resolve") <- res
    return(out)
  }

  reg <- if (res$kind == "adaptation") registry_collection(res$collection) else NULL

  # ---- module list: default to the registry's full module set ----
  if (!is.null(module)) {
    module <- trimws(as.character(module))
    module <- module[nzchar(module)]
    if (!length(module)) module <- NULL
  }
  if (is.null(module)) {
    if (is.null(reg)) {
      if (res$kind == "master") {
        err_input("For master files, specify module or filename.")
      }
      err_input(sprintf(
        "Collection %s has no module registry: specify module or filename.",
        res$collection
      ))
    }
    module <- names(reg$modules)
  }

  # ---- load each module ----
  frames <- list()
  files <- character(0)
  levels <- character(0)
  keys_list <- list()
  for (m in module) {
    fname <- paste0(res$file_stem, "_", m, ".dta")
    fpath <- fs::path(res$data_stata, fname)
    if (!fs::file_exists(fpath)) {
      err_not_found(sprintf("File %s not found under %s.", fname, res$data_stata))
    }
    if (isTRUE(verbose)) message("Loading ", fpath)
    df <- as.data.frame(haven::read_dta(fpath))

    lvl <- NA_character_
    keys <- character(0)
    if (!is.null(reg)) {
      info <- reg$modules[[m]]
      if (!is.null(info)) {
        lvl <- info$level
        if (identical(lvl, "person")) {
          keys <- as.character(reg$keys_person)
          lv <- info$linevar
          if (!is.null(lv) && !identical(lv, "line_number") &&
              lv %in% names(df) && !("line_number" %in% names(df))) {
            names(df)[names(df) == lv] <- "line_number"
          }
        } else {
          keys <- as.character(reg$keys_hh)
        }
      }
    }
    if (!"ctrycode" %in% names(df)) df$ctrycode <- res$country
    if (!"year" %in% names(df)) df$year <- as.integer(res$year)
    front <- intersect(c("ctrycode", "year", "source", keys), names(df))
    df <- df[, c(front, setdiff(names(df), front)), drop = FALSE]

    frames[[m]] <- df
    files <- c(files, fname)
    levels[m] <- lvl
    keys_list[[m]] <- keys
  }

  # ---- merge = FALSE: named list of module data.frames ----
  if (!isTRUE(merge)) {
    attr(frames, "datalib_files") <- files
    attr(frames, "datalib_resolve") <- res
    return(frames)
  }

  if (length(frames) == 1L) {
    out <- frames[[1]]
  } else {
    # validate keys per module (unique, no missings) before any merge
    for (m in names(frames)) {
      keys <- keys_list[[m]]
      if (!length(keys)) {
        err_input(sprintf(
          "Cannot merge: merge keys unknown for module %s. Use merge = FALSE.", m
        ))
      }
      df <- frames[[m]]
      missing_keys <- setdiff(keys, names(df))
      if (length(missing_keys)) {
        err_input(sprintf(
          "Cannot merge: key variable(s) %s missing in module %s. Drop that module from module or use merge = FALSE.",
          paste(missing_keys, collapse = ", "), m
        ))
      }
      kdf <- df[keys]
      has_na <- any(vapply(kdf, function(col) any(is.na(col)), logical(1)))
      if (has_na || anyDuplicated(kdf) > 0L) {
        err_input(sprintf(
          "Cannot merge: keys (%s) do not uniquely identify rows of module %s (missing or duplicated identifiers in the data). Drop that module from module or use merge = FALSE.",
          paste(keys, collapse = " "), m
        ))
      }
    }
    keys_person <- as.character(reg$keys_person)
    keys_hh <- as.character(reg$keys_hh)
    persons <- names(frames)[which(levels[names(frames)] == "person")]
    hhs <- names(frames)[which(levels[names(frames)] == "hh")]
    if (length(persons)) {
      out <- frames[[persons[1]]]
      for (m in persons[-1]) out <- dl_merge_outer(out, frames[[m]], keys_person)
      for (m in hhs) out <- dl_merge_outer(out, frames[[m]], keys_hh)
    } else {
      out <- frames[[hhs[1]]]
      for (m in hhs[-1]) out <- dl_merge_outer(out, frames[[m]], keys_hh)
    }
    front <- intersect(c("ctrycode", "year", "source", keys_person, keys_hh),
                       names(out))
    out <- out[, c(front, setdiff(names(out), front)), drop = FALSE]
    rownames(out) <- NULL
  }

  attr(out, "datalib_files") <- files
  attr(out, "datalib_resolve") <- res
  out
}

# Outer merge on explicit keys, Stata-style handling of columns present in
# both sides: matched rows keep the accumulated (master) value even when it is
# NA — exactly like Stata's merge and pandas' right_only fill; only rows that
# exist solely in the incoming (using) side take the incoming value. No value
# in either input is ever altered.
dl_merge_outer <- function(x, y, keys) {
  common <- setdiff(intersect(names(x), names(y)), keys)
  x[[".__inx"]] <- TRUE
  m <- merge(x, y, by = keys, all = TRUE, sort = TRUE,
             suffixes = c(".__x", ".__y"))
  right_only <- is.na(m[[".__inx"]])
  for (col in common) {
    cx <- m[[paste0(col, ".__x")]]
    cy <- m[[paste0(col, ".__y")]]
    cx[right_only] <- cy[right_only]
    m[[col]] <- cx
    m[[paste0(col, ".__x")]] <- NULL
    m[[paste0(col, ".__y")]] <- NULL
  }
  m[[".__inx"]] <- NULL
  m
}
