*******************************************************
* datalib_files: contract v1 file lister for a resolved vintage (pure r())
* Author: Joao Pedro Azevedo
*! Version: 0.9.3       Date: <2026-07-25>
* Sections: data (Data/Stata), data-original, data-r, doc, programs.
*******************************************************

capture program drop datalib_files
program define datalib_files, rclass

    version 15

    syntax , country(string)              ///
        [                                 ///
            year(string)                  ///
            survey(string)                ///
            KINd(string)                  ///
            collection(string)            ///
            master_version(string)        ///
            adaptation_version(string)    ///
            SECtion(string)               ///
            pattern(string)               ///
            root(string)                  ///
        ]

    quietly {
        if ("`section'"=="") local section "data"
        if ("`pattern'"=="") local pattern "*"

        datalib_resolve, country(`country') year(`year') survey(`survey') ///
            kind(`kind') collection(`collection') ///
            master_version(`master_version') adaptation_version(`adaptation_version') ///
            root("`root'")

        if ("`section'"=="data")               local dir "`r(data_stata)'"
        else if ("`section'"=="data-original") local dir "`r(data_original)'"
        else if ("`section'"=="data-r")        local dir "`r(data_r)'"
        else if ("`section'"=="data-other")    local dir "`r(data_other)'"
        else if ("`section'"=="doc")           local dir "`r(doc)'"
        else if ("`section'"=="programs")      local dir "`r(programs)'"
        else {
            di as err "section() must be data, data-original, data-r, data-other, doc, or programs."
            exit 198
        }

        return add
        * a missing section directory is an empty listing, not an error
        * (contract: "zero rows when the section is empty or missing")
        mata: st_local("secok", strofreal(direxists(st_local("dir"))))
        local flist ""
        if ("`secok'"=="1") {
            local flist : dir "`dir'" files "`pattern'"
        }
        local out ""
        foreach f in `flist' {
            local out `"`out' "`f'""'
        }
        return local files = trim(`"`out'"')
        return local n = wordcount(`"`out'"')
        return local dir "`dir'"
        return local section "`section'"
    }

end
