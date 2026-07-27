*******************************************************
* datalib_browse: contract v1 stateless navigation (pure r(), no data touched)
* Author: Joao Pedro Azevedo
*! Version: 0.9.3       Date: <2026-07-25>
* Returns the child choices of one node of the library tree, mirroring the
* R/Python datalib_browse: no arguments -> countries; country() -> survey
* folders; a 3-token path() -> vintage folders; a 5/8-token path() -> the
* section folders present. Replaces _foldernav's click-state with explicit,
* re-passable tokens in r(choices).
*******************************************************

capture program drop datalib_browse
program define datalib_browse, rclass

    version 15

    syntax [, country(string) path(string) root(string) noDISplay ]

    quietly {
        if ("`root'"=="") local root "${datalib}"
        if ("`root'"=="") local root : environment DATALIB_ROOT
        if ("`root'"=="") {
            di as err "datalib root not set: pass root(), set global datalib, or set DATALIB_ROOT."
            exit 198
        }
        local country = upper(trim("`country'"))
        local path    = upper(trim("`path'"))

        if ("`path'"=="") & ("`country'"!="") local path "`country'"

        if ("`path'"=="") {
            * level 0: countries
            local list : dir "`root'/" dirs "*"
            local kind "country"
        }
        else {
            local toks = subinstr("`path'","_"," ",.)
            local wc = wordcount("`toks'")
            if (`wc'==1) {
                * a country: its survey folders
                local hit : dir "`root'/" dirs "`path'"
                if (`"`hit'"'=="") {
                    di as err "Country `path' not found in datalib (`root')."
                    exit 198
                }
                local list : dir "`root'/`path'" dirs "*_*_*"
                local kind "survey"
            }
            else if (`wc'==3) {
                * a survey folder: its vintages
                local ctry = word("`toks'",1)
                local list : dir "`root'/`ctry'/`path'" dirs "`path'_*"
                local kind "vintage"
            }
            else if (`wc'==5 | `wc'==8) {
                * a vintage folder: its section directories
                local ctry = word("`toks'",1)
                local svyfld = "`=word("`toks'",1)'_`=word("`toks'",2)'_`=word("`toks'",3)'"
                local list : dir "`root'/`ctry'/`svyfld'/`path'" dirs "*"
                local kind "section"
            }
            else {
                di as err "path() must be a country, a CCC_YYYY_SSSS survey folder, or a vintage folder."
                exit 198
            }
        }

        local out ""
        foreach f in `list' {
            local out "`out' `=upper("`f'")'"
        }
        local out : list sort out
        if ("`display'"!="nodisplay") {
            noi di as txt "{hline 40}"
            foreach c of local out {
                noi di as txt "  `c'"
            }
            noi di as txt "{hline 40}"
        }
        return local choices = trim("`out'")
        return local kind "`kind'"
        return local n = wordcount("`out'")
        return local root "`root'"
    }

end
