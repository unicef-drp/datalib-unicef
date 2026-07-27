*******************************************************
* datalib_surveys: contract v1 survey enumerator for a country (pure r())
* Author: Joao Pedro Azevedo
*! Version: 0.9.7       Date: <2026-07-26>
*******************************************************

capture program drop datalib_surveys
program define datalib_surveys, rclass

    version 15

    syntax , country(string) [ survey(string) root(string) ]

    quietly {
        if ("`root'"=="") local root "${datalib}"
        if ("`root'"=="") local root : environment DATALIB_ROOT
        if ("`root'"=="") {
            di as err "datalib root not set: pass root(), set global datalib, or set DATALIB_ROOT."
            exit 198
        }
        local country = upper(trim("`country'"))
        local survey  = upper(trim("`survey'"))


        * The root must EXIST before it is listed. A bare `: dir' on a missing
        * directory raises Stata's own rc 601 with an internal message, so the
        * only 601 a caller could observe was an unguarded leak. Contract error
        * not_found legitimately reaches 601 when the library itself is absent
        * (config/grammar.md section 6); this makes that deliberate.
        mata: st_local("_dlok", strofreal(direxists(st_local("root"))))
        if ("`_dlok'"!="1") {
            di as err "datalib library root not found: `root'."
            exit 601
        }
        local hit : dir "`root'/" dirs "`country'"
        if (`"`hit'"'=="") {
            di as err "Country `country' not found in datalib (`root')."
            exit 198
        }

        if ("`survey'"!="") local flist : dir "`root'/`country'" dirs "*_`survey'"
        else                local flist : dir "`root'/`country'" dirs "*_*_*"

        local folders ""
        local ymax = -1
        local latest_survey ""
        foreach f in `flist' {
            local F = upper("`f'")
            local folders "`folders' `F'"
            local yr = real(word(subinstr("`F'","_"," ",.),2))
            if (`yr'<.) & (`yr'>`ymax') {
                local ymax = `yr'
                local latest_survey = word(subinstr("`F'","_"," ",.),3)
            }
        }
        local folders : list sort folders
        return local surveys = trim("`folders'")
        return local n = wordcount("`folders'")
        if (`ymax'>=0) {
            return local latest_year   "`ymax'"
            return local latest_survey "`latest_survey'"
        }
        return local country "`country'"
        return local root "`root'"
    }

end
