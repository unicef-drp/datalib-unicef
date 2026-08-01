*******************************************************
** datalib_index
* Joao Pedro Azevedo and Minh Cong Nguyen
*! v0.9.24
*******************************************************
* Walk a subtree RECURSIVELY and return it as a DATASET -- one row per file, and
* optionally one per folder.
*
* WHY THIS EXISTS SEPARATELY FROM datalib_explorer
*
* -datalib_explorer- answers "what is in THIS folder" and returns it in r(). That is the
* right shape for browsing and the wrong shape for work: reaching one file in
* Spain/1975 Vital Statistics/Working Datasets/Unzipped/datos partos75 takes five
* round trips, and at the end you have a display rather than something you can
* -tabulate-, -merge- or -export-. This command pays the walk once and hands back data.
*
* THE COST IS REAL, AND IT IS NOT THIS CODE'S FAULT
*
* Measured on <staging-tree>: 0.35 s per FOLDER, near-constant across subtrees
* of very different size (Spain a large branch / about nine minutes; a small branch in well under a minute; Brazil
* a mid-sized branch in about a minute). That is SMB round-trip latency per directory open, not overhead here:
* PowerShell's -Get-ChildItem -Recurse-, which enumerates in one process, took 538 s on
* the same subtree and found the same folders and thousands of files. There is no faster
* path from a single thread.
*
* So the whole staging tree -- every country -- is a 6-to-8 hour walk, which is why
* -maxnodes()- defaults to 400 (about two and a half minutes) and why the cap is announced rather
* than silent. For the whole archive, use the scheduled catalogue under <catalogue>:
* it pays the same per-folder cost but does it in parallel, off-hours, and stores
* checksums this command deliberately does not compute.
*
* SIZES ARE STILL OPT-IN, AND NOW MORE SO
*
* Stata cannot read a file's size without OPENING the file, ~1.4 s each over SMB. At
* thousands of files, Spain with -sizes- is an hour on top of the walk. Without it, r(bytes)
* and the bytes variable are missing rather than zero: 0 is a real size.
*
* RETURNED
*
* A dataset in memory (and optionally -saving()-), with:
*   relpath        path relative to root, forward-slashed, original casing
*   parent         relpath of the containing folder ("." at the top of the walk)
*   name           final component
*   ext            lowercased, no dot; "" for a folder, "none" for a file without one
*   depth          1 for the children of the walk's starting node
*   is_dir         1 folder, 0 file
*   bytes          size, or missing when -sizes- was not given
*   looks_grammar  1 when THIS row's name parses as CCC_YYYY_SURVEY
*
* Deliberately NOT split into country/survey columns. The whole reason this command and
* -explorer- exist is that these trees do not follow the grammar, so baking in
* "component 1 is a country" would reintroduce exactly the assumption they avoid. When
* the tree does follow it, -split relpath, parse("/")- is one line.
*
* r(n_files) r(n_dirs) r(nodes) r(bytes) r(truncated) r(seconds) r(root) r(path)
*******************************************************

