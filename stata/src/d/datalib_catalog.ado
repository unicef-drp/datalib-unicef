*******************************************************
* datalib_catalog: contract v1 catalog — one-pass tree scan -> dataset
* Author: Joao Pedro Azevedo
*! Version: 0.9.3       Date: <2026-07-25>
* Scans the library and REPLACES the data in memory with one row per
* survey-vintage: country year survey kind master_version adaptation_version
* collection survey_folder vintage_folder. Requires -clear-.
*******************************************************

capture program drop datalib_catalog
program define datalib_catalog, rclass

    version 15

    syntax , clear [ root(string) country(string) ]

    quietly {

        if ("`root'"=="") local root "${datalib}"
        if ("`root'"=="") local root : environment DATALIB_ROOT
        if ("`root'"=="") {
            di as err "datalib root not set: pass root(), set global datalib, or set DATALIB_ROOT."
            exit 198
        }
        local country = upper(trim("`country'"))

        tempname ph
        tempfile cat
        postfile `ph' str12 country int year str24 survey str12 kind ///
            byte master_version byte adaptation_version str24 collection ///
            str80 survey_folder str120 vintage_folder using `cat', replace

        if ("`country'"!="") local clist : dir "`root'/" dirs "`country'"
        else                 local clist : dir "`root'/" dirs "*"
        foreach c in `clist' {
            local C = upper("`c'")
            local slist : dir "`root'/`c'" dirs "*_*_*"
            foreach s in `slist' {
                local S = upper("`s'")
                local yr = real(word(subinstr("`S'","_"," ",.),2))
                local sv = word(subinstr("`S'","_"," ",.),3)
                local vlist : dir "`root'/`c'/`s'" dirs "`s'_*"
                foreach v in `vlist' {
                    local V = upper("`v'")
                    local toks = subinstr("`V'","_"," ",.)
                    local wc = wordcount("`toks'")
                    if (`wc'==5) & (word("`toks'",5)=="M") {
                        local vm = real(substr(word("`toks'",4),2,.))
                        post `ph' ("`C'") (`yr') ("`sv'") ("master") (`vm') (.) ("") ("`S'") ("`V'")
                    }
                    else if (`wc'==8) & (word("`toks'",8)!="") {
                        local vm = real(substr(word("`toks'",4),2,.))
                        local va = real(substr(word("`toks'",6),2,.))
                        local cl = word("`toks'",8)
                        post `ph' ("`C'") (`yr') ("`sv'") ("adaptation") (`vm') (`va') ("`cl'") ("`S'") ("`V'")
                    }
                }
            }
        }
        postclose `ph'
        use `cat', clear
        sort country year survey kind collection master_version adaptation_version
        return local n = _N
        return local root "`root'"
    }

end
