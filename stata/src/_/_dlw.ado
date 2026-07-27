*******************************************************
* _dlw: Data Loading and Processing Utility
* Author: Joao Pedro Azevedo
*! Version: 1.10       Date: <2026-07-10>
* Description:
* This program is designed to facilitate the loading, processing, and
* merging of survey data modules across different countries and years.
* The utility provides options to select specific surveys, modules,
* and collections, with default settings for common use cases.
*******************************************************

capture program drop _dlw
program define _dlw, rclass

    version 15

    syntax  [varlist]                      ///
            [in] [if]                      ///
            [,                             ///
                country(string)            ///
                year(string)               ///
                survey(string)             ///
                MODule(string)             ///
                filename(string)           ///
                MASter			           ///
                adaptation                 ///
                LATest                     ///
                collection(string)         ///
                harmonization(string)      ///
                va(string)                 ///
                vm(string)                 ///
                DEBUG                      ///
                data                       ///
                doc                        ///
                programs                   ///
                NOMerge                    ///
                clear                      ///
            ]

    quietly {

        /**
        * Flow Control
        */

        * Master and adaptation are mutually exclusive
        if ("`master'" != "") & ("`adaptation'" != "" | "`collection'" != "") {
            di as err "Options master and adaptation/collection() are mutually exclusive."
            exit 198
        }

        * Check if country is specified
        if ("`country'" == "") {
            di as err "Country needs to be specified."
            exit 198
        }

        * Normalize inputs once at the boundary (contract: uppercase, exact matching)
        local country = upper(trim("`country'"))
        local survey  = upper(trim("`survey'"))
        local collection = upper(trim("`collection'"))

        * Normalize vintage inputs: accept 1, 01, v01, V01 -> v01
        foreach v in vm va {
            if ("``v''" != "") {
                local raw = lower(trim("``v''"))
                if (substr("`raw'",1,1) == "v") {
                    local raw = substr("`raw'",2,.)
                }
                capture confirm integer number `raw'
                if _rc {
                    di as err "Option `v'() must be a vintage number such as 01 or v01."
                    exit 198
                }
                local nn : display %02.0f `raw'
                local `v' "v`nn'"
            }
        }

        * Set year to latest if not specified
        if ("`year'" == "") {
            di in y "Year not specified. Latest available survey will be used."
            local latest latest
        }

        * Ensure the datalib path is set
        if ("${datalib}" == "") {
            di as err "Path to datalib needs to be specified. Global datalib needs to be defined."
            exit 198
        }

        * collection() implies adaptation; adaptation defaults to the HLT collection
        if ("`collection'" != "") & ("`adaptation'" == "") {
            local adaptation "adaptation"
        }
        if ("`collection'" == "") & ("`adaptation'" != "") {
            local collection "HLT"
        }
        local clct "`collection'"

        * Supported modules, module levels, and merge keys by collection
        * (single registry: hh-level modules merge on keys_hh; person-level on
        *  keys_person; linevar_<module> names a module's person-line variable
        *  when it is not already called line_number)
        if ("`clct'"=="IPUMS") {
            local allmodule   "bh ch fs hh hl mn wm"
            local hh_modules  "hh"
            local keys_hh     "svy_id household_id"
            local keys_person "svy_id household_id line_number"
        }
        if ("`clct'"=="HLT") {
            local allmodule   "household hhmembers adult children"
            local hh_modules  "household"
            local keys_hh     "svy_id cluster_id household_id"
            local keys_person "svy_id cluster_id household_id line_number"
            local linevar_hhmembers "hh_line_number"
        }

        * Select all modules if none specified
        if ("`module'"=="") {
            local module "`allmodule'"
        }

        * Master files: module list is not known from a collection registry
        if ("`adaptation'"=="") & ("`module'"=="") & ("`filename'"=="") {
            di as err "For master files, specify module() or filename()."
            exit 198
        }

        * Count the number of modules selected
        local cntmod = wordcount("`module'")

        * Enable noisy output for debugging if requested
        if ("`debug'"!="") {
            local noi noisily
        }

        ******************************************
        * Folder Navigation and Data Selection
        ******************************************

        * Verify the selected country exists (exact folder-name match)
        local list : dir "${datalib}/" dirs "`country'"
        `noi' di "ctry: `"`list'"'"
        if (`"`list'"' == "") {
            di as err "Country `country' not found in datalib (${datalib})."
            exit 198
        }

        * List available survey folders for the selected country
        * (exact survey suffix: CCC_YYYY_SSSS ends with _<survey>)
        if ("`survey'" != "") {
            local list : dir "${datalib}/`country'" dirs "*_`survey'"
        }
        else {
            local list : dir "${datalib}/`country'" dirs "*"
        }
        `noi' di "Survey folders: `"`list'"'"

        * Handle cases where the survey is not specified or not available
        if (`"`list'"'==`""') {
            di as err "`survey' for `country' not available. Please select an eligible survey."
            exit 198
        }

        * Default to the latest available survey if not specified
        if ("`survey'"=="") {
            local pick = word(`"`list'"',-1)
            local survey = upper(word(subinstr("`pick'","_"," ",.),3))
        }

        * Extract the latest year if not specified (numeric max, not listing order)
        if ("`year'"=="") {
            local ymax = -1
            foreach folders in `list' {
                local yr = real(word(subinstr("`folders'","_"," ",.),2))
                if (`yr' < .) & (`yr' > `ymax') {
                    local ymax = `yr'
                }
            }
            if (`ymax' < 0) {
                di as err "Could not determine the survey year for `country'."
                exit 198
            }
            local year "`ymax'"
        }

        local ctry "`country'"
        local svy "`survey'"
        local svyfld "`ctry'_`year'_`svy'"

        * Resolve vintage defaults from the folders that actually exist
        * (numeric latest, never alphabetical listing order)
        local vdirs : dir "${datalib}/`ctry'/`svyfld'" dirs "`svyfld'_*"
        if ("`vm'"=="") {
            local best = -1
            foreach d in `vdirs' {
                local D = upper("`d'")
                local toks = subinstr("`D'","_"," ",.)
                if (wordcount("`toks'")==5) & (word("`toks'",5)=="M") {
                    local n = real(substr(word("`toks'",4),2,.))
                    if (`n' < .) & (`n' > `best') local best = `n'
                }
            }
            if (`best' < 0) {
                di as err "No master vintage found under `svyfld'."
                exit 198
            }
            local nn : display %02.0f `best'
            local vm "v`nn'"
        }
        if ("`adaptation'"!="") & ("`va'"=="") {
            local best = -1
            local VM = upper("`vm'")
            foreach d in `vdirs' {
                local D = upper("`d'")
                local toks = subinstr("`D'","_"," ",.)
                if (wordcount("`toks'")==8) & (word("`toks'",4)=="`VM'") & (word("`toks'",8)=="`clct'") {
                    local n = real(substr(word("`toks'",6),2,.))
                    if (`n' < .) & (`n' > `best') local best = `n'
                }
            }
            if (`best' < 0) {
                di as err "No `clct' adaptation found under `svyfld' for master `vm'."
                exit 198
            }
            local nn : display %02.0f `best'
            local va "v`nn'"
        }

        * Construct the vintage folder name
        if ("`adaptation'"!="") {
            local file "`ctry'_`year'_`svy'_`vm'_M_`va'_A_`clct'"
        }
        if ("`adaptation'"=="") {
            local file "`ctry'_`year'_`svy'_`vm'_M"
        }

        * Confirm the vintage folder exists before loading
        local hit : dir "${datalib}/`ctry'/`svyfld'" dirs "`file'"
        if (`"`hit'"' == "") {
            di as err "Vintage folder `file' not found under `svyfld'."
            exit 198
        }

        * Check if the file exists and load the data
        * Prepare the data for merging if more than one module is selected
        if ("`file'"!="") & ("`filename'"=="") {

            `noi' di "`year'"

            local i = 0
            foreach type in `module' {

                local i = `i'+1

                local tousedta`i' "${datalib}/`ctry'/`svyfld'/`file'/Data/Stata/`file'_`type'.dta"
                use "`tousedta`i''", `clear'
                `noi' ds, varwidth(30) alpha
                `noi' di ""

                * Determine module level and merge keys from the registry
                local mkeys`i' ""
                local mlvl`i'  ""
                local mok`i'  0
                local mname`i' "`type'"
                if ("`keys_hh'"!="") {
                    local mlvl`i' "person"
                    if (strpos(" `hh_modules' ", " `type' ") > 0) {
                        local mlvl`i' "hh"
                        local mkeys`i' "`keys_hh'"
                    }
                    else {
                        local mkeys`i' "`keys_person'"
                        * Normalize the module's person-line variable to line_number
                        local lv "`linevar_`type''"
                        if ("`lv'"!="") & ("`lv'"!="line_number") {
                            capture rename `lv' line_number
                        }
                    }

                    * Sort and prepare data for merging; record whether the
                    * registry keys actually identify rows (checked at merge time)
                    capture sort `mkeys`i''
                    capture isid `mkeys`i''
                    local mok`i' = (_rc==0)
                    `noi' di "Keys: `mkeys`i'' (module `type', unique=`mok`i'')"
                }

                * Provenance columns (contract: added when absent, never
                * overwritten) — on every load, registry-known or master
                cap gen ctrycode = "`ctry'"
                cap gen year = `year'
                if ("`mkeys`i''"!="") {
                    capture order ctrycode year source `mkeys`i''
                    if _rc {
                        capture order ctrycode year `mkeys`i''
                    }
                }

                tempfile tmp`i'
                save `tmp`i'', replace

                return local filename`i' = "`file'_`type'.dta"
            }
        }
        if ("`file'"!="") & ("`filename'"!="") {

            `noi' di "`year'"

            local i = 0
            foreach flname in `"`filename'"'{

                local i = `i'+1

                * Load the data for the specified files
                if ("`data'"=="data") {
                    local tousedta`i' "${datalib}/`ctry'/`svyfld'/`file'/Data/Stata/`flname'"
                    use "`tousedta`i''", `clear'
                    `noi' ds, varwidth(30) alpha
                    `noi' di ""
                    return local data`i' "`tousedta`i''"

                    * Named files have no registry module: keys unknown, no mutation
                    local mkeys`i' ""
                    local mlvl`i'  ""

                    tempfile tmp`i'
                    save `tmp`i'', replace
                }
                * View the documents from specific surveys
                if ("`doc'"=="doc") {
                    local tousedoc`i'  "${datalib}/`ctry'/`svyfld'/`file'/Doc/`flname'"
                    view browse "`tousedoc`i''"
                    return local doc`i' "`tousedoc`i''"
                }
                * View the files in the program folder
                if ("`programs'"=="programs") {
                    local touseprog`i' "${datalib}/`ctry'/`svyfld'/`file'/Programs/`flname'"
                    view browse "`touseprog`i''"
                    return local programs`i' "`touseprog`i''"
                }

                return local filename`i' = "`flname'"
            }
        }
        if ("`file'"=="") & ("`filename'"=="") {
            noi di as err "No data for `country' available. Please check your selection and resubmit."
            exit 198
        }

        * Merge selected modules if more than one module is chosen
        * (explicit registry keys, validated with -isid- per module: person-level
        *  modules chain 1:1 on the person keys, then hh-level modules attach m:1
        *  on the hh keys. Modules whose keys do not uniquely identify rows stop
        *  the merge with an actionable error instead of merging by row order.)
        if (`cntmod'>1 & "`nomerge'"=="" & "`filename'"=="") {

            * Partition loaded modules into person-level and hh-level
            local plist ""
            local hlist ""
            forvalues m = 1/`i' {
                if ("`mkeys`m''"=="") {
                    di as err "Cannot merge: module merge keys unknown for this selection. Use nomerge."
                    exit 198
                }
                if (`mok`m''==0) {
                    di as err "Cannot merge: keys (`mkeys`m'') do not uniquely identify rows of module `mname`m'' (missing or duplicated identifiers in the data). Drop that module from module() or use nomerge."
                    exit 198
                }
                if ("`mlvl`m''"=="person") local plist "`plist' `m'"
                else                       local hlist "`hlist' `m'"
            }

            local first : word 1 of `plist' `hlist'
            use `tmp`first'', clear

            * Chain the remaining person-level modules 1:1 on the person keys
            local started 0
            foreach m of local plist {
                if (`started'==0) {
                    local started 1
                    continue
                }
                merge 1:1 `keys_person' using `tmp`m''
                `noi' tab _merge
                drop _merge
            }

            * Attach hh-level modules
            foreach m of local hlist {
                if ("`m'"=="`first'") continue
                if ("`plist'"=="") {
                    merge 1:1 `keys_hh' using `tmp`m''
                }
                else {
                    merge m:1 `keys_hh' using `tmp`m''
                }
                `noi' tab _merge
                drop _merge
            }
        }

        * Return the harmonization file name
        return local harmonization = "`file'"
        return add
    }

end

/*******************************************************
Version History

v1.10 (2026-07-10)
Fixes and behavior changes:
Merging now uses explicit keys from the collection registry (HLT: person
modules chain 1:1 on svy_id cluster_id household_id line_number, then hh-level
modules attach m:1 on svy_id cluster_id household_id), validated per module
with -isid-; modules whose identifiers are missing/duplicated in the data stop
the merge with an actionable error. The previous release cleared the key locals
before merging, producing an unkeyed old-syntax merge. Person-line variables
are normalized to line_number from the registry (HLT hhmembers: hh_line_number).
Removed the undocumented `recode windex5 8=.` data mutation from the loader;
apply collection-specific recodes in harmonization code instead.
vm() and va() now default to the numerically latest vintage found on disk, and
accept 1 / 01 / v01 / V01 spellings.
Country matching is exact (case-normalized at the boundary) instead of
substring matching; survey folders match the exact survey suffix.
Master files can now be loaded (specify module() or filename()); the option
previously exited with an error.
The vintage folder is verified to exist before any load is attempted.

v1.01 (2024-08-18)
Enhancements:
Improved handling of the year and survey options to ensure the correct survey year is selected when not specified, defaulting to the latest available survey.
Added more robust logic for loading and merging data modules, ensuring appropriate sorting and variable management across multiple modules.
Enhanced the debugging functionality to provide clearer, noisier output when the DEBUG option is specified.
Implemented better error handling for missing or incorrect country, survey, and year inputs.
Improved folder navigation and file verification to handle more complex folder structures and subfolder depth.

v1.00 (2024-03-21)
Initial Release:
Developed the core utility for loading and processing survey data across different countries and years.
Introduced options to select specific surveys, modules, and collections.
Implemented basic error handling and default settings for common use cases.
Supported integration with master and adaptation file types, though master file handling was not fully implemented.
Included initial support for various modules and sorting mechanisms based on the selected collection.
*******************************************************/
