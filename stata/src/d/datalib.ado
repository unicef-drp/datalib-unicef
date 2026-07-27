*******************************************************
** datalib 
* Joao Pedro Azevedo and Minh Cong Nguyen
*! v0.9.19
*******************************************************

capture program drop datalib
program define datalib, rclass

    version 15

    *---------------------------------------------------------------------------
    * Subcommand dispatch: -datalib <subcmd> ...- runs -datalib_<subcmd> ...-
    * Exact lowercase match only; anything else falls through to the legacy
    * surface below (whose calls always start with a comma or are bare).
    *---------------------------------------------------------------------------
    gettoken sub rest : 0, parse(" ,")
    local subcmds resolve load catalog countries surveys vintages ///
                  adaptations files create config root browse map_drive
    * Guard the empty token: -:list "" in subcmds- is true (an empty list is
    * contained in any list), which would dispatch a bare -datalib- to -datalib_-.
    if ("`sub'"!="") & (`:list sub in subcmds') {
        datalib_`sub' `rest'
        return add
        exit
    }

    * No [varlist]/[if]/[in]: they were declared but never referenced, and the
    * first token position is now the subcommand slot (a dataset variable named
    * e.g. -load- or -root- must not be swallowed there).
    syntax  [,                           ///
                update                   ///
                install                  ///
                force                    ///
                netsource(string)        ///
                subfoldr(string)         ///
                country(string)          ///
                year(string)             ///
                survey(string)           ///
                MODule(string)           ///
                filename(string)         ///
                MASter                   ///
                adaptation               ///
                LATest                   ///
                collection(string)       ///
                harmonization(string)    ///
                VM(string)               ///
                VA(string)               ///
                debug                    ///
                data                     ///   
                doc                      ///
                programs                 ///
                NOMerge                  ///
                clear                    ///
                path(string)         ///
                LIBrary(string)          ///
            ]

    *---------------------------------------------------------------------------
    * Package maintenance. Handled BEFORE library resolution and returning
    * immediately: checking whether a newer datalib exists must work on a machine
    * where no library is configured yet -- which is exactly the machine most
    * likely to need an update. Delegated to _dl_update so the front door stays a
    * dispatcher.
    *
    * Deliberately an OPTION, not a subcommand: -datalib-'s subcommand list is
    * asserted to be exactly the 13 canonical contract commands (see
    * config/surface.yml and python/tests/test_surface.py), and update is a
    * Stata-only maintenance affordance, not part of the trilingual contract.
    *---------------------------------------------------------------------------
    if ("`update'"!="") {
        _dl_update, netsource(`"`netsource'"') `install' `force'
        return add
        exit
    }

    *---------------------------------------------------------------------------
    * Library root, resolved in -find- mode: library() outranks the config chain
    * (${datalib}, which getuserconfig fills from the user_config datalib: key,
    * then DATALIB_ROOT); a candidate may name the library or the place holding
    * it; and with nothing configured a library named "datalib" is discovered.
    * datalib_root stops with an actionable error naming library() rather than
    * letting _foldernav/_dlw fail later with a bare -directory not found-.
    *
    * The resolved root is published to ${datalib} because the clickable
    * navigation links _foldernav writes carry no library() option — they must
    * find the same library on the next call.
    *---------------------------------------------------------------------------
    * The interactive navigation carries its click-state in r(subfoldr) from one
    * call to the next, and datalib_root is rclass — resolving here would wipe
    * it and break the DATA / DOC / PROGRAMS links. So hold r() across the
    * resolution, and skip it entirely once this session has already validated
    * the library (which also keeps a slow network share from being probed on
    * every single call).
    capture _return drop _dl_rhold
    capture _return hold _dl_rhold
    local _dl_held = (_rc==0)

    if (`"`library'"'!="") {
        datalib_root, root(`"`library'"') find set
        global datalib_checked `"${datalib}"'
    }
    else if !((`"`path'"'!="") & (`"`subfoldr'"'!="")) {
        if ("${datalib}"=="") capture getuserconfig
        if (`"${datalib}"'!=`"${datalib_checked}"') {
            datalib_root, find set
            global datalib_checked `"${datalib}"'
        }
    }

    if (`_dl_held') capture _return restore _dl_rhold

    quietly {

        * Interactive navigation starts if no country, year, or survey is specified
        if ("`country'" == "") & ("`year'" == "") & ("`survey'" == "") & ("`subfoldr'" == "") {
            noi _foldernav
        }
        else if ("`country'" != "") & (("`year'" == "") | ("`survey'" == "")) & ("`subfoldr'" == "") {
            noi _foldernav, country(`country')
            return add   
        }
        else if ("`subfoldr'" != "") {
            noi _foldernav, subfoldr("`subfoldr'") path("`path'")
            return add   
        }
        else if ("`country'" != "") & ("`year'" != "") & ("`survey'" != "")  & ("`subfoldr'" == "") {
            * Load and process data using the _dlw program
            _dlw                                   ///
                ,                                  ///
                    country(`country')             ///
                    year(`year')                   ///
                    survey(`survey')               ///
                    module(`module')               ///
                    filename("`filename'")         ///
                    `master'                       ///
                    `adaptation'                   ///
                    `latest'                       ///
                    collection(`collection')       ///
                    harmonization(`harmonization') ///
                    va(`va')                       ///
                    vm(`vm')                       ///
                    `debug'                        ///
                    `nomerge'                      ///
                    `clear'                        ///
                    `data'                         ///   
                    `doc'                          ///
                    `programs'

            return add   
        }
    }

end
