*******************************************************
** _dl_update
* Joao Pedro Azevedo and Minh Cong Nguyen
*! Version: 0.9.23      Date: <2026-07-29>
*******************************************************
* Compare the INSTALLED datalib against the net site it came from, and
* optionally reinstall from there. Backs -datalib , update-.
*
* WHY THIS IS NOT JUST -adoupdate-
* Stata's own adoupdate would do the reinstall, but it answers a yes/no question
* and it will happily move you BACKWARDS: it reinstalls whatever the recorded
* source now holds. That has already caused a real regression here -- a stale
* v0.1 snapshot on the net site silently downgraded a v0.8 install, which
* reintroduced the -recode windex5 8=.- data mutation that contract v1 forbids.
* So this command:
*   - reports THREE coordinates (installed / source / direction), because
*     "up to date" is ambiguous exactly when the source is the stale one;
*   - refuses to go backwards unless -force- is given;
*   - never writes anything unless -install- is given.
*
* THE ADO CACHE. Stata holds ado-programs in memory once loaded, so after
* -install- this session is still running the PREVIOUS code until -discard- (or a
* restart). The post-install message says so, because omitting it made a working
* install look like a failed one: the operator re-ran the check in the same
* session, got the old code, and saw no change.
*
* WHERE "THE INSTALLATION HOME" COMES FROM, in precedence order:
*   1. netsource()                 -- this call only
*   2. ${datalib_netsource}        -- set once per session, e.g. in profile.do
*   3. PLUS/datalib_netsource.txt  -- what THIS command remembered the last time
*      it installed. See "REMEMBERING THE SOURCE" below.
*   4. the source recorded by -net install- in PLUS/stata.trk (the S line):
*      Stata's own record of where the package came from
*   5. ${zDrive}_pkg/datalib/stata -- the CSO LAN net site on a mapped drive
*   6. Z:/_pkg/datalib/stata       -- last resort
*
* REMEMBERING THE SOURCE, and why slots 2 and 3 are not the same thing.
*
* Before 0.9.17 the only memory was stata.trk, which -net install- appends to and
* nothing else can write. That produced a dead end: a machine whose recorded
* source was a retired root got the "the net site moved" notice on every single
* check, because the notice said "installing from here updates the record" while
* being printed under a status -- current -- that gives nobody a reason to
* install. The advice was unreachable, so the one-off was permanent. Reported
* from a live session that saw it twice in a row at 0.9.16 = 0.9.16.
*
* So slot 3: a small file this command writes on every successful install and
* reads on every check. It is deliberately NOT implemented by persisting
* ${datalib_netsource} into profile.do, even though that would be less code and
* the slot already exists. A global is treated here as an INSTRUCTION and is
* never redirected (see 2b) -- correct for something a caller typed, wrong for
* something we wrote down ourselves. Persisting it would make the next root move
* unmigratable, trading today's dead end for a worse one. A remembered value is a
* RECORD, so it stays redirectable and a future move still completes by itself.
*
* It lives in PLUS beside the package rather than in PERSONAL because it
* describes THAT install: wipe the install and the claim about it should go too.
* Three lines as of 0.9.18 -- source, version, trk entry count -- read leniently,
* so a 0.9.17-era one-line file still supplies the source.
*
* THE TRK IS NOT AUTHORITATIVE for "what is installed", which is why the version
* is in that file at all. -net install ... replace- appends a trk entry only when
* it copies something; when it judges the files already current it prints "all
* files already exist and are up to date" and writes nothing. Verified by probe:
* two consecutive installs into one PLUS leave a single entry. So the trk version
* can lag the files on disk -- observed on a real machine carrying 0.9.17 files
* under a 0.9.16 record -- and -update- then reports an update that is permanently
* available and that installing cannot clear, because there is nothing to copy.
*
* Which record wins is decided by RECENCY, not by version order. "Prefer the
* higher version" would hide a deliberate downgrade performed with plain
* -net install-, and not hiding downgrades is the reason this command exists. The
* trk is append-only, so its entry count answers "has anything installed since we
* wrote our stamp?" in both directions. A disagreement is always printed.
*
* The GitHub raw URL is deliberately NOT a default: the repository is private,
* so an anonymous net install answers 404, and the workaround would be putting a
* token into Stata. Pass netsource() explicitly if that ever changes.
*
* Returns:
*   r(installed)      version recorded for the installed package, or "unknown"
*   r(source)         the net site consulted
*   r(source_version) version the net site advertises, or "" if unreadable
*   r(recorded_source) the S line from stata.trk, or "" if none
*   r(recorded_version) the version stata.trk records, or "" if none
*   r(remembered_source) source from PLUS/datalib_netsource.txt, or ""
*   r(remembered_version) version from that file, or "" if not recorded there
*   r(version_from)   which record r(installed) came from: trk | stamp
*   r(running_from)   where the adopath resolves datalib.ado, or "" if nowhere
*   r(shadowed)       1 when that is not the installed copy, so the versions
*                     reported describe files this session will not run
*   r(status)         current | newer_available | source_behind | unknown
*   r(installed_from) the adopath directory the package is installed into
*   r(migrated)       1 when the resolved source was a legacy root and this
*                     call redirected to the current one (transition only)
*******************************************************

