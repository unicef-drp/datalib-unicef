*******************************************************
* datalib_vintages: contract v1 vintage enumerator for a survey (pure r())
* Author: Joao Pedro Azevedo
*! Version: 0.9.7       Date: <2026-07-26>
* Returns integer master vintages and collection:vm:va adaptation triples;
* "latest" is the numeric maximum, never listing order.
*******************************************************

capture program drop datalib_vintages
program define datalib_vintages, rclass

    version 15

    syntax , country(string) year(string) survey(string) [ root(string) ]

    quietly {
        if ("`root'"=="") local root "${datalib}"
        if ("`root'"=="") local root : environment DATALIB_ROOT
        if ("`root'"=="") {
            di as err "datalib root not set: pass root(), set global datalib, or set DATALIB_ROOT."
            exit 198
        }
        local country = upper(trim("`country'"))
        local survey  = upper(trim("`survey'"))
        local svyfld "`country'_`year'_`survey'"


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
        mata: st_local("_dlok", strofreal(direxists(st_local("root")+"/"+st_local("country"))))
        if ("`_dlok'"!="1") {
            di as err "Country `country' not found in datalib (`root')."
            exit 198
        }
        local hit : dir "`root'/`country'" dirs "`svyfld'"
        if (`"`hit'"'=="") {
            di as err "Survey folder `svyfld' not found."
            exit 198
        }

        local vdirs : dir "`root'/`country'/`svyfld'" dirs "`svyfld'_*"
        local masters ""
        local adapts ""
        local mmax = -1
        foreach d in `vdirs' {
            local D = upper("`d'")
            local toks = subinstr("`D'","_"," ",.)
            local wc = wordcount("`toks'")
            if (`wc'==5) & (word("`toks'",5)=="M") {
                local n = real(substr(word("`toks'",4),2,.))
                local masters "`masters' `=string(`n')'"
                if (`n'<.) & (`n'>`mmax') local mmax = `n'
            }
            else if (`wc'==8) {
                local vm = real(substr(word("`toks'",4),2,.))
                local va = real(substr(word("`toks'",6),2,.))
                local cl = word("`toks'",8)
                local adapts "`adapts' `cl':`=string(`vm')':`=string(`va')'"
            }
        }
        return local masters       = trim("`masters'")
        return local n_masters     = wordcount("`masters'")
        if (`mmax'>=0) return local latest_master "`mmax'"
        return local adaptations   = trim("`adapts'")
        return local n_adaptations = wordcount("`adapts'")
        return local has_master     = cond(wordcount("`masters'")>0, "1", "0")
        return local has_adaptation = cond(wordcount("`adapts'")>0, "1", "0")
        return local survey_folder "`svyfld'"
        return local root "`root'"
    }

end
