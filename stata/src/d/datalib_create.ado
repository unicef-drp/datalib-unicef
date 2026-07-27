*******************************************************
* datalib_create: contract v1 vintage-tree creator (check-mode by default)
* Author: Joao Pedro Azevedo
*! Version: 0.9.3       Date: <2026-07-25>
* Without -create-, reports the paths that WOULD be made (zero side effects).
* With -create-, builds <vintage>/{Data/{Original,Stata,R,Other},Doc,Programs}.
*******************************************************

capture program drop datalib_create
program define datalib_create, rclass

    version 15

    syntax , country(string) year(string) survey(string)  ///
        [                                                  ///
            KINd(string)                                   ///
            collection(string)                             ///
            master_version(string)                         ///
            adaptation_version(string)                     ///
            create                                         ///
            root(string)                                   ///
        ]

    quietly {
        if ("`root'"=="") local root "${datalib}"
        if ("`root'"=="") local root : environment DATALIB_ROOT
        if ("`root'"=="") {
            di as err "datalib root not set: pass root(), set global datalib, or set DATALIB_ROOT."
            exit 198
        }
        local country = upper(trim("`country'"))
        local survey  = upper(trim("`survey'"))
        local collection = upper(trim("`collection'"))
        if ("`kind'"=="") local kind = cond("`collection'"!="", "adaptation", "master")
        local kind = lower(trim("`kind'"))
        if ("`kind'"=="adaptation") & ("`collection'"=="") {
            di as err "kind(adaptation) requires collection()."
            exit 198
        }

        * vintages: default v01 for creation; normalize spellings
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
        if ("`master_version'"=="") local master_version "v01"
        if ("`kind'"=="adaptation") & ("`adaptation_version'"=="") local adaptation_version "v01"

        local svyfld "`country'_`year'_`survey'"
        if ("`kind'"=="adaptation") local vfolder "`svyfld'_`master_version'_M_`adaptation_version'_A_`collection'"
        else                        local vfolder "`svyfld'_`master_version'_M"
        local base "`root'/`country'/`svyfld'/`vfolder'"

        mata: st_local("existed", strofreal(direxists(st_local("base"))))

        local subs `""Data" "Data/Original" "Data/Stata" "Data/R" "Data/Other" "Doc" "Programs""'
        if ("`create'"!="") {
            capture mkdir "`root'/`country'"
            capture mkdir "`root'/`country'/`svyfld'"
            capture mkdir "`base'"
            foreach s in `subs' {
                capture mkdir "`base'/`s'"
            }
            return local created = cond("`existed'"=="1", "0", "1")
        }
        else {
            return local created "0"
        }

        return local existed        "`existed'"
        return local root           "`root'"
        return local survey_folder  "`svyfld'"
        return local vintage_folder "`vfolder'"
        return local path           "`base'"
        return local data_stata     "`base'/Data/Stata"
        return local data_original  "`base'/Data/Original"
        return local data_r         "`base'/Data/R"
        return local doc            "`base'/Doc"
        return local programs       "`base'/Programs"
    }

end