*------------------------------------------------------------------------------*
* Scan PLUS/stata.trk for the live datalib entry.
*
* Factored out of _dl_update in 0.9.18 because it has to run TWICE: once to
* report, and again after an install to find out whether -net install- actually
* recorded anything. It does not always: see "THE TRK IS NOT AUTHORITATIVE".
*
* Returns r(version), r(source), r(entries). r(entries) is the number of datalib
* entries in the file, used purely as a recency signal -- the file is append-only,
* so a larger count means a later install event, whatever version it carried.
*------------------------------------------------------------------------------*
capture program drop _dl_upd_trk
program define _dl_upd_trk, rclass
    args trk
    quietly {
        local instver ""
        local trksrc  ""
        local entries 0
        capture confirm file `"`trk'"'
        if (_rc==0) {
            tempname fh
            file open `fh' using `"`trk'"', read text
            local lastS   ""
            local pending 0
            local curS    ""
            local curV    ""
            file read `fh' line
            while (r(eof)==0) {
                local l = trim(`"`macval(line)'"')
                if (substr(`"`l'"', 1, 2)=="S ") {
                    local lastS = trim(substr(`"`l'"', 3, .))
                    local pending 0
                }
                else if (`"`l'"'=="N datalib.pkg") {
                    local ++entries
                    local pending 1
                    local curS `"`lastS'"'
                    local curV ""
                }
                else if (`pending'==1) {
                    if (substr(`"`l'"', 1, 10)=="d Version ") {
                        local curV = trim(substr(`"`l'"', 11, .))
                    }
                    else if (substr(`"`l'"', 1, 2)=="f ") {
                        * the file list starts: this entry's header is complete.
                        * Keep overwriting so the LAST entry wins.
                        local instver `"`curV'"'
                        local trksrc  `"`curS'"'
                        local pending 0
                    }
                }
                file read `fh' line
            }
            file close `fh'
        }
        return local version `"`instver'"'
        return local source  `"`=subinstr(`"`trksrc'"', "\", "/", .)'"'
        return scalar entries = `entries'
    }
end

capture program drop _dl_update
program define _dl_update, rclass

    version 15

    syntax [, NETsource(string) INSTALL FORCE RUNNING(string) ]

    quietly {
        *----------------------------------------------------------------------
        * 1. what is installed, and what source did it come from?
        *
        * The version is read from PLUS/stata.trk rather than from the .ado's
        * -*!- stamp, because this repo bumps only the files whose contents
        * changed: datalib.ado still stamps 0.9.3 in a 0.9.9 package, so the
        * stamp is not the package version. net install APPENDS a new trk entry
        * on every -replace- (17 datalib entries on the machine this was written
        * on), so the LAST entry is the live one.
        *----------------------------------------------------------------------
        local plus `"`c(sysdir_plus)'"'
        local trk  `"`plus'stata.trk"'

        *----------------------------------------------------------------------
        * 1a. WHICH COPY WOULD THIS SESSION LOAD?
        *
        * PLUS is not a choice: -net install- has no destination option and always
        * writes there, so there is no installation home to pick. What is worth
        * asking -- and what this command assumed away until 0.9.18 -- is whether
        * the adopath resolves datalib.ado to that copy at all. If something
        * earlier on the path shadows it (a clone added with -adopath +-, a copy in
        * PERSONAL), then every version reported below describes a package that
        * will not run, and the report is about the wrong files.
        *
        * -findfile- rather than -whereis-: whereis locates external executables
        * from a registry the operator maintains, not ado-files on the adopath.
        * This is also all -which- does, minus the printing.
        *
        * It reports where the ADOPATH resolves. A program already loaded into
        * memory by -run- (as the conformance harness does) is invisible to any of
        * these, so this is deliberately not claimed to detect that.
        *----------------------------------------------------------------------
        local runfrom ""
        capture findfile datalib.ado
        if (_rc==0) local runfrom = subinstr(`"`r(fn)'"', "\", "/", .)
        local shadowed 0
        if (`"`runfrom'"'!="") {
            local plusl = lower(subinstr(`"`plus'"', "\", "/", .))
            if (substr(`"`plusl'"', -1, 1)!="/") local plusl `"`plusl'/"'
            if (strpos(lower(`"`runfrom'"'), `"`plusl'"')!=1) local shadowed 1
        }

        _dl_upd_trk `"`trk'"'
        local trkver  `"`r(version)'"'
        local trksrc  `"`r(source)'"'
        local trkn    = r(entries)

        *----------------------------------------------------------------------
        * 1b. what did WE remember last time? (see the header)
        *
        * Up to three lines: the source, the version installed, and the trk entry
        * count at that moment. Read defensively -- a truncated, hand-edited or
        * 0.9.17-era one-line file must degrade to "less known" and let the chain
        * continue, never abort a read-only status check.
        *----------------------------------------------------------------------
        local memfile `"`plus'datalib_netsource.txt"'
        local memsrc  ""
        local memver  ""
        local memn    = -1
        capture confirm file `"`memfile'"'
        if (_rc==0) {
            tempname mh
            capture file open `mh' using `"`memfile'"', read text
            if (_rc==0) {
                file read `mh' line
                if (r(eof)==0) local memsrc = trim(`"`macval(line)'"')
                file read `mh' line
                if (r(eof)==0) local memver = trim(`"`macval(line)'"')
                file read `mh' line
                if (r(eof)==0) {
                    local raw = trim(`"`macval(line)'"')
                    capture confirm number `raw'
                    if (_rc==0) local memn = real("`raw'")
                }
                capture file close `mh'
            }
            local memsrc = subinstr(`"`memsrc'"', "\", "/", .)
        }

        *----------------------------------------------------------------------
        * 1c. THE TRK IS NOT AUTHORITATIVE for "what is installed".
        *
        * -net install ... replace- appends a trk entry only when it copies
        * something. When it decides the files are already current it prints "all
        * files already exist and are up to date" and writes NOTHING -- verified by
        * probe: two consecutive installs into the same PLUS leave one entry.
        *
        * So the trk's version can lag the files on disk, and then -update- reports
        * an update that is permanently available and that installing cannot clear,
        * because there is nothing left to copy. Observed on a real machine holding
        * 0.9.17 files under a 0.9.16 trk record.
        *
        * Hence our own stamp, and a rule for which record wins. NOT "the higher
        * version": a deliberate downgrade by plain -net install- would then be
        * hidden, which is the exact failure this command exists to prevent. The
        * trk is append-only, so its ENTRY COUNT is a recency signal that works in
        * both directions -- if it has grown since we wrote our stamp, some later
        * install happened by other means and the trk is the newer fact.
        *----------------------------------------------------------------------
        local instver `"`trkver'"'
        local vsrc    "trk"
        if (`"`memver'"'!="") & (`memn'>=0) & (`trkn'<=`memn') {
            local instver `"`memver'"'
            local vsrc    "stamp"
        }
        if (`"`instver'"'=="") local instver "unknown"
        local skew 0
        if ("`vsrc'"=="stamp") & (`"`trkver'"'!="") & (`"`trkver'"'!=`"`memver'"') local skew 1

        *----------------------------------------------------------------------
        * 2. resolve the net site
        *----------------------------------------------------------------------
        local src `"`netsource'"'
        if (`"`src'"'=="") local src `"${datalib_netsource}"'
        if (`"`src'"'=="") local src `"`memsrc'"'
        if (`"`src'"'=="") local src `"`trksrc'"'
        if (`"`src'"'=="") & (`"${zDrive}"'!="") {
            local zd = subinstr(`"${zDrive}"', "\", "/", .)
            if (substr(`"`zd'"', -1, 1)!="/") local zd `"`zd'/"'
            local src `"`zd'_pkg/datalib/stata"'
        }
        if (`"`src'"'=="") local src "Z:/_pkg/datalib/stata"
        local src = subinstr(`"`src'"', "\", "/", .)
        while (substr(`"`src'"', -1, 1)=="/") & (strlen(`"`src'"')>1) {
            local src = substr(`"`src'"', 1, strlen(`"`src'"')-1)
        }

        *----------------------------------------------------------------------
        * 2b. THE FORWARDING RULE. Do not delete this as a transition leftover.
        *
        * The net site moved twice: Z:/_statapkg, then Z:/_pkg/stata, now
        * Z:/_pkg/datalib/stata. The source RECORDED by net install outranks the
        * built-in default -- deliberately, so an existing install keeps working --
        * but that alone means nobody ever migrates: the recorded value wins forever
        * and nothing tells the operator a new root exists. So when the recorded
        * source is a retired root AND the canonical root is readable, prefer the
        * canonical one and SAY SO. Installing from here rewrites the trk record, so
        * a single -datalib , update install- completes the move.
        *
        * AS OF 0.9.19 THIS IS LOAD-BEARING, NOT COURTESY. Both retired roots have
        * been REMOVED from the share -- the decision is that every datalib
        * installation package comes from Z:/_pkg/datalib and nowhere else. Until
        * 0.9.19 they were kept in step so that an un-migrated machine could still
        * install from the path it remembered; that fallback is gone. This redirect
        * is now the only thing standing between such a machine and a hard failure,
        * so it must outlive the roots it names. It does not require them to exist:
        * it tests the CANONICAL toc, not the retired one.
        *
        * Only the recorded (or remembered) source is redirected. An explicit
        * netsource() or ${datalib_netsource} is never overridden: if a caller names
        * a root, that is an instruction, not a legacy artefact -- even now that the
        * instruction may name somewhere that no longer exists, which the "no
        * stata.toc at that path" branch reports plainly.
        *----------------------------------------------------------------------
        local migrated 0
        if (`"`netsource'"'=="") & (`"${datalib_netsource}"'=="") {
            * Retired roots, oldest first. A LIST rather than a hardcoded string
            * because the site has moved more than once. Both are listed even
            * though only Z:/_statapkg ever had a real installed base: the middle
            * one existed long enough to be recorded on some machine, and the cost
            * of listing it is one word against a hard failure.
            local retired "z:/_statapkg z:/_pkg/stata"
            local canon   "Z:/_pkg/datalib/stata"
            local here = lower(`"`src'"')
            if (`:list here in retired') {
                capture confirm file `"`canon'/stata.toc"'
                if (_rc==0) {
                    local oldsrc `"`src'"'
                    local src `"`canon'"'
                    local migrated 1
                }
            }
        }

        *----------------------------------------------------------------------
        * 3. what version does the net site advertise?
        * stata.toc is the net-site index and carries "d Version X | date".
        *----------------------------------------------------------------------
        local srcver  ""
        local srcdate ""
        capture confirm file `"`src'/stata.toc"'
        local tocok = (_rc==0)
        if (`tocok') {
            tempname th
            file open `th' using `"`src'/stata.toc"', read text
            file read `th' line
            while (r(eof)==0) {
                local l = trim(`"`macval(line)'"')
                if (substr(`"`l'"', 1, 10)=="d Version ") {
                    local raw = trim(substr(`"`l'"', 11, .))
                    local raw = subinstr(`"`raw'"', "|", " ", .)
                    local srcver  = trim(word(`"`raw'"', 1))
                    local srcdate = trim(word(`"`raw'"', 2))
                }
                file read `th' line
            }
            file close `th'
        }

        *----------------------------------------------------------------------
        * 4. compare, semantically. Text order is wrong for versions: "0.9.10"
        *    sorts BELOW "0.9.9" as a string, which is exactly the comparison
        *    this command exists to get right.
        *----------------------------------------------------------------------
        local status "unknown"
        if (`"`instver'"'!="unknown") & (`"`srcver'"'!="") {
            local inum 0
            local snum 0
            forvalues k = 1/3 {
                local iw = real(word(subinstr(`"`instver'"', ".", " ", .), `k'))
                local sw = real(word(subinstr(`"`srcver'"',  ".", " ", .), `k'))
                if (`iw'>=.) local iw 0
                if (`sw'>=.) local sw 0
                local inum = `inum'*1000 + `iw'
                local snum = `snum'*1000 + `sw'
            }
            if (`snum' > `inum')      local status "newer_available"
            else if (`snum' < `inum') local status "source_behind"
            else                      local status "current"
        }

        *----------------------------------------------------------------------
        * 4c. is this SESSION running what is on disk?
        *
        * Distinct from `shadowed', which is about the adopath resolving datalib
        * somewhere other than PLUS. This is about time: the right file, loaded
        * before it was replaced. Stata compiles an ado into memory on first use and
        * -net install- does not invalidate that, so the two diverge silently.
        *
        * running() is the caller's OWN compiled-in version. Empty means the front
        * door predates this check or _dl_update was called directly, and then there
        * is nothing to compare -- report nothing rather than guess.
        *----------------------------------------------------------------------
        local stale 0
        if (`"`running'"'!="") & (`"`instver'"'!="") & (`"`instver'"'!="unknown") {
            local stale = (`"`running'"'!=`"`instver'"')
        }

        *----------------------------------------------------------------------
        * 5. report
        *----------------------------------------------------------------------
        noi di as txt _n "{hline 68}"
        noi di as txt "datalib update"
        noi di as txt "{hline 68}"
        noi di as txt "  installed      : " as res `"`instver'"' ///
                      as txt "   (in `plus')" ///
                      as txt cond(`skew', "  [from this command's own record]", "")
        if (`stale') {
            * One display class for the whole line, on purpose. -quietly- suppresses
            * as-txt and as-res output but lets as-err through, so a line that MIXED
            * them rendered as "running        :    (in memory - NOT what is on disk)"
            * under -quietly datalib, update- -- label and warning intact, version
            * silently dropped. A half-rendered warning is worse than none: it names a
            * problem and withholds the number the reader needs. All as-err means the
            * line either appears whole or not at all.
            noi di as err "  running        : `running'   (in memory - NOT what is on disk)"
            noi di as txt "                   Stata compiled datalib into memory before"
            noi di as txt "                   the files were replaced, and keeps using that"
            noi di as txt "                   copy. Run {bf:discard} -- until then the"
            noi di as txt "                   version above is the one you are running."
        }
        if (`shadowed') {
            noi di as err "  running code   : " `"`runfrom'"'
            noi di as txt "                   That is NOT the installed copy. The adopath"
            noi di as txt "                   resolves datalib there first, so the versions"
            noi di as txt "                   here describe files this session will not run."
            noi di as txt "                   Normal when working from a clone; otherwise check"
            noi di as txt "                   {bf:adopath} and {bf:which datalib}."
        }
        * Never override Stata's record silently. Elsewhere in this package a
        * substitution the operator cannot see afterwards is treated as a defect,
        * and that applies to us too.
        if (`skew') {
            noi di as txt "                   {bf:net install} last recorded " ///
                          as res `"`trkver'"' as txt ", but it only writes that"
            noi di as txt "                   record when it copies something, and it copies"
            noi di as txt "                   nothing when the files are already current. The"
            noi di as txt "                   version above is what this command last installed."
        }
        noi di as txt "  net site       : " as res `"`src'"'
        if (!`tocok') {
            noi di as err "  site version   : NO stata.toc at that path - cannot check for updates."
            noi di as txt "                   Pass {bf:netsource()}, or set the global"
            noi di as txt "                   {bf:datalib_netsource} to a readable net site."
        }
        else {
            noi di as txt "  site version   : " as res `"`srcver'"' ///
                          as txt cond(`"`srcdate'"'!="", `"   (`srcdate')"', "")
        }
        if (`migrated') {
            noi di as txt "  installed from : " as res `"`oldsrc'"' ///
                          as txt "  (legacy root)"
            noi di as txt "                   The net site moved. Checking the current"
            noi di as txt "                   root instead."
        }
        else if (`"`trksrc'"'!="") & (`"`trksrc'"'!=`"`src'"') & (`"`memsrc'"'=="") {
            noi di as txt "  installed from : " as res `"`trksrc'"' ///
                          as txt "  (differs from the site being checked)"
        }
        if (`"`memsrc'"'!="") {
            noi di as txt "  remembered     : " as res `"`memsrc'"' ///
                          as txt cond(`migrated', "  (being migrated)", "")
        }

        if ("`status'"=="newer_available") {
            noi di as res _n "  A newer datalib is available on the net site."
            if ("`install'"=="") {
                noi di as txt `"  {stata "datalib, update install":Install `srcver' now}"' ///
                              `" or run {bf:datalib, update install}."'
            }
        }
        else if ("`status'"=="current") {
            noi di as txt _n "  Up to date - installed and net site are both `instver'."
            * "Up to date" is a claim about the two RECORDS, and a reader takes it as
            * a claim about their session. Say which one it is when they differ.
            if (`stale') {
                noi di as txt "  On disk, that is. This session is still running " ///
                              as res `"`running'"' as txt " - run {bf:discard}."
            }
        }
        else if ("`status'"=="source_behind") {
            noi di as err _n "  The net site is OLDER than what you have installed."
            noi di as txt "  Installing would DOWNGRADE you `instver' -> `srcver', so it is refused."
            noi di as txt "  This is not hypothetical: a stale snapshot on this net site once"
            noi di as txt "  downgraded a working install and reinstated a data-mutation bug."
            noi di as txt "  Override with {bf:datalib, update install force} only if you mean it."
        }
        else {
            noi di as txt _n "  Cannot compare: " ///
                cond(`"`instver'"'=="unknown", "no version recorded for the installed package. ", "") ///
                cond(`"`srcver'"'=="",         "the net site advertises no version. ", "")
            noi di as txt "  Reinstall once with {bf:datalib, update install} to record one."
        }

        * The re-point offer. It must NOT live inside the newer_available branch,
        * which is where it used to be implied. A redirected machine reads as
        * ALREADY current -- the version it is compared against is the canonical
        * root's, which it is being forwarded to -- so the status that most needs
        * this offer is the one that gives no other reason to install. Printing
        * "installing updates the record" under -current- without offering the
        * install is what made the notice permanent before 0.9.17.
        *
        * Re-pointing matters more since 0.9.19 removed the retired roots: until the
        * record is rewritten, every call depends on this redirect firing, and any
        * tool that reads stata.trk directly still sees a path that is now absent.
        if (`migrated') & ("`install'"=="") {
            noi di as txt _n "  This machine still records the old root, and only a" ///
                          _n "  reinstall can rewrite that record -- so the notice above" ///
                          _n "  repeats until you re-point it. Same `instver', same files:"
            noi di as txt `"    {stata "datalib, update install":Re-point to `src' now}"' ///
                          `" or run {bf:datalib, update install}."'
        }
        noi di as txt "{hline 68}"

        *----------------------------------------------------------------------
        * 6. install, only when asked
        *----------------------------------------------------------------------
        if ("`install'"!="") {
            if ("`status'"=="source_behind") & ("`force'"=="") {
                noi di as err "Refusing to downgrade `instver' -> `srcver'. Add {bf:force} to override."
                exit 198
            }
            if (!`tocok') {
                noi di as err "Cannot install: no stata.toc at `src'."
                exit 601
            }
            noi di as txt _n "Installing datalib from `src' ..."
            noi net install datalib, from(`"`src'"') replace

            * Did -net install- record anything? It appends a trk entry only when
            * it copies. A no-op leaves the count unchanged, and that is precisely
            * when our own stamp has to carry the version instead.
            _dl_upd_trk `"`trk'"'
            local newn = r(entries)
            local noop = (`newn'<=`trkn')

            * Remember it. AFTER the install, so a failed install leaves the old
            * record intact rather than pointing at a root that did not work.
            * -replace- on file open: this is current state, not a history.
            *
            * The version written is the SITE's, including after a no-op. That is
            * justified rather than assumed: a no-op is Stata reporting that the
            * installed files already match this net site's package, and if they
            * match the site then the installed version IS the site version. The
            * count is stored so a later install by other means can outrank us.
            tempname mw
            capture file close `mw'
            capture file open `mw' using `"`memfile'"', write text replace
            if (_rc==0) {
                file write `mw' `"`src'"' _n
                file write `mw' `"`srcver'"' _n
                file write `mw' `"`newn'"' _n
                capture file close `mw'
                local memsrc `"`src'"'
                local memver `"`srcver'"'
            }
            else {
                * PLUS not writable (locked-down install, read-only share). The
                * install itself succeeded, so say what was lost and carry on --
                * stata.trk still records the source, which is the pre-0.9.17
                * behaviour, not a regression.
                noi di as txt "  (could not write `memfile' -- the source and version" ///
                              _n "   were not remembered; stata.trk still records them.)"
            }

            if (`noop') {
                * Do not say "Installed." when nothing was copied: that reads as a
                * silent success and leaves the operator unable to tell this apart
                * from a real install that failed to take effect.
                noi di as res _n "Already current - nothing was copied."
                noi di as txt    "  Stata reports the installed files already match `src',"
                noi di as txt    "  so `srcver' is what you have. It wrote no new stata.trk"
                noi di as txt    "  record (it only writes one when it copies), which is why"
                noi di as txt    "  the version was recorded here instead."
                noi di as txt _n "  No " as res "discard" as txt " needed: nothing on disk changed."
            }
            else {
                * Stata CACHES ado-programs in memory. net install has replaced the
                * files on disk, but this session keeps running the copies it
                * already loaded -- so a follow-up -datalib , update- here re-runs
                * the OLD code and appears not to have updated. Telling the operator
                * to "run it again to confirm" without saying this is actively
                * misleading: it is how a working install was reported as a failure.
                noi di as res _n "Installed. One more step in THIS session:"
                noi di as txt    "  Stata still has the previous copies loaded in memory,"
                noi di as txt    "  so run" as res " discard " as txt "before using datalib again --"
                noi di as txt    "  otherwise you keep running the old code."
                noi di as txt _n "  Restarting Stata is the more thorough option: it also"
                noi di as txt    "  drops Stata's cached copy of the net site's package"
                noi di as txt    "  description, which a second install in one session can"
                noi di as txt    "  otherwise reuse."
                noi di as txt _n "  Then: " as res "datalib, update" as txt " to confirm."
            }
        }

        return local installed        `"`instver'"'
        return local source           `"`src'"'
        return local source_version   `"`srcver'"'
        return local recorded_source  `"`trksrc'"'
        return local recorded_version `"`trkver'"'
        return local remembered_source `"`memsrc'"'
        return local remembered_version `"`memver'"'
        return local version_from     "`vsrc'"
        return local running_from     `"`runfrom'"'
        return local running          `"`running'"'
        return scalar stale           = `stale'
        return scalar shadowed        = `shadowed'
        return local status           "`status'"
        return scalar migrated        = `migrated'
        return local installed_from   `"`plus'"'
    }

end
