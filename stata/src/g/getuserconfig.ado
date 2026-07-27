*! getuserconfig 1.2.0  — load per-operator paths from the user config file(s)
*! Stata port of the team R user-config routine.  Zero dependencies: parses the
*! constrained two-level YAML schema (<username>: {key: value}) natively, so it
*! runs unchanged on locked-down machines with no YAML/Python stack.
*!
*! Supported subset: a top-level map of <username> blocks, each with indented
*! "key: value" scalars (quoted or unquoted). "#" comments and blank lines are
*! ignored. NOT supported: lists, nested maps >2 deep, multiline scalars,
*! anchors. Use spaces (not tabs) for indentation and forward slashes in paths.
*!
*! v1.1.0 (contract v1 config seam): the library-root key uses a TWO-FILE
*! key-presence search — the current user's block is looked up first in
*! user_config.yml, then in datalib_config.yml; the FIRST file whose block
*! carries a non-empty `datalib:` key wins (block-level, never merged). The
*! full block (githubFolder, teamsRoot, ...) comes from the first file that
*! has the user block. r(source_stage) reports where the root came from
*! (config_generic / config_package), byte-identical to R and Python.
*! Isolation hooks: env DATALIB_CONFIG pins one file (fallback off); env
*! DATALIB_CONFIG_DIR searches the two-file list in another directory.

