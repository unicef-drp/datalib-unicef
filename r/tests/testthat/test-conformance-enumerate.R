# Shared enumerator conformance cases (contract v1, grammar.md rule 9).
#
# The contract pins the VALUE SET an enumerator returns, not the container, so
# this file adapts R's own return types (data frames) to the normalised list
# defined in grammar.md rule 9 and compares against tests/cases_enumerate.csv --
# the same rows Python and Stata assert.
#
# The normalisation is what makes a shared corpus possible: R returns data
# frames whose columns hold full folder names, Python returns VintageCatalog /
# AdaptationInfo objects, Stata returns space-separated strings in r(). A corpus
# matching the *container* could match at most one of the three, which is why
# the first attempt at this file was abandoned as impossible.

cases <- read.csv(file.path(datalib_test_repo_tests(), "cases_enumerate.csv"),
                  colClasses = "character")
fixture <- datalib_test_fixture_root()

# Adapt R's return type to the contract's normalised list. grammar.md rule 9
# fixes both the value set and its order per enumerator; vintages sort
# NUMERICALLY (sorting 9 and 10 as text would give "10 9").
dl_normalise <- function(fn, country, year, survey, root) {
  if (fn == "countries") {
    return(paste(sort(datalib_countries(root = root)$country), collapse = " "))
  }
  if (fn == "surveys") {
    s <- datalib_surveys(country, root = root)$folder
    return(paste(sort(s), collapse = " "))
  }
  if (fn == "vintages") {
    v <- datalib_vintages(country, year, survey, root = root)
    m <- sort(unique(v$master_version[v$kind == "master"]))
    return(paste(m, collapse = " "))
  }
  if (fn == "adaptations") {
    a <- datalib_adaptations(country, year, survey, root = root)
    return(paste(sort(a$collection), collapse = " "))
  }
  stop("unknown fn in cases_enumerate.csv: ", fn)
}

for (i in seq_len(nrow(cases))) {
  case <- cases[i, ]
  test_that(paste0("enumerate ", case$case_id, " (", case$fn, ")"), {
    got <- dl_normalise(case$fn, case$country, case$year, case$survey, fixture)
    expect_identical(got, case$expect_values)
  })
}

test_that("every enumerator is covered by the shared corpus", {
  # A corpus that silently stops covering an enumerator is worse than none.
  expect_setequal(unique(cases$fn),
                  c("countries", "surveys", "vintages", "adaptations"))
})
