*******************************************************
** uninstall_datalib.do
* Remove every -datalib- registration from this machine.
*
* WHY THIS EXISTS, i.e. why -ado uninstall datalib- does not work
*
*   . sscpax datalib, action(uninstall)
*   criterion matches more than one package
*
* -net install ... replace- APPENDS a stata.trk entry every time, so a machine
* that has reinstalled during development carries many entries under one name --
* 27 on the machine this was written for. Every by-name form (-ado uninstall-,
* -ssc uninstall-, -sscpax , action(uninstall)-) refuses, because the name is
* genuinely ambiguous. Only the bracketed index is unambiguous, and no name-based
* wrapper can express it: they all take a -namelist-, and "[1497]" is not a name.
*
* INDICES ARE DERIVED AT RUN TIME, EVERY TIME. The first version of this script
* hardcoded them, and that is how it destroyed an unrelated package: -ado dir-'s
* [n] is the ordinal position of the entry in stata.trk, so ANY uninstall shifts
* every later number down. A stale list re-run after a partial sweep landed [n]
* on whatever had slid into that position -- it deleted the files of -sscpax-.
* So this script re-reads stata.trk before EACH removal and always takes the
* highest datalib index; nothing else can be hit, and a partial run is always
* safe to re-run.
*
* ONE SESSION AT A TIME. Every uninstall rewrites stata.trk through a rename
* dance (stata.trk -> backup.trk, next.trk -> stata.trk). A second Stata session
* touching the trk at the same moment makes the rename fail with rc=699/603,
* which aborts the sweep partway. Close other Stata sessions, or leave them
* idle, before running with EXECUTE=1.
*
* Only the removal that last claims a file deletes it: Stata keeps a file on
* disk while any remaining entry still lists it. So most removals only clear
* their stata.trk entry, and the files disappear as the last claimant goes.
*
* KNOWN HAZARD kept on record: this machine carried a Dec-2024 registration of
* an ancestor of this package (repo github.com/unicef-drp/datalib -- this
* repository under its former name). Its 14 files were all also owned by the
* current package, so removing THAT entry alone, with the current package
* installed, would have deleted 14 live files. Highest-index-first order is what
* makes such overlaps safe: by the time an old entry is reached, the newer
* claimants are already gone.
*
* NOT REMOVED by this script, by design:
*   - PLUS/datalib_netsource.txt   (written by -datalib , update install-;
*     not in datalib.pkg, so no uninstall reaches it -- erased explicitly below)
*   - the datalib block in profile.do, and the datalib: key in user_config.yml
*   - the ~21 user-written packages profile_datalib.do installs (wbopendata,
*     estout, filelist, ...): independent packages shared with other repos.
*******************************************************

local EXECUTE 0     // <-- set to 1 to actually uninstall

*------------------------------------------------------------------------------*
* Scan stata.trk: how many datalib entries, and where is the highest one?
* The [n] shown by -ado dir- is the 1-based ordinal of the "N <pkg>.pkg" line.
*------------------------------------------------------------------------------*
capture program drop _udl_scan
program define _udl_scan, rclass
    quietly {
        local trk `"`c(sysdir_plus)'stata.trk"'
        local n 0
        local ndl 0
        local hi 0
        capture confirm file `"`trk'"'
        if (_rc==0) {
            tempname fh
            file open `fh' using `"`trk'"', read text
            file read `fh' line
            while (r(eof)==0) {
                local l = trim(`"`macval(line)'"')
                if (substr(`"`l'"', 1, 2)=="N ") & (substr(`"`l'"', -4, .)==".pkg") {
                    local ++n
                    if (`"`l'"'=="N datalib.pkg") {
                        local ++ndl
                        local hi `n'
                    }
                }
                file read `fh' line
            }
            file close `fh'
        }
        return scalar n   = `n'
        return scalar ndl = `ndl'
        return scalar hi  = `hi'
    }
end

di as res _n "{hline 70}"
di as res "datalib registrations currently on this machine"
di as res "{hline 70}"
capture noisily ado dir datalib
_udl_scan
local ndl = r(ndl)
di as txt _n "stata.trk: " as res r(n) as txt " package entries, " ///
    as res `ndl' as txt " named datalib (highest at [" as res r(hi) as txt "])"

if (`ndl'==0) {
    di as res _n "Nothing to do - no datalib registrations."
    exit 0
}

if (!`EXECUTE') {
    di as err _n "PLAN ONLY - nothing was removed."
    di as txt "This run would remove `ndl' entries, re-deriving the index before each."
    di as txt "Set EXECUTE to 1 at the top of this file and run it again --"
    di as txt "in ONE Stata session only (see the header)."
    exit 0
}

*------------------------------------------------------------------------------*
* Remove: re-scan, take the highest datalib index, uninstall, repeat.
* A lock failure (another session holding stata.trk) STOPS the sweep -- rc 699
* and 603 here are not benign, and continuing past them is how a partial state
* gets worse. The sweep is safe to re-run after the other session closes.
*------------------------------------------------------------------------------*
discard
local guard = `ndl' + 5      // hard stop: never loop past what the scan counted
local done 0
while (`done' < `guard') {
    _udl_scan
    if (r(ndl)==0) continue, break
    local hi = r(hi)
    di as res _n "{hline 70}"
    di as txt "removing [" as res "`hi'" as txt "] -- " as txt "(" as res r(ndl) as txt " left)"
    capture noisily ado dir [`hi']
    capture noisily ado uninstall [`hi']
    if (_rc==699) | (_rc==603) {
        di as err _n "STOPPED: stata.trk is locked (rc=" _rc ")."
        di as err "Another Stata session is using it. Close or idle that session"
        di as err "and re-run this script -- a partial sweep is safe to resume."
        exit _rc
    }
    if (_rc) {
        di as err _n "STOPPED: ado uninstall [`hi'] failed with rc=" _rc "."
        di as err "Inspect before re-running: ado dir [`hi']"
        exit _rc
    }
    local ++done
}

*------------------------------------------------------------------------------*
* Verify, and clean up what -ado uninstall- cannot reach.
*------------------------------------------------------------------------------*
di as res _n "{hline 70}"
di as res "After"
di as res "{hline 70}"
capture noisily ado dir datalib
capture which datalib
di as txt "which datalib -> rc " _rc "   (111 = fully removed)"

local mem `"`c(sysdir_plus)'datalib_netsource.txt"'
capture confirm file `"`mem'"'
if (_rc==0) {
    capture erase `"`mem'"'
    if (_rc==0) di as txt "erased `mem'"
    else        di as err "could not erase `mem' (rc=" _rc ") - remove it by hand"
}

di as txt _n "Check by hand, not removed by design:"
di as txt "  - the datalib block in your profile.do"
di as txt "  - the datalib: key in user_config.yml"
di as txt "  - globals \$datalib, \$datalib_checked, \$datalib_netsource (this session)"
di as txt _n "Reinstall at any time:"
di as txt `"  net install datalib, from("Z:/_pkg/datalib/stata") replace"'

capture program drop _udl_scan
