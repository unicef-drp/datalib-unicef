*******************************************************
* datalib_resolve: contract v1 path resolution (pure — touches no data)
* Author: Joao Pedro Azevedo
*! Version: 0.9.3       Date: <2026-07-25>
* Resolves (country, year, survey, kind, collection, vintages) -> paths,
* following config/grammar.md: uppercase-once, exact matching, numeric latest.
*******************************************************

capture program drop datalib_resolve
program define datalib_resolve, rclass

    version 15

    syntax , country(string)              ///
        [                                 ///
            year(string)                  ///
            survey(string)                ///
            KINd(string)                  ///
            collection(string)            ///
            master_version(string)        ///
            adaptation_version(string)    ///
            root(string)                  ///
        ]

    quietly {

        * ---- root resolution: root() arg -> ${datalib} -> env DATALIB_ROOT ----
        if ("`root'"=="") local root "${datalib}"
        if ("`root'"=="") local root : environment DATALIB_ROOT
        if ("`root'"=="") {
            di as err "datalib root not set: pass root(), set global datalib, or set DATALIB_ROOT."
            exit 198
        }

        * ---- normalize inputs once at the boundary ----
        local country = upper(trim("`country'"))
        local survey  = upper(trim("`survey'"))
        local collection = upper(trim("`collection'"))
        if ("`kind'"=="") local kind "adaptation"
        local kind = lower(trim("`kind'"))
        if !inlist("`kind'", "master", "adaptation") {
            di as err "kind() must be master or adaptation."
            exit 198
        }
        if ("`kind'"=="adaptation") & ("`collection'"=="") local collection "HLT"
        if ("`kind'"=="master") & ("`collection'"!="") {
            di as err "collection() applies only to kind(adaptation)."
            exit 198
        }

        * vintages: accept 1 / 01 / v01 / V01 -> v01
        foreach v in master_version adaptation_version {
            if ("``v''" != "") {
                local raw = lower(trim("``v''"))
                if (substr("`raw'",1,1)=="v") local raw = substr("`raw'",2,.)
                capture confirm integer number `raw'
                if _rc {
                    di as err "`v'() must be a vintage number such as 01 or v01."
                    exit 198
                }
                local nn : display %02.0f `raw'
                local `v' "v`nn'"
            }
        }

        * ---- country: exact folder match ----
        local hit : dir "`root'/" dirs "`country'"
        if (`"`hit'"'=="") {
            di as err "Country `country' not found in datalib (`root')."
            exit 198
        }

        * ---- survey folders (exact suffix), latest-year default ----
        if ("`survey'"!="") local flist : dir "`root'/`country'" dirs "*_`survey'"
        else                local flist : dir "`root'/`country'" dirs "*"
        if (`"`flist'"'=="") {
            di as err "`survey' for `country' not available."
            exit 198
        }
        if ("`survey'"=="") {
            * pick numerically latest year, then that folder's survey
            local ymax = -1
            foreach f in `flist' {
                local yr = real(word(subinstr("`f'","_"," ",.),2))
                if (`yr'<.) & (`yr'>`ymax') {
                    local ymax = `yr'
                    local survey = upper(word(subinstr("`f'","_"," ",.),3))
                }
            }
            if ("`year'"=="") local year "`ymax'"
        }
        if ("`year'"=="") {
            local ymax = -1
            foreach f in `flist' {
                local yr = real(word(subinstr("`f'","_"," ",.),2))
                if (`yr'<.) & (`yr'>`ymax') local ymax = `yr'
            }
            if (`ymax'<0) {
                di as err "Could not determine the survey year for `country'."
                exit 198
            }
            local year "`ymax'"
        }

        local svyfld "`country'_`year'_`survey'"
        local hit : dir "`root'/`country'" dirs "`svyfld'"
        if (`"`hit'"'=="") {
            di as err "Survey folder `svyfld' not found."
            exit 198
        }

        * ---- vintage defaults: numeric latest on disk ----
        local vdirs : dir "`root'/`country'/`svyfld'" dirs "`svyfld'_*"
        if ("`master_version'"=="") {
            local best = -1
            foreach d in `vdirs' {
                local D = upper("`d'")
                local toks = subinstr("`D'","_"," ",.)
                if (wordcount("`toks'")==5) & (word("`toks'",5)=="M") {
                    local n = real(substr(word("`toks'",4),2,.))
                    if (`n'<.) & (`n'>`best') local best = `n'
                }
            }
            if (`best'<0) {
                di as err "No master vintage found under `svyfld'."
                exit 198
            }
            local nn : display %02.0f `best'
            local master_version "v`nn'"
        }
        if ("`kind'"=="adaptation") & ("`adaptation_version'"=="") {
            local best = -1
            local VM = upper("`master_version'")
            foreach d in `vdirs' {
                local D = upper("`d'")
                local toks = subinstr("`D'","_"," ",.)
                if (wordcount("`toks'")==8) & (word("`toks'",4)=="`VM'") & (word("`toks'",8)=="`collection'") {
                    local n = real(substr(word("`toks'",6),2,.))
                    if (`n'<.) & (`n'>`best') local best = `n'
                }
            }
            if (`best'<0) {
                di as err "No `collection' adaptation found under `svyfld' for master `master_version'."
                exit 198
            }
            local nn : display %02.0f `best'
            local adaptation_version "v`nn'"
        }

        * ---- vintage folder + existence check ----
        if ("`kind'"=="adaptation") local vfolder "`svyfld'_`master_version'_M_`adaptation_version'_A_`collection'"
        else                        local vfolder "`svyfld'_`master_version'_M"
        local hit : dir "`root'/`country'/`svyfld'" dirs "`vfolder'"
        if (`"`hit'"'=="") {
            di as err "Vintage folder `vfolder' not found under `svyfld'."
            exit 198
        }

        * ---- publish ----
        local base "`root'/`country'/`svyfld'/`vfolder'"
        return local root           "`root'"
        return local country        "`country'"
        return local year           "`year'"
        return local survey         "`survey'"
        return local kind           "`kind'"
        return local collection     "`collection'"
        return local master_version     = real(substr("`master_version'",2,.))
        return local adaptation_version = cond("`adaptation_version'"=="", "", ///
                                          string(real(substr("`adaptation_version'",2,.))))
        return local survey_folder  "`svyfld'"
        return local vintage_folder "`vfolder'"
        return local file_stem      "`vfolder'"
        return local data_stata     "`base'/Data/Stata"
        return local data_original  "`base'/Data/Original"
        return local data_r         "`base'/Data/R"
        return local data_other     "`base'/Data/Other"
        return local doc            "`base'/Doc"
        return local programs       "`base'/Programs"
    }

end
