*******************************************************
** datalib 
* Joao Pedro Azevedo and Minh Cong Nguyen
*! v0.9.28
*******************************************************

capture program drop datalib
program define datalib, rclass

    version 15

    * The version of THIS file, compiled in. It cannot be read from the `*!' stamp
    * at runtime: that would mean reading datalib.ado from disk, and the disk copy
    * is exactly what this literal exists to be compared against. -net install-
    * replaces the file while Stata keeps the old program in memory, so after an
    * install without -discard- the two diverge and every disk-based indicator
    * (-which datalib-, the trk, the stamp) reports the new version about a session
    * still running the old code. Pinned to VERSION by test_stamps.py.
    local RUNNING "0.9.28"

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
                explorer                 ///
                NOFILES                  ///
                files                    ///
                sizes                    ///
                MAXitems(integer 400)    ///
                PERpage(integer 0)       ///
                PAGE(integer 1)          ///
                index                    ///
                dirs                     ///
                MAXDepth(integer 0)      ///
                MAXNodes(integer 400)    ///
                pattern(string)          ///
                saving(string)           ///
                replace                  ///
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
        _dl_update, netsource(`"`netsource'"') `install' `force' ///
            running("`RUNNING'")
        return add
        exit
    }

    * Dispatched BEFORE library resolution, deliberately: explorer walks ARBITRARY
    * trees, and datalib_root would apply _dl_islib -- the very gate this option
    * exists to bypass. root() falls back to ${datalib} inside datalib_explorer, so
    * the common case still needs no argument.
    if ("`explorer'"!="") {
        datalib_explorer, path(`"`path'"') root(`"`library'"') `files' `nofiles' `sizes' ///
            maxitems(`maxitems') perpage(`perpage') page(`page')
        return add
        exit
    }

    * Also before library resolution, and for the same reason as explorer: it walks an
    * ARBITRARY tree, so _dl_islib must not get a vote. Note it REPLACES the data in
    * memory -- that is why `clear' has to be passed through rather than assumed.
    if ("`index'"!="") {
        datalib_index, path(`"`path'"') root(`"`library'"') `dirs' `sizes' `clear' ///
            maxdepth(`maxdepth') maxnodes(`maxnodes') ///
            pattern(`"`pattern'"') saving(`"`saving'"')
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
