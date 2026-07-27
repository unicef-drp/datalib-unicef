*******************************************************
** _uc_init
* Joao Pedro Azevedo
*! v0.9.3
*******************************************************
* Bootstrap an operator's user configuration: write a prepopulated
* user_config.yml block, and optionally a startup profile.do that loads it.
* Fills in everything Stata can detect for itself, so a new user has at most
* one or two values left to supply.
*
* GENERIC by design. This helper belongs to the -getuserconfig- family, not to
* datalib: it knows the config schema and nothing about any library. A caller
* that can resolve a value passes it in (see the datalib() option, used by
* -datalib config, init-). Do not add project-specific lookups here.
*
* This is a WRITE, reached only when a caller explicitly asks for it. The
* config READ path never creates files: a read that writes on failure would
* make the CFG golden cases non-hermetic and repeat the _mkdir side-effect
* defect recorded in tests/DIVERGENCES.md.
*
* Safety rules:
*   - nothing is ever overwritten. A config that already carries this user's
*     block is left as found (unless -replace-), and an existing profile.do is
*     never touched;
*   - when the config exists but has no block for this user, the block is
*     APPENDED: the file is shared with the R/DW routines and holds other
*     operators' blocks, so it is only ever added to;
*   - a value that cannot be determined unambiguously is written as a commented
*     TODO with the candidates listed, never guessed.
*
* NOTE on user(): on the READ path user() means "look at someone else's block".
* Here it means "write a block LABELLED this, using THIS machine's detected
* paths" -- so user(colleague) puts your paths under their name. Intended for
* the conformance cases; ordinary callers should omit it.
*
* Returns:
*   r(file)     the config file
*   r(profile)  the profile.do written or found ("" if not requested)
*   r(action)   created | appended | replaced | kept
*   r(todo)     number of values the user still has to fill in
*   r(opened)   1 if the files were opened in the do-file editor
*******************************************************

