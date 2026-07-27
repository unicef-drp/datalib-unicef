*******************************************************
* datalib_adaptations: contract v1 collection enumerator for a survey (pure r())
* Author: Joao Pedro Azevedo
*! Version: 0.9.3       Date: <2026-07-25>
* Returns the unique adaptation collections; empty list when none (no sentinels).
*******************************************************

capture program drop datalib_adaptations
program define datalib_adaptations, rclass

    version 15

    syntax , country(string) year(string) survey(string) [ root(string) ]

    quietly {
        datalib_vintages, country(`country') year(`year') survey(`survey') root("`root'")
        local out ""
        foreach t in `r(adaptations)' {
            local cl = substr("`t'", 1, strpos("`t'", ":")-1)
            local out : list out | cl
        }
        local out : list sort out
        return local collections = trim(`"`out'"')
        return local n = wordcount(`"`out'"')
    }

end