* --- internal: parse ONE file for ONE user's block --------------------------
capture program drop _dl_parse_cfg
program define _dl_parse_cfg, rclass
    version 15
    syntax , FILE(string) USER(string)

    return local found 0
    capture confirm file `"`file'"'
    if _rc exit

    tempname fh
    file open `fh' using `"`file'"', read text
    local in_target 0
    local found     0
    local githubFolder ""
    local teamsRoot    ""
    local zDrive       ""
    local zDriveUNC    ""
    local datalibRoot  ""

    file read `fh' line
    while (r(eof)==0) {
        local raw = subinstr(`"`macval(line)'"', char(13), "", .)   // drop CR (CRLF)
        * Drop a UTF-8 BOM as well. Windows PowerShell's -Out-File- and ">"
        * write one by default, and it would make the first line eight
        * characters, so the leading username block goes unrecognised and the
        * command reports "no entry for user" on a file that plainly has one.
        local raw = subinstr(`"`macval(raw)'"', uchar(65279), "", .)
        local trm = trim(`"`macval(raw)'"')
        local len = strlen(`"`macval(trm)'"')

        if (`len'>0 & substr(`"`macval(trm)'"',1,1)!="#") {
            local lead = strlen(`"`macval(raw)'"') - strlen(ltrim(`"`macval(raw)'"'))
            local cpos = strpos(`"`macval(trm)'"', ":")

            if (`lead'==0 & `cpos'>0) {
                * top-level key: <username>:
                local key = trim(substr(`"`macval(trm)'"', 1, `cpos'-1))
                local in_target = ("`key'"=="`user'")
                if (`in_target') local found 1
            }
            else if (`in_target' & `cpos'>0) {
                * indented "key: value" (first colon splits key/value)
                local k = trim(substr(`"`macval(trm)'"', 1, `cpos'-1))
                local v = trim(substr(`"`macval(trm)'"', `cpos'+1, `len'-`cpos'))

                local q = substr(`"`macval(v)'"', 1, 1)
                if (`"`macval(q)'"'==char(34) | `"`macval(q)'"'==char(39)) {
                    local v  = substr(`"`macval(v)'"', 2, strlen(`"`macval(v)'"')-1)
                    local qp = strpos(`"`macval(v)'"', `"`macval(q)'"')
                    if (`qp'>0) local v = substr(`"`macval(v)'"', 1, `qp'-1)
                }
                else if (strpos(`"`macval(v)'"', " #")>0) {
                    local v = trim(substr(`"`macval(v)'"', 1, strpos(`"`macval(v)'"', " #")-1))
                }

                if ("`k'"=="githubFolder") local githubFolder `"`macval(v)'"'
                if ("`k'"=="teamsRoot")    local teamsRoot    `"`macval(v)'"'
                if ("`k'"=="zDrive")       local zDrive       `"`macval(v)'"'
                if ("`k'"=="zDriveUNC")    local zDriveUNC    `"`macval(v)'"'
                if ("`k'"=="datalib")      local datalibRoot  `"`macval(v)'"'
            }
        }
        file read `fh' line
    }
    file close `fh'

    return local found        `found'
    return local githubFolder `"`macval(githubFolder)'"'
    return local teamsRoot    `"`macval(teamsRoot)'"'
    return local zDrive       `"`macval(zDrive)'"'
    return local zDriveUNC    `"`macval(zDriveUNC)'"'
    return local datalib      `"`macval(datalibRoot)'"'
end

* --- getuserconfig ----------------------------------------------------------
capture program drop getuserconfig
program define getuserconfig, rclass
    version 15
    syntax [, USER(string) CONFIG(string) CONFIGDIR(string) ///
              INIT LIBrary(string) PROFILE REPLACE EDIT]

    if ("`user'"=="") local user = c(username)

    * ---- init: write a prepopulated block, then read it -------------------
    * Opt-in only. The read path below never writes: a command that creates
    * files when its read fails would make the CFG golden cases non-hermetic
    * and repeats the _mkdir side-effect defect (see tests/DIVERGENCES.md).
    *
    * This stays GENERIC. Any value that needs project knowledge to find is
    * passed in -- library() carries the datalib: key, which -datalib config,
    * init- resolves before calling here. No project lookups belong in this
    * command: it is the shared loader, used outside datalib as well.
    if ("`init'"!="") {
        local initfile ""
        if (`"`config'"'!="")         local initfile `"`config'"'
        else if (`"`configdir'"'!="") local initfile `"`configdir'/user_config.yml"'
        _uc_init, user("`user'") file(`"`initfile'"') datalib(`"`library'"') ///
                  `profile' `replace' `edit'
        local cfgfile_new `"`r(file)'"'
        local cfgprofile  `"`r(profile)'"'
        local cfgaction   "`r(action)'"
        local cfgbackup   `"`r(backup)'"'
        local cfgtodo   = r(todo)
        * a missing r(todo) is ".", and ".>0" is TRUE in Stata, which would route
        * a writer failure into the "fill in your TODOs" path
        if missing(`cfgtodo') local cfgtodo 0
        * Same return names on both paths: whether we stop here or carry on to
        * the read, the bootstrap outcome is reported as r(init_*).
        if (`cfgtodo'>0) {
            noi di as txt `"{p}Fill in the TODO value(s), then run {bf:getuserconfig} again.{p_end}"'
            return local init_file    `"`cfgfile_new'"'
            return local init_profile `"`cfgprofile'"'
            return local init_action  "`cfgaction'"
            return local init_backup  `"`cfgbackup'"'
            return scalar init_todo = `cfgtodo'
            exit
        }
    }

    * ---- build the (at most two) config files ----
    * config()    pins one file (fallback off); configdir() / DATALIB_CONFIG_DIR
    * choose the search directory for the two-file list. configdir() is a
    * Stata-specific accommodation (Stata cannot set env vars in-session, so it
    * cannot use DATALIB_CONFIG_DIR the way the R/Python conformance tests do).
    local file1 ""
    local file2 ""
    if (`"`config'"'!="") {
        local file1 `"`config'"'                       // explicit: single file
    }
    else {
        local envfile : environment DATALIB_CONFIG
        if (`"`envfile'"'!="") {
            local file1 `"`envfile'"'                  // DATALIB_CONFIG: single file
        }
        else {
            local dir `"`configdir'"'
            if (`"`dir'"'=="") local dir : environment DATALIB_CONFIG_DIR
            if (`"`dir'"'=="") {
                local home : environment USERPROFILE
                if ("`home'"=="") local home : environment HOME
                local dir "`home'/.config"
            }
            local file1 `"`dir'/user_config.yml"'
            local file2 `"`dir'/datalib_config.yml"'
        }
    }

    * ---- full block from the first file with the user block; datalib key via
    *      two-file key-presence ----
    local anyfile    0
    local blockfound 0
    local cfgfile ""
    local gh ""
    local tr ""
    local zd ""
    local zu ""
    local dl ""
    local src_stage "unset"
    local src_file  ""

    forvalues i = 1/2 {
        local f `"`file`i''"'
        if (`"`f'"'=="") continue
        capture confirm file `"`f'"'
        if _rc continue
        local anyfile 1
        _dl_parse_cfg, file(`"`f'"') user(`"`user'"')
        if ("`r(found)'"=="1") {
            if (`blockfound'==0) {
                local blockfound 1
                local cfgfile `"`f'"'
                local gh `"`r(githubFolder)'"'
                local tr `"`r(teamsRoot)'"'
                local zd `"`r(zDrive)'"'
                local zu `"`r(zDriveUNC)'"'
            }
            if ("`dl'"=="" & `"`r(datalib)'"'!="") {
                local dl `"`r(datalib)'"'
                local src_file `"`f'"'
                local fslash = subinstr(`"`f'"', "\", "/", .)
                local base = substr(`"`fslash'"', strrpos(`"`fslash'"',"/")+1, .)
                if ("`base'"=="user_config.yml") local src_stage "config_generic"
                else local src_stage "config_package"
            }
        }
    }

    * ---- config file must exist -------------------------------------------
    if (`anyfile'==0) {
        di as error `"{p}Configuration file not found at expected path: `file1'.{p_end}"'
        di as error `"{p}Run {bf:getuserconfig, init} to write a prepopulated one — it fills in everything Stata can detect and flags anything left for you. Add {bf:profile} to also install a startup profile.do. A template lives in the repo under config/user_config.yml.{p_end}"'
        error 601
    }

    * ---- user entry must exist --------------------------------------------
    if (`blockfound'==0) {
        di as error `"{p}Configuration file found at: `cfgfile'`file1', but it has no entry for user '`user''.{p_end}"'
        di as error `"{p}Please ensure your username is correctly defined in the YAML file (template: config/user_config.yml).{p_end}"'
        error 459
    }

    * ---- Z: drive: non-blocking advisory mirror (default Z:/) --------------
    if (`"`macval(zd)'"'=="") local zd "Z:/"
    mata: st_local("zok", strofreal(direxists(st_local("zd"))))
    if ("`zok'"=="0") di as txt `"{p}Note: Z: mirror not mounted at `zd' (advisory only — continuing).{p_end}"'

    * ---- publish: globals (R-parity names) + r() --------------------------
    global githubFolder `"`macval(gh)'"'
    global teamsRoot    `"`macval(tr)'"'
    global zDrive       `"`macval(zd)'"'
    global zDriveUNC    `"`macval(zu)'"'

    * contract v1: optional per-user datalib root fills ${datalib} when unset
    if ("${datalib}"=="") & (`"`macval(dl)'"'!="") {
        global datalib `"`macval(dl)'"'
    }

    return local user         "`user'"
    return local config       `"`cfgfile'"'
    return local githubFolder `"`macval(gh)'"'
    return local teamsRoot    `"`macval(tr)'"'
    return local zDrive       `"`macval(zd)'"'
    return local zDriveUNC    `"`macval(zu)'"'
    return local datalib      `"`macval(dl)'"'
    return local source_stage "`src_stage'"
    return local source_file  `"`src_file'"'

    * When -init- wrote (or kept) a complete configuration we carry on to the
    * read above, whose returns replace the writer's. Report the bootstrap
    * outcome under its own names so a caller can still see what happened.
    if ("`init'"!="") {
        return local init_action  "`cfgaction'"
        return local init_file    `"`cfgfile_new'"'
        return local init_profile `"`cfgprofile'"'
        return local init_backup  `"`cfgbackup'"'
        return scalar init_todo = `cfgtodo'
    }

    di as result `"{p}Loaded user configuration for '`user'' from: `cfgfile' (datalib root: `src_stage').{p_end}"'
end