capture program drop _uc_init
program define _uc_init, rclass

    version 15

    syntax [, USER(string) FILE(string) DATALIB(string) PROFILE REPLACE EDIT ]

    quietly {
        if ("`user'"=="") local user = c(username)

        local home : environment USERPROFILE
        if ("`home'"=="") local home : environment HOME
        if (`"`home'"'=="") {
            noi di as err `"{p}Neither USERPROFILE nor HOME is set, so the config location cannot be determined. Pass {bf:file(}{it:path}{bf:)}.{p_end}"'
            exit 198
        }
        local home = subinstr(`"`home'"', "\", "/", .)

        * ---- where the config goes -----------------------------------------
        if (`"`file'"'=="") {
            local dir `"`home'/.config"'
            capture mkdir `"`dir'"'
            local file `"`dir'/user_config.yml"'
        }
        local file = subinstr(`"`file'"', "\", "/", .)

        * ---- does it exist, and already know this user? ---------------------
        local exists   0
        local hasblock 0
        capture confirm file `"`file'"'
        if (_rc==0) {
            local exists 1
            tempname fh
            file open `fh' using `"`file'"', read text
            file read `fh' line
            while (r(eof)==0) {
                * Strip CR and a UTF-8 BOM before comparing. _dl_parse_cfg
                * already defends against CR; a BOM makes the first line eight
                * characters and would defeat the match, so an existing block
                * would be missed and a DUPLICATE appended.
                local probe = subinstr(`"`macval(line)'"', char(13), "", .)
                local probe = subinstr(`"`macval(probe)'"', uchar(65279), "", .)
                if (trim(`"`macval(probe)'"')=="`user':") local hasblock 1
                file read `fh' line
            }
            file close `fh'
        }

        * ---- the startup profile -------------------------------------------
        * PERSONAL is the right home: it is on the adopath, so Stata runs the
        * profile at launch, and it needs no administrator rights (unlike the
        * Stata installation directory).
        local prof ""
        local profexists 0
        if ("`profile'"!="") {
            local pdir = subinstr(`"`c(sysdir_personal)'"', "\", "/", .)
            while (substr(`"`pdir'"', -1, 1)=="/") {
                local pdir = substr(`"`pdir'"', 1, strlen(`"`pdir'"')-1)
            }
            capture mkdir `"`pdir'"'
            local prof `"`pdir'/profile.do"'
            capture confirm file `"`prof'"'
            if (_rc==0) local profexists 1
        }

        * ---- the config already has this operator's block -------------------
        * Then the config is DONE, whatever the profile situation. A missing
        * profile.do is written below; it must never drag the config into a
        * rewrite, because appending a second "<user>:" makes a duplicate
        * top-level key and R's yaml::read_yaml -- the reader at
        * r/R/datalib_config.R -- hard-errors on it ("Duplicate map key"),
        * taking down the operator's R tooling. Stata and Python tolerate
        * duplicates (last wins), which is exactly why a Stata-only test cannot
        * see the breakage.
        if (`exists'==1) & (`hasblock'==1) & ("`replace'"=="") {
            if ("`profile'"!="") & (`profexists'==0) {
                _uc_writeprofile `"`prof'"'
                noi di as result `"{p}Startup profile written: `prof'{p_end}"'
            }
            noi di as result `"{p}Configuration for '`user'' already in place — config unchanged.{p_end}"'
            noi di as txt    `"{p}  config:  `file'{p_end}"'
            if (`"`prof'"'!="") noi di as txt `"{p}  profile: `prof'{p_end}"'
            _uc_open `"`file'"' `"`prof'"'
            local opened = r(opened)
            return local file    `"`file'"'
            return local profile `"`prof'"'
            return local action  "kept"
            return scalar todo   = 0
            return scalar opened = `opened'
            exit
        }

        * ---- detect what we can --------------------------------------------
        local todo 0

        * githubFolder: -whereis- knows it when the operator has stored it
        local gh ""
        capture whereis github
        if (_rc==0) local gh = subinstr(`"`r(github)'"', "\", "/", .)

        * teamsRoot: the synced Teams roots are named "<site> - <library>", so
        * prefer the "- Documents" ones. Mata's dir() is used rather than the
        * -dir- macro function because -dir- lowercases names on Windows, and a
        * lowercased path would be wrong for the R/Python readers on a
        * case-sensitive filesystem.
        local tr ""
        local cands ""
        local ncand 0
        capture _uc_dirs `"`home'/UNICEF"' "*- Documents"
        if (_rc==0) {
            local cands `"`r(dirs)'"'
            local ncand = r(n)
        }
        if (`ncand'==0) {
            capture _uc_dirs `"`home'/UNICEF"' "*"
            if (_rc==0) {
                local cands `"`r(dirs)'"'
                local ncand = r(n)
            }
        }
        if (`ncand'==1) local tr `"`home'/UNICEF/`:word 1 of `cands''"'

        * zDrive / zDriveUNC: mapzdrive already knows how to read the mapping
        * mapzdrive reports its default letter with rc 0 even when nothing is
        * mapped, and an empty r(unc) is the tell. Writing "zDrive: Z:" on that
        * basis would be a guess dressed as a detected value, and would leave
        * r(todo)==0 while the mapping is in fact missing.
        local zd ""
        local zu ""
        if ("`c(os)'"=="Windows") {
            capture mapzdrive, discover
            if (_rc==0) & (`"`r(unc)'"'!="") {
                local zd `"`r(letter)'"'
                local zu `"`r(unc)'"'
            }
        }

        * ---- compose the block ---------------------------------------------
        tempfile blk
        tempname bh
        file open `bh' using `"`blk'"', write text replace
        file write `bh' "`user':" _n
        if (`"`gh'"'!="") file write `bh' `"  githubFolder: "`gh'""' _n
        else {
            file write `bh' `"  # TODO githubFolder: "C:/path/to/your/GitHub/folder""' _n
            local ++todo
        }
        if (`"`tr'"'!="") {
            * A single match is used, but flagged: one synced root does not mean
            * the RIGHT one, and a wrong-but-plausible teamsRoot sends downstream
            * writes into a corporate document library.
            file write `bh' `"  teamsRoot: "`tr'"   # detected automatically -- check this is the one you use"' _n
        }
        else {
            file write `bh' `"  # TODO teamsRoot: uncomment the one you use"' _n
            local ++todo
            local shown 0
            foreach c of local cands {
                if (`shown'>=8) continue, break
                file write `bh' `"  #   teamsRoot: "`home'/UNICEF/`c'""' _n
                local ++shown
            }
            if (`ncand'>8) file write `bh' `"  #   ... and `=`ncand'-8' more under `home'/UNICEF"' _n
        }
        if (`"`datalib'"'!="") file write `bh' `"  datalib: "`datalib'""' _n
        else {
            file write `bh' `"  # TODO datalib: "Z:/datalib"   <- the library root (or the folder holding it)"' _n
            local ++todo
        }
        if (`"`zd'"'!="") file write `bh' `"  zDrive: "`zd'""' _n
        if (`"`zu'"'!="") file write `bh' `"  zDriveUNC: '`zu''"' _n
        if (`"`zu'"'=="") {
            file write `bh' `"  # TODO zDrive: "Z:/"          <- no drive is mapped right now"' _n
            file write `bh' `"  # TODO zDriveUNC: '\server\share'"' _n
            local ++todo
        }
        file close `bh'

        * ---- write the config, atomically ----------------------------------
        * One path for all three cases. The intended file is built in full in a
        * tempfile and then moved into place, so a failure part-way cannot leave
        * a shared config half-written, and the newline before the new block is
        * under our control rather than depending on how the previous editor
        * saved the file. Also, since we back a pre-existing file up first,
        * there is always something to restore from.
        if (`exists'==1) {
            * Back up before touching a file we did not create. It carries other
            * operators' blocks and is read by the R and Python routines too.
            local stamp = subinstr(subinstr("`c(current_date)'", " ", "", .), ":", "", .)
            local bak `"`file'.bak"'
            capture copy `"`file'"' `"`bak'"', replace
            if (_rc==0) noi di as txt `"{p}Backup of the previous configuration: `bak'{p_end}"'
        }

        tempfile out
        tempname oh rh sh
        file open `oh' using `"`out'"', write text replace

        if (`exists'==0) {
            file write `oh' "# user_config.yml -- per-operator paths, one block per machine username." _n
            file write `oh' "# Generated by -getuserconfig, init-. Read by the Stata, R and Python" _n
            file write `oh' "# routines alike, so keep it valid YAML: two-space indent, no tabs," _n
            file write `oh' "# forward slashes in paths, and UNC paths in single quotes." _n
            local action "created"
        }
        else {
            * Copy the existing file through, dropping this operator's block when
            * -replace- was asked for: appending a second "<user>:" would make a
            * duplicate top-level key, and R's yaml::read_yaml rejects those
            * outright. Every other operator's block is copied verbatim.
            if (`hasblock'==1) local action "replaced"
            else               local action "appended"
            local skipping 0
            local lastblank 0
            file open `sh' using `"`file'"', read text
            file read `sh' line
            while (r(eof)==0) {
                local raw = subinstr(`"`macval(line)'"', char(13), "", .)
                local raw = subinstr(`"`macval(raw)'"', uchar(65279), "", .)
                local trm = trim(`"`macval(raw)'"')
                local lead = strlen(`"`macval(raw)'"') - strlen(ltrim(`"`macval(raw)'"'))
                if (`lead'==0) & (`"`macval(trm)'"'!="") & ///
                   (substr(`"`macval(trm)'"',1,1)!="#") & (strpos(`"`macval(trm)'"',":")>0) {
                    local k = trim(substr(`"`macval(trm)'"', 1, strpos(`"`macval(trm)'"',":")-1))
                    local skipping = ("`k'"=="`user'") & (`hasblock'==1)
                }
                if (`skipping'==0) {
                    file write `oh' `"`macval(raw)'"' _n
                    local lastblank = (`"`macval(trm)'"'=="")
                }
                file read `sh' line
            }
            file close `sh'
            * exactly one blank line before the new block, however the source ended
            if (`lastblank'==0) file write `oh' "" _n
        }

        file open `rh' using `"`blk'"', read text
        file read `rh' line
        while (r(eof)==0) {
            file write `oh' `"`macval(line)'"' _n
            file read `rh' line
        }
        file close `rh'
        file close `oh'

        capture erase `"`file'"'
        copy `"`out'"' `"`file'"'

        * ---- write the startup profile -------------------------------------
        if ("`profile'"!="") & (`profexists'==0) {
            _uc_writeprofile `"`prof'"'
            noi di as result `"{p}Startup profile written: `prof'{p_end}"'
        }

        noi di as result `"{p}Configuration for '`user'' `action' in `file'.{p_end}"'
        if (`"`datalib'"'!="") noi di as result `"{p}  datalib: `datalib'{p_end}"'
        if (`todo'>0) noi di as error `"{p}`todo' value(s) still to fill in — search the file for {bf:TODO}.{p_end}"'

        * Open when asked, and always when something is left to fill in: a file
        * with TODOs in it is of no use until the operator edits it.
        local opened 0
        if ("`edit'"!="") | (`todo'>0) {
            _uc_open `"`file'"' `"`prof'"'
            local opened = r(opened)
        }

        return local file    `"`file'"'
        return local profile `"`prof'"'
        return local action  "`action'"
        return scalar todo   = `todo'
        return scalar opened = `opened'
        return local  backup `"`bak'"'
    }

end

* --- internal: write the startup profile ------------------------------------
capture program drop _uc_writeprofile
program define _uc_writeprofile
    version 15
    args prof
    tempname ph
    file open `ph' using `"`prof'"', write text replace
    file write `ph' "* profile.do -- Stata startup file (PERSONAL adopath)." _n
    file write `ph' "* Publishes this operator's paths from ~/.config/user_config.yml." _n
    file write `ph' "* Written by -getuserconfig, init profile-. Safe to delete." _n
    file write `ph' "*" _n
    file write `ph' "* The -which- check matters: this file outlives" _n
    file write `ph' "* -ado uninstall datalib-, and -capture noisily- on a missing" _n
    file write `ph' "* command still prints an unrecognized-command error, so" _n
    file write `ph' "* without it every Stata launch would nag after an uninstall." _n
    file write `ph' "capture which getuserconfig" _n
    file write `ph' "if !_rc capture noisily getuserconfig" _n
    file close `ph'
end

* --- internal: case-preserving directory listing ----------------------------
* Stata's -dir- macro function lowercases names on Windows; Mata's dir() does
* not, and these names end up in a config file the R/Python readers parse.
capture program drop _uc_dirs
program define _uc_dirs, rclass
    version 15
    args base pattern
    * One dir() call: re-reading it per element would rely on the listing order
    * being stable between calls, which is not a documented contract, and an
    * index past rows() aborts Mata.
    local out ""
    capture mata: st_local("out", invtokens((char(34) :+ dir(st_local("base"), "dirs", st_local("pattern")) :+ char(34))'))
    local n : word count `out'
    return local dirs `"`out'"'
    return scalar n = `n'
end

* --- internal: open the files for editing, when that is possible ------------
capture program drop _uc_open
program define _uc_open, rclass
    version 15
    args f p
    * doedit belongs to the GUI. In the console build it is unrecognized, and in
    * BATCH mode c(console) is empty while doedit still returns rc 0 -- so it
    * would silently open editor tabs during a scripted run. Both must be gated.
    if ("`c(console)'"!="") | ("`c(mode)'"=="batch") {
        noi di as txt `"{p}Not an interactive session — edit the file(s) above yourself.{p_end}"'
        return scalar opened = 0
        exit
    }
    capture doedit `"`f'"'
    local ok = (_rc==0)
    if (`"`p'"'!="") capture doedit `"`p'"'
    return scalar opened = `ok'
end
