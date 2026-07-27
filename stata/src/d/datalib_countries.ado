*******************************************************
* datalib_countries: contract v1 country enumerator (pure r(), no data touched)
* Author: Joao Pedro Azevedo
*! Version: 0.9.7       Date: <2026-07-26>
*******************************************************

capture program drop datalib_countries
program define datalib_countries, rclass

    version 15

    syntax [, root(string) ]

    quietly {
        if ("`root'"=="") local root "${datalib}"
        if ("`root'"=="") local root : environment DATALIB_ROOT
        if ("`root'"=="") {
            di as err "datalib root not set: pass root(), set global datalib, or set DATALIB_ROOT."
            exit 198
        }

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
        local clist : dir "`root'/" dirs "*"
        local out ""
        foreach c in `clist' {
            local out "`out' `=upper("`c'")'"
        }
        local out : list sort out
        return local countries = trim("`out'")
        return local n = wordcount("`out'")
        return local root "`root'"
    }

end
