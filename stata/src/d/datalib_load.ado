*******************************************************
* datalib_load: contract v1 loader — thin wrapper over _dlw
* Author: Joao Pedro Azevedo
*! Version: 0.9.3       Date: <2026-07-25>
* Maps the shared datalib_* argument names onto the _dlw engine:
*   modules() -> module(), kind(master|adaptation), master_version() -> vm(),
*   adaptation_version() -> va(), merge (default) / nomerge.
*******************************************************

capture program drop datalib_load
program define datalib_load, rclass

    version 15

    syntax , country(string)              ///
        [                                 ///
            year(string)                  ///
            survey(string)                ///
            MODules(string)               ///
            KINd(string)                  ///
            collection(string)            ///
            master_version(string)        ///
            adaptation_version(string)    ///
            filename(string)              ///
            NOMerge                       ///
            clear                         ///
            DEBUG                         ///
            root(string)                  ///
        ]

    quietly {
        if ("`kind'"=="") local kind = cond("`collection'"!="", "adaptation", "adaptation")
        local kind = lower(trim("`kind'"))
        if !inlist("`kind'", "master", "adaptation") {
            di as err "kind() must be master or adaptation."
            exit 198
        }

        * root(): _dlw reads ${datalib}; honor root() without clobbering the
        * global, and fall back to env DATALIB_ROOT like the other wrappers
        local oldroot "${datalib}"
        if ("`root'"=="") & ("${datalib}"=="") {
            local root : environment DATALIB_ROOT
        }
        if ("`root'"!="") global datalib "`root'"

        local kopt ""
        if ("`kind'"=="master") local kopt "master"
        else {
            if ("`collection'"=="") local collection "HLT"
            local kopt "adaptation collection(`collection')"
        }
        local fopt ""
        if ("`filename'"!="") local fopt `"filename("`filename'") data"'

        capture noisily _dlw , country(`country') year(`year') survey(`survey') ///
            module(`modules') `kopt' vm(`master_version') va(`adaptation_version') ///
            `fopt' `nomerge' `clear' `debug'
        local rc = _rc

        if ("`root'"!="") global datalib "`oldroot'"
        if (`rc') exit `rc'
        return add
    }

end
