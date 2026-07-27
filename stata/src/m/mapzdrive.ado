*! mapzdrive 1.0.0 — map the configured network drive (default Z:) from user_config.yml
*! Reads the mount letter (zDrive) and share (zDriveUNC) via getuserconfig, then maps
*! the drive with `net use` when it is not already available. Windows-only. Safe by
*! default: never touches an existing mapping unless -force- is given.
*!
*! Examples:
*!   mapzdrive                                  // read config, map Z: if not present
*!   mapzdrive, dryrun                          // show the net use command, no change
*!   mapzdrive, discover                        // print the UNC of the current Z: map
*!   mapzdrive, letter(Y:) unc(\\host\share)    // explicit, no config needed

program define mapzdrive, rclass
    version 15
    syntax [, LETTER(string) UNC(string) USER(string) CONFIG(string) ///
              PERSISTENT(string) FORCE DRYrun DISCover]

    if ("`c(os)'"!="Windows") {
        di as error "mapzdrive maps a Windows network drive; this session is `c(os)'."
        error 198
    }

    * ---- discover: report an existing letter's remote, then exit ----------
    if ("`discover'"!="") {
        if (`"`letter'"'=="") local letter "Z:"
        local letter = upper(substr(`"`letter'"',1,1)) + ":"
        _mzremote "`letter'"
        if (`"`r(remote)'"'=="") di as txt "No mapping found on `letter'."
        else {
            di as result "`letter' is mapped to: `r(remote)'"
            di as txt    `"  -> add to user_config.yml:  zDriveUNC: '`r(remote)''"'
        }
        return local letter "`letter'"
        return local unc    `"`r(remote)'"'
        exit
    }

    * ---- resolve letter + unc (explicit options override the config) ------
    if (`"`letter'"'=="" | `"`unc'"'=="") {
        capture getuserconfig, user("`user'") config(`"`config'"')
        if (`"`letter'"'=="") local letter "${zDrive}"
        if (`"`unc'"'=="")    local unc    "${zDriveUNC}"
    }
    if (`"`letter'"'=="") local letter "Z:"
    local letter = upper(substr(`"`letter'"',1,1)) + ":"     // normalise to "X:"

    if (`"`unc'"'=="") {
        di as error `"{p}No share to map: set 'zDriveUNC' in your user_config.yml, or pass unc(). If `letter' is already mapped, run  {bf:mapzdrive, discover}  to read its UNC.{p_end}"'
        error 198
    }
    if (`"`persistent'"'=="") local persistent "yes"

    * ---- current state ----------------------------------------------------
    mata: st_local("avail", strofreal(direxists("`letter'/")))
    _mzremote "`letter'"
    local current `"`r(remote)'"'

    if ("`avail'"=="1") {
        if (`"`current'"'==`"`unc'"' | `"`current'"'=="") {
            di as result `"`letter' already mapped — nothing to do."'
            return local status "already-mapped"
            return local letter "`letter'"
            return local unc `"`unc'"'
            exit
        }
        else if ("`force'"=="") {
            di as error `"{p}`letter' is mapped to a different share (`current'). Re-run with -force- to remap it to `unc'.{p_end}"'
            error 198
        }
    }

    * ---- build + (optionally) run ----------------------------------------
    local delcmd `"net use `letter' /delete /y"'
    local mapcmd `"net use `letter' "`unc'" /persistent:`persistent'"'

    if ("`dryrun'"!="") {
        if ("`avail'"=="1" & "`force'"!="") di as txt `"[dryrun] `delcmd'"'
        di as txt `"[dryrun] `mapcmd'"'
        return local status "dryrun"
        return local letter "`letter'"
        return local unc `"`unc'"'
        exit
    }

    tempfile out
    if ("`avail'"=="1" & "`force'"!="") qui shell `delcmd' > "`out'" 2>&1
    qui shell `mapcmd' > "`out'" 2>&1

    mata: st_local("ok", strofreal(direxists("`letter'/")))
    if ("`ok'"=="1") {
        di as result `"Mapped `letter' -> `unc' (persistent: `persistent')."'
        return local status "mapped"
    }
    else {
        di as error `"{p}Failed to map `letter' -> `unc'. net use said:{p_end}"'
        type "`out'"
        return local status "failed"
    }
    return local letter "`letter'"
    return local unc `"`unc'"'
end

program define _mzremote, rclass
    version 15
    args letter
    tempfile out
    qui shell net use "`letter'" > "`out'" 2>&1
    tempname fh
    file open `fh' using "`out'", read text
    local remote ""
    file read `fh' line
    while (r(eof)==0) {
        local raw = subinstr(`"`macval(line)'"', char(13), "", .)
        local p = strpos(`"`macval(raw)'"', "Remote name")
        if (`p'>0) {
            local st = `p' + strlen("Remote name")
            local remote = trim(substr(`"`macval(raw)'"', `st', strlen(`"`macval(raw)'"')))
        }
        file read `fh' line
    }
    file close `fh'
    return local remote `"`macval(remote)'"'
end