capture program drop datalib_index
program define datalib_index, rclass

    version 15

    syntax [, ROOT(string) PATH(string) MAXDepth(integer 0) MAXNodes(integer 400) ///
              SIZES DIRS PATtern(string) SAVing(string) CLEAR replace ]

    *------------------------------------------------------------------
    * 1. resolve the root, exactly as explorer does: no _dl_islib gate,
    *    no case folding, no separator guessing.
    *------------------------------------------------------------------
    local r `"`root'"'
    if (`"`r'"'=="") local r `"${datalib}"'
    if (`"`r'"'=="") {
        di as err `"{p}index needs a tree to walk: pass {bf:root()}, or set {bf:${datalib}}.{p_end}"'
        exit 198
    }
    local r = subinstr(`"`r'"', "\", "/", .)
    while (substr(`"`r'"', -1, 1)=="/" & strlen(`"`r'"')>1 & substr(`"`r'"', -2, 1)!=":") {
        local r = substr(`"`r'"', 1, strlen(`"`r'"')-1)
    }

    local rel = subinstr(`"`path'"', "\", "/", .)
    while (substr(`"`rel'"', 1, 1)=="/") {
        local rel = substr(`"`rel'"', 2, .)
    }
    while (substr(`"`rel'"', -1, 1)=="/") {
        local rel = substr(`"`rel'"', 1, strlen(`"`rel'"')-1)
    }

    local start `"`r'"'
    if (`"`rel'"'!="") local start `"`r'/`rel'"'

    mata: st_local("ok", strofreal(direxists(st_local("start"))))
    if ("`ok'"!="1") {
        di as err `"{p}Not a directory: `start'{p_end}"'
        exit 601
    }

    if (`"`pattern'"'=="") local pattern "*"

    *------------------------------------------------------------------
    * 2. this command REPLACES the data in memory, so say so before doing it.
    *------------------------------------------------------------------
    if ("`clear'"=="") {
        capture describe, short
        if (_rc==0 & (r(N)>0 | r(k)>0)) {
            di as err "{p}data in memory would be lost. Save it, or add {bf:clear}.{p_end}"
            exit 4
        }
    }

    *------------------------------------------------------------------
    * 3. walk. A worklist, not recursion: Stata's nesting limit is finite and a
    *    193-country tree is not, and a queue makes the node cap exact.
    *
    *    The queue lives in MATA, not in a local. At 500 nodes a macro queue is
    *    comfortable, but a user raising maxnodes() to 20000 with long paths would
    *    silently exceed c(macrolen) and get a short answer with no error -- the
    *    silent-wrong-result class this package keeps having to fix.
    *------------------------------------------------------------------
    tempfile idx
    tempname ph
    postfile `ph' str400 relpath str400 parent str200 name str24 ext ///
        int depth byte is_dir double bytes byte looks_grammar using `"`idx'"'

    mata: _dl_iq  = J(1, 1, st_local("rel"))
    mata: _dl_iqd = J(1, 1, 0)

    local nodes     0
    local nfiles    0
    local ndirs     0
    local totbytes  0
    local truncated 0
    local left      1

    timer clear 99
    timer on 99

    di as txt _n "{hline 78}"
    di as txt "index: " as res cond(`"`rel'"'=="", `"`r'"', `"`rel'"')
    di as txt "  about 0.35 s per folder on a network share. Press {bf:Break} to stop."
    di as txt "{hline 78}"

    while (`left' > 0) {
        mata: st_local("cur", _dl_iq[1]); st_local("curd", strofreal(_dl_iqd[1]))
        mata: _dl_iq  = (rows(_dl_iq)  > 1 ? _dl_iq[|2 \ .|]  : J(0, 1, ""))
        mata: _dl_iqd = (rows(_dl_iqd) > 1 ? _dl_iqd[|2 \ .|] : J(0, 1, 0))

        local ++nodes
        if (`nodes' > `maxnodes') {
            local truncated 1
            local --nodes
            continue, break
        }

        local here `"`r'"'
        if (`"`cur'"'!="") local here `"`r'/`cur'"'

        local kids ""
        local fs ""
        mata: st_local("kids", invtokens((char(34) :+ dir(st_local("here"), "dirs", "*") :+ char(34))'))
        mata: st_local("fs", invtokens((char(34) :+ dir(st_local("here"), "files", st_local("pattern")) :+ char(34))'))

        * ---- files at this node ----
        foreach f of local fs {
            local ++nfiles
            local e = lower(substr(`"`f'"', strrpos(`"`f'"', ".") + 1, .))
            if (strpos(`"`f'"', ".") == 0) local e "none"
            local b = .
            if ("`sizes'"!="") {
                local b 0
                tempname fh
                capture file open `fh' using `"`here'/`f'"', read binary
                if (_rc == 0) {
                    capture file seek `fh' eof
                    capture file seek `fh' query
                    local b = r(loc)
                    capture file close `fh'
                }
                if ("`b'"=="" | "`b'"==".") local b 0
                local totbytes = `totbytes' + `b'
            }
            local g = 0
            if (ustrregexm(`"`f'"', "^[A-Za-z]{3}_[0-9]{4}_[A-Za-z0-9-]+")) local g 1
            local frel `"`f'"'
            if (`"`cur'"'!="") local frel `"`cur'/`f'"'
            post `ph' (`"`frel'"') (`"`=cond(`"`cur'"'=="", ".", `"`cur'"')'"') ///
                (`"`f'"') ("`e'") (`=`curd'+1') (0) (`b') (`g')
        }

        * ---- folders at this node: recorded if asked, queued either way ----
        foreach k of local kids {
            local ++ndirs
            local krel `"`k'"'
            if (`"`cur'"'!="") local krel `"`cur'/`k'"'
            if ("`dirs'"!="") {
                local g = 0
                if (ustrregexm(`"`k'"', "^[A-Za-z]{3}_[0-9]{4}_[A-Za-z0-9-]+")) local g 1
                post `ph' (`"`krel'"') (`"`=cond(`"`cur'"'=="", ".", `"`cur'"')'"') ///
                    (`"`k'"') ("") (`=`curd'+1') (1) (.) (`g')
            }
            * maxdepth(0) means no limit. The children of the starting node are depth 1.
            if (`maxdepth'==0 | `=`curd'+1' < `maxdepth') {
                mata: _dl_iq  = _dl_iq  \ st_local("krel")
                mata: _dl_iqd = _dl_iqd \ (`curd' + 1)
            }
        }

        mata: st_local("left", strofreal(rows(_dl_iq)))
        if (mod(`nodes', 25)==0) {
            di as txt "  " as res %6.0f `nodes' as txt " folders visited, " ///
                as res %7.0f `nfiles' as txt " files, " as res %6.0f `left' ///
                as txt " queued"
        }
    }

    postclose `ph'
    timer off 99
    quietly timer list 99
    local secs = r(t99)

    mata: mata drop _dl_iq _dl_iqd

    use `"`idx'"', clear
    label variable relpath       "path relative to root"
    label variable parent        "containing folder"
    label variable name          "final component"
    label variable ext           "extension, lowercased"
    label variable depth         "1 = child of the starting node"
    label variable is_dir        "1 folder, 0 file"
    label variable bytes         "size in bytes (missing = not measured)"
    label variable looks_grammar "name parses as CCC_YYYY_SURVEY"

    *------------------------------------------------------------------
    * 4. report. The cap is ANNOUNCED: a short answer that looks complete is the
    *    failure mode this package has already been bitten by.
    *------------------------------------------------------------------
    di as txt "{hline 78}"
    di as txt "  " as res %6.0f `nodes' as txt " folders walked, " ///
        as res %7.0f `nfiles' as txt " files indexed, " ///
        as res %6.1f `secs' as txt " s"
    if (`truncated') {
        * Be exact about what the remainder number IS. The walk is breadth-first, so the
        * queue holds only the frontier already discovered -- the children of folders
        * never visited were never enumerated, so the true number of unindexed folders is
        * larger and unknowable without finishing the walk. Reporting the queue length as
        * though it were the remainder understates it badly: this subtree has 8 folders,
        * a cap of 3 leaves 5 unwalked, and the queue said 2.
        local est = `maxnodes' * 4 * 0.35
        local unit "seconds"
        if (`est' >= 90) {
            local est = `est' / 60
            local unit "minutes"
        }
        di as err "  STOPPED at the {bf:maxnodes} cap of `maxnodes' folders."
        di as txt "                   At least " as res "`left'" as txt " more folder(s) were already queued, and"
        di as txt "                   the children of unvisited folders were never listed -- so the"
        di as txt "                   true remainder is larger than that, and unknown until the walk"
        di as txt "                   finishes. This dataset is a PREFIX of the subtree."
        di as txt "                   Raise it with {bf:maxnodes(`=`maxnodes'*4')}: at the measured 0.35 s"
        di as txt "                   per folder that is about " as res %4.0f `est' as txt " `unit'."
    }
    if ("`sizes'"=="") {
        di as txt "  bytes not measured -- add {bf:sizes} (about 1.4 s per file over SMB)."
    }
    di as txt "{hline 78}"

    if (`"`saving'"'!="") {
        save `"`saving'"', `replace'
        di as txt "  saved to " as res `"`saving'"'
    }

    return local root        `"`r'"'
    return local path        `"`rel'"'
    return scalar nodes     = `nodes'
    return scalar n_files   = `nfiles'
    return scalar n_dirs    = `ndirs'
    return scalar bytes     = cond("`sizes'"=="", -1, `totbytes')
    return scalar truncated = `truncated'
    return scalar seconds   = `secs'
end
