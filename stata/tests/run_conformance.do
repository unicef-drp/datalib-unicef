*==============================================================================*
*! run_conformance.do — Stata conformance harness for datalib contract v1
*
* Parts 1-2 run the cross-language golden cases in tests/cases_resolve.csv and
* tests/cases_load.csv against the committed fixture library: every implemented
* language (Stata, R, Python) must pass those cases unmodified.
*
* Parts 3-4 cover the Stata-only front-door surface — subcommand dispatch and
* the -find- library resolution documented in tests/DIVERGENCES.md. R and Python
* are NOT expected to reproduce them.
*
* Usage (from the repo root):   do "stata/tests/run_conformance.do"
* Exits with error 9 on any failure (CI/cscript-friendly).
*==============================================================================*

version 15
clear all
set more off

capture confirm file "stata/tests/run_conformance.do"
if _rc {
    di as err "Run this harness from the repository root."
    exit 601
}

* Load the wrappers from the working tree (installed users already have them)
foreach p in datalib_resolve datalib_catalog datalib_countries datalib_surveys ///
             datalib_vintages datalib_adaptations datalib_files datalib_load  ///
             datalib_create datalib_root datalib_config datalib_browse        ///
             datalib_map_drive {
    capture program drop `p'
    quietly run "stata/src/d/`p'.ado"
}
foreach p in _dlw _foldernav _dl_islib _dl_update {
    capture program drop `p'
    quietly run "stata/src/_/`p'.ado"
}
* Load these from the tree as well: a wrapper under test must not be paired
* with an older installed copy of a command it calls.
capture program drop getuserconfig
quietly run "stata/src/g/getuserconfig.ado"
capture program drop mapzdrive
quietly run "stata/src/m/mapzdrive.ado"
capture program drop _uc_init
quietly run "stata/src/_/_uc_init.ado"

local ROOT "`c(pwd)'/tests/fixtures/library"
local fails 0
local total 0
local skips 0

* Session state this harness mutates (datalib_root, set / datalib) — restored
* at the end. Captured BEFORE anything runs so the restore is meaningful.
local dl_saved  `"${datalib}"'
local zd_saved  `"${zDrive}"'
local pwd_saved `"`c(pwd)'"'
* getuserconfig publishes five globals; Part 5 reads real configs, so all five
* must be restored or an interactive run silently wipes the operator's paths.
local gh_saved  `"${githubFolder}"'
local tr_saved  `"${teamsRoot}"'
local zu_saved  `"${zDriveUNC}"'

*------------------------------------------------------------------------------*
* Part 1 — resolve cases
*------------------------------------------------------------------------------*
import delimited "tests/cases_resolve.csv", varnames(1) stringcols(_all) clear
local N = _N
forvalues i = 1/`N' {
    foreach v in case_id country year survey kind collection master_version ///
                 adaptation_version expect_error expect_vintage_folder {
        local `v' = `v'[`i']
        if ("``v''"==".") local `v' ""
    }
    local ++total
    capture datalib_resolve, country(`country') year(`year') survey(`survey') ///
        kind(`kind') collection(`collection') master_version(`master_version') ///
        adaptation_version(`adaptation_version') root("`ROOT'")
    local rc = _rc
    if ("`expect_error'"!="") {
        if (`rc'==0) {
            di as err "FAIL `case_id': expected an error, got success."
            local ++fails
        }
        else di as txt "pass `case_id' (error as expected, rc=`rc')"
    }
    else if (`rc'!=0) {
        di as err "FAIL `case_id': unexpected rc=`rc'."
        local ++fails
    }
    else if ("`r(vintage_folder)'" != "`expect_vintage_folder'") {
        di as err "FAIL `case_id': got `r(vintage_folder)', expected `expect_vintage_folder'."
        local ++fails
    }
    else di as txt "pass `case_id' -> `r(vintage_folder)'"
}

*------------------------------------------------------------------------------*
* Part 2 — load cases (content equivalence: row count + windex5==8 preservation)
*------------------------------------------------------------------------------*
import delimited "tests/cases_load.csv", varnames(1) stringcols(_all) clear
local N = _N
forvalues i = 1/`N' {
    foreach v in case_id country year survey kind collection modules ///
                 master_version nomerge expect_error expect_n expect_windex8 ///
                 expect_provenance {
        local `v' = `v'[`i']
        if ("``v''"==".") local `v' ""
    }
    * stash remaining rows: datalib_load clobbers memory
    tempfile stash
    quietly save `stash'

    local ++total
    capture datalib_load, country(`country') year(`year') survey(`survey') ///
        kind(`kind') collection(`collection') modules(`modules') ///
        master_version(`master_version') `nomerge' clear root("`ROOT'")
    local rc = _rc
    if ("`expect_error'"!="") {
        if (`rc'==0) {
            di as err "FAIL `case_id': expected an error, got success."
            local ++fails
        }
        else di as txt "pass `case_id' (error as expected, rc=`rc')"
    }
    else if (`rc'!=0) {
        di as err "FAIL `case_id': unexpected rc=`rc'."
        local ++fails
    }
    else {
        local ok 1
        if (_N != real("`expect_n'")) {
            di as err "FAIL `case_id': got _N=" _N ", expected `expect_n'."
            local ++fails
            local ok 0
        }
        if ("`expect_windex8'"!="") & (`ok') {
            quietly count if windex5==8
            if (r(N) != real("`expect_windex8'")) {
                di as err "FAIL `case_id': windex5==8 count " r(N) ", expected `expect_windex8'."
                local ++fails
                local ok 0
            }
        }
        if ("`expect_provenance'"=="1") & (`ok') {
            capture confirm variable ctrycode
            local rc1 = _rc
            capture confirm variable year
            if (`rc1' != 0) | (_rc != 0) {
                di as err "FAIL `case_id': provenance columns ctrycode/year missing."
                local ++fails
                local ok 0
            }
        }
        if (`ok') di as txt "pass `case_id' (_N=" _N ")"
    }
    use `stash', clear
}

*------------------------------------------------------------------------------*
* Part 3 — subcommand dispatch equivalence
* -datalib <subcmd> ...- must return exactly what -datalib_<subcmd> ...- returns.
*------------------------------------------------------------------------------*
capture program drop datalib
quietly run "stata/src/d/datalib.ado"
quietly run "stata/src/_/_dl_fileaction.ado"
quietly run "stata/src/d/datalib_explorer.ado"
quietly run "stata/src/d/datalib_index.ado"

* Pin the library so the legacy-surface cases below measure dispatch only, and
* never read the operator's real config or probe a network share.
global datalib `"`ROOT'"'

import delimited "tests/cases_resolve.csv", varnames(1) stringcols(_all) clear
local N = _N
forvalues i = 1/`N' {
    foreach v in case_id country year survey kind collection master_version ///
                 adaptation_version expect_error {
        local `v' = `v'[`i']
        if ("``v''"==".") local `v' ""
    }
    if ("`expect_error'"!="") continue          // error paths covered in Part 1
    local ++total
    * direct wrapper call (captured: a regression here must report, not abort)
    capture datalib_resolve, country(`country') year(`year') survey(`survey') ///
        kind(`kind') collection(`collection') master_version(`master_version') ///
        adaptation_version(`adaptation_version') root("`ROOT'")
    if (_rc != 0) {
        di as err "FAIL dispatch-`case_id': wrapper datalib_resolve rc=" _rc "."
        local ++fails
        continue
    }
    local direct "`r(vintage_folder)'"
    * same call through the dispatcher
    capture datalib resolve, country(`country') year(`year') survey(`survey') ///
        kind(`kind') collection(`collection') master_version(`master_version') ///
        adaptation_version(`adaptation_version') root("`ROOT'")
    if (_rc != 0) {
        di as err "FAIL dispatch-`case_id': rc=" _rc " through -datalib resolve-."
        local ++fails
    }
    else if ("`r(vintage_folder)'" != "`direct'") {
        di as err "FAIL dispatch-`case_id': dispatcher gave `r(vintage_folder)', wrapper gave `direct'."
        local ++fails
    }
    else di as txt "pass dispatch-`case_id' -> `r(vintage_folder)'"
}

* -return add- fidelity: the dispatcher must republish EVERY r() macro of the
* wrapper, not only the vintage_folder asserted above. (There is no r(macros)
* introspection to loop over, so the wrapper's documented returns are listed.)
local rmacs root country year survey kind collection master_version           ///
            adaptation_version survey_folder vintage_folder file_stem          ///
            data_stata data_original data_r data_other doc programs
local ++total
capture datalib_resolve, country(ZWE) year(2019) survey(MICS) kind(master) root("`ROOT'")
local rc_w = _rc
foreach m of local rmacs {
    local w_`m' `"`r(`m')'"'
}
capture datalib resolve, country(ZWE) year(2019) survey(MICS) kind(master) root("`ROOT'")
local bad ""
if (`rc_w'!=0) | (_rc!=0) local bad " (rc wrapper=`rc_w', dispatcher=`=_rc')"
else {
    foreach m of local rmacs {
        if (`"`r(`m')'"' != `"`w_`m''"') local bad `"`bad' `m'"'
    }
}
if (`"`bad'"'!="") {
    di as err "FAIL dispatch-return-add: differ or missing:`bad'."
    local ++fails
}
else di as txt "pass dispatch-return-add (`:word count `rmacs'' macros identical)"

* Every declared subcommand must be recognised (catches a typo in the dispatch
* list, or a wrapper that is not installed).
* Two subcommands need an argument to stay hermetic, because the bare call has a
* side effect on the operator's machine: -config- would read the real
* ~/.config files, and -map_drive- reaches `qui shell net use` (mapzdrive.ado:85)
* against a live share. Both accept an option that makes the call inert, and the
* assertion here is only "the subcommand is recognised (rc != 199)", so pinning
* them changes what is asserted not at all. c(tmpdir) is used directly: the
* harness's `TMP' local is not defined until Part 4.
local nosuchcfg = subinstr(`"`c(tmpdir)'"', "\", "/", .) + "dl_nosuch_config.yml"
foreach sub in resolve load catalog countries surveys vintages adaptations ///
               files create config root browse map_drive {
    local ++total
    if ("`sub'"=="config")          capture datalib config, config(`"`nosuchcfg'"')
    else if ("`sub'"=="map_drive")  capture datalib map_drive, dryrun
    else                            capture datalib `sub'
    if (_rc == 199) {
        di as err "FAIL dispatch-exists[`sub']: not recognised (rc=199)."
        local ++fails
    }
    else di as txt "pass dispatch-exists[`sub'] (recognised, rc=" _rc ")"
}

* Subcommand names must not be swallowed by the legacy surface, and non-
* subcommand first tokens must still reach it (bare/option-only calls).
local ++total
capture datalib countries, root("`ROOT'")
if (_rc != 0) {
    di as err "FAIL dispatch-countries: rc=" _rc "."
    local ++fails
}
else {
    * datalib_countries returns n as a MACRO (return local n), so it must be
    * converted before any numeric comparison — r(n) <= 0 is a type mismatch.
    local nn = real(`"`r(n)'"')
    if missing(`nn') | (`nn' <= 0) {
        di as err "FAIL dispatch-countries: r(n)=`r(n)'."
        local ++fails
    }
    else di as txt "pass dispatch-countries (r(n)=`r(n)')"
}

local ++total
capture datalib root, root("`ROOT'")
if (_rc != 0) | ("`r(source_stage)'" != "argument") {
    di as err "FAIL dispatch-root: rc=" _rc ", source_stage=`r(source_stage)'."
    local ++fails
}
else di as txt "pass dispatch-root (source_stage=argument)"

* Regression: an empty or unknown first token must never be dispatched.
* -:list "" in subcmds- is TRUE, so an unguarded dispatcher sends a bare
* -datalib- to -datalib_- and fails with rc 199 (command unrecognized).
foreach tok in "" "nosuchsubcmd" {
    local ++total
    capture datalib `tok'
    if (_rc == 199) {
        di as err "FAIL dispatch-guard[`tok']: token was dispatched (rc=199)."
        local ++fails
    }
    else di as txt "pass dispatch-guard[`tok'] (not dispatched, rc=" _rc ")"
}

*------------------------------------------------------------------------------*
* Part 4 — library resolution.
* DEFAULT datalib_root is pure string selection and must stay byte-identical to
* R/Python (c01-c04). -find- adds the Stata-only disk resolution: descend into a
* datalib child, refuse a directory that is not a library, and discover only when
* nothing is configured (c05-c11). See tests/DIVERGENCES.md.
*------------------------------------------------------------------------------*

* Scratch trees, built under c(tmpdir):
*   <TMP>/place/datalib   a library inside a "place"  (descent)
*   <TMP>/notalib         a directory that is NOT a library (refusal)
local TMPB = subinstr(`"`c(tmpdir)'"', "\", "/", .)
if (substr(`"`TMPB'"', -1, 1)=="/") local TMPB = substr(`"`TMPB'"', 1, strlen(`"`TMPB'"')-1)
local TMP `"`TMPB'/dl_libcase"'
capture mkdir `"`TMP'"'
capture mkdir `"`TMP'/place"'
capture mkdir `"`TMP'/place/datalib"'
capture mkdir `"`TMP'/notalib"'
_dl_islib `"`TMP'/place/datalib"'
local fixture_ok = r(islib)
_dl_islib `"`TMP'/notalib"'
local notalib_ok = (r(exists)==1 & r(islib)==0)
if (`fixture_ok'!=1) | (`notalib_ok'!=1) {
    di as err "FAIL setup: scratch trees under `TMP' are not as required " ///
              "(islib=`fixture_ok', notalib=`notalib_ok') — cannot run Part 4."
    * ++total as well as ++fails: every other site pairs them, and the report
    * prints `total'-`fails' as the numerator, so incrementing fails alone
    * under-reports the denominator and can print a negative pass count.
    local ++total
    local ++fails
}

* ROOT comes from c(pwd), which is backslashed on Windows; the resolver
* normalizes to forward slashes, so compare against the normalized form.
_dl_islib `"`ROOT'"'
local ROOTN `"`r(path)'"'

* --- default mode: contract behaviour, no disk access ------------------------

* c01 — first non-empty candidate wins, returned as given
local ++total
capture datalib_root, root("`ROOT'")
if (_rc!=0) | (`"`r(root)'"'!=`"`ROOT'"') | ("`r(source_stage)'"!="argument") {
    di as err "FAIL c01: rc=" _rc " root=`r(root)' stage=`r(source_stage)'."
    local ++fails
}
else di as txt "pass c01 (argument returned as given)"

* c02 — a NONEXISTENT root is still returned, with stage argument: R and Python
* do not validate existence, and datalib_root's default must not either.
local ++total
capture datalib_root, root("Z:/no-such-library-xyz")
if (_rc!=0) | (`"`r(root)'"'!="Z:/no-such-library-xyz") | ("`r(source_stage)'"!="argument") {
    di as err "FAIL c02: rc=" _rc " root=`r(root)' stage=`r(source_stage)' (parity: must be returned as given)."
    local ++fails
}
else di as txt "pass c02 (nonexistent argument returned as given — R/Python parity)"

* c03 — precedence: global is used when no argument is given
local ++total
global datalib `"`TMP'/place"'
capture datalib_root
if (_rc!=0) | (`"`r(root)'"'!=`"`TMP'/place"') | ("`r(source_stage)'"!="global") {
    di as err "FAIL c03: rc=" _rc " root=`r(root)' stage=`r(source_stage)'."
    local ++fails
}
else di as txt "pass c03 (global, no descent in default mode)"

* c04 — nothing set: error 198, no discovery in default mode
local envroot : environment DATALIB_ROOT
if (`"`envroot'"'!="") {
    di as txt "skip c04 (DATALIB_ROOT is set: `envroot')"
    local ++skips
}
else {
    local ++total
    global datalib ""
    capture datalib_root
    if (_rc != 198) {
        di as err "FAIL c04: rc=" _rc " (expected 198; default mode must not discover)."
        local ++fails
    }
    else di as txt "pass c04 (default mode errors rather than discovering)"
}

* --- find mode: disk resolution ---------------------------------------------

* c05 — find uses an existing library as given (no descent)
local ++total
capture datalib_root, root("`ROOT'") find
if (_rc!=0) | (`"`r(root)'"'!=`"`ROOTN'"') | (r(descended)!=0) | ("`r(source_stage)'"!="argument") {
    di as err "FAIL c05: rc=" _rc " root=`r(root)' descended=" r(descended) " stage=`r(source_stage)'."
    local ++fails
}
else di as txt "pass c05 (find: library used as given)"

* c06 — find descends from the place holding the library
local ++total
capture datalib_root, root(`"`TMP'/place"') find
if (_rc!=0) | (`"`r(root)'"'!=`"`TMP'/place/datalib"') | (r(descended)!=1) {
    di as err "FAIL c06: rc=" _rc " root=`r(root)' descended=" r(descended) " (expected `TMP'/place/datalib, 1)."
    local ++fails
}
else di as txt "pass c06 (find: descended into the datalib folder)"

* c07 — backslashes and trailing separators normalized
local ++total
local messy = subinstr(`"`TMP'/place"', "/", "\", .) + "\"
capture datalib_root, root(`"`messy'"') find
if (_rc!=0) | (`"`r(root)'"'!=`"`TMP'/place/datalib"') {
    di as err "FAIL c07: rc=" _rc " root=`r(root)' (expected `TMP'/place/datalib)."
    local ++fails
}
else di as txt "pass c07 (find: path normalized)"

* c08 — a directory that EXISTS but is not a library is refused, not accepted.
* Without this, any existing path (C:/, a share root) would resolve silently.
local ++total
capture datalib_root, root(`"`TMP'/notalib"') find
if (_rc != 198) {
    di as err "FAIL c08: rc=" _rc " (expected 198; an existing non-library must be refused)."
    local ++fails
}
else di as txt "pass c08 (find: existing non-library refused, rc=198)"

* c09 — a configured-but-missing root ERRORS; it is never silently replaced by a
* discovered library, which would destroy the provenance of the switch.
local ++total
global datalib `"`TMP'/no-such-place-xyz"'
global zDrive  `"`TMP'/place"'
capture datalib_root, find
if (_rc != 198) {
    di as err "FAIL c09: rc=" _rc " (expected 198; a stale global must not fall through to discovery)."
    local ++fails
}
else di as txt "pass c09 (find: stale global errors, no silent substitution)"

* c10 — discovery fires only when nothing is configured, and finds the library
* under ${zDrive}. Hermetic: zDrive is pointed at the scratch place, and it is
* base 1, so the machine's own Z: cannot pre-empt it.
local ++total
global datalib ""
global zDrive `"`TMP'/place"'
capture datalib_root, find
if (_rc!=0) | (`"`r(root)'"'!=`"`TMP'/place/datalib"') | ("`r(source_stage)'"!="discovered") {
    di as err "FAIL c10: rc=" _rc " root=`r(root)' stage=`r(source_stage)' (expected `TMP'/place/datalib, discovered)."
    local ++fails
}
else di as txt "pass c10 (find: discovered `r(root)')"

* c11 — library() on the legacy surface resolves, publishes to ${datalib}, and
* its error path surfaces rc 198 rather than being swallowed.
local ++total
global datalib ""
global zDrive ""
capture datalib, library("`ROOT'") country(ZWE)
if (_rc != 0) | (`"${datalib}"'!=`"`ROOTN'"') {
    di as err "FAIL c11: rc=" _rc " global=${datalib} (expected 0, `ROOTN')."
    local ++fails
}
else di as txt "pass c11 (library() published to \${datalib})"

local ++total
global datalib ""
capture datalib, library(`"`TMP'/notalib"') country(ZWE)
if (_rc != 198) {
    di as err "FAIL c12: rc=" _rc " (expected 198 from -datalib, library(<non-library>)-)."
    local ++fails
}
else di as txt "pass c12 (library() error path surfaces rc=198)"

* c13 — REGRESSION: the navigation click-state must survive the root
* resolution. datalib_root is rclass, so resolving inside -datalib- wipes r();
* _foldernav's DATA/DOC/PROGRAMS links read the folder back out of
* r(subfoldr), and a wiped r() used to build "<root>/./Data/Stata/" and fail
* with r(601). -datalib- holds and restores r() around the resolution.
local ++total
global datalib `"`ROOTN'"'
global datalib_checked ""
quietly datalib, subfoldr(ZWE_2019_MICS_v02_M)
local carried `"`r(subfoldr)'"'
capture datalib, subfoldr(DATA)
local c13rc = _rc
local c13full `"`r(fullfoldr)'"'
if (`c13rc'!=0) | (`"`c13full'"'!=`"`carried'/Data/Stata/"') {
    di as err "FAIL c13: rc=`c13rc' fullfoldr=`c13full' (expected `carried'/Data/Stata/)."
    local ++fails
}
else di as txt "pass c13 (click-state survives root resolution -> `c13full')"

* c14 — a section link with no navigation behind it must say so, not build a
* path with a missing component in it.
local ++total
global datalib `"`ROOTN'"'
global datalib_checked ""
quietly datalib_countries, root(`"`ROOTN'"')      // an rclass call, no r(subfoldr)
capture datalib, subfoldr(DOC)
if (_rc != 198) {
    di as err "FAIL c14: rc=" _rc " (expected 198 naming the lost click-state)."
    local ++fails
}
else di as txt "pass c14 (missing click-state errors clearly, rc=198)"

*------------------------------------------------------------------------------*
* Part 5 — config bootstrap (-getuserconfig, init-). Generic: no library lookup
* happens here; the caller supplies it. See tests/DIVERGENCES.md.
*------------------------------------------------------------------------------*
local ib `"`TMP'/initcase"'
capture mkdir `"`ib'"'
capture mkdir `"`ib'/personal"'
local icfg `"`ib'/user_config.yml"'
local iprof `"`ib'/personal/profile.do"'
capture erase `"`icfg'"'
capture erase `"`iprof'"'
local personal_saved "`c(sysdir_personal)'"
sysdir set PERSONAL `"`ib'/personal"'

* i01 — init writes a block the READER can parse back (the round trip)
local ++total
capture getuserconfig, user(ciuser) config(`"`icfg'"') init library("Z:/somelib")
local i1rc = _rc
capture getuserconfig, user(ciuser) config(`"`icfg'"')
if (`i1rc'!=0) | (_rc!=0) | (`"`r(datalib)'"'!="Z:/somelib") {
    di as err "FAIL i01: init rc=`i1rc', read rc=" _rc ", datalib=`r(datalib)'."
    local ++fails
}
else di as txt "pass i01 (init -> read round trip, datalib=`r(datalib)')"

* i02 — a second init keeps the block instead of duplicating it
local ++total
capture getuserconfig, user(ciuser) config(`"`icfg'"') init library("Z:/somelib")
if (_rc!=0) | ("`r(init_action)'"!="kept") {
    di as err "FAIL i02: rc=" _rc " init_action=`r(init_action)' (expected kept)."
    local ++fails
}
else di as txt "pass i02 (existing block kept, not duplicated)"

* i03 — a file with someone else's block is APPENDED to, never rewritten
local ++total
capture getuserconfig, user(otherop) config(`"`icfg'"') init library("Z:/otherlib")
local i3act "`r(init_action)'"
capture getuserconfig, user(ciuser) config(`"`icfg'"')
local i3keep `"`r(datalib)'"'
capture getuserconfig, user(otherop) config(`"`icfg'"')
if ("`i3act'"!="appended") | (`"`i3keep'"'!="Z:/somelib") | (`"`r(datalib)'"'!="Z:/otherlib") {
    di as err "FAIL i03: action=`i3act' first=`i3keep' second=`r(datalib)'."
    local ++fails
}
else di as txt "pass i03 (block appended; both operators readable)"

* i04 — profile.do is created when absent, and never overwritten after that
local ++total
capture getuserconfig, user(pu2) config(`"`ib'/p2.yml"') init profile library("Z:/somelib")
capture confirm file `"`iprof'"'
local i4made = (_rc==0)
tempname pfh
file open `pfh' using `"`iprof'"', write text append
file write `pfh' "* operator's own startup code" _n
file close `pfh'
capture getuserconfig, user(pu2) config(`"`ib'/p2.yml"') init profile library("Z:/somelib")
local i4kept 0
tempname rfh
file open `rfh' using `"`iprof'"', read text
file read `rfh' pline
while (r(eof)==0) {
    if (strpos(`"`macval(pline)'"', "operator's own startup code")>0) local i4kept 1
    file read `rfh' pline
}
file close `rfh'
if (`i4made'!=1) | (`i4kept'!=1) {
    di as err "FAIL i04: created=`i4made' preserved=`i4kept'."
    local ++fails
}
else di as txt "pass i04 (profile.do created once, then preserved)"

* i06 — REGRESSION: appending to a config whose last line has NO trailing
* newline must not concatenate onto it. Unterminated, the new key stops being
* top-level, the PREVIOUS operator's block swallows it, and that operator starts
* reporting someone else's paths — silent corruption of a shared file.
local ++total
local nlf `"`ib'/nonewline.yml"'
capture erase `"`nlf'"'
tempname nfh
file open `nfh' using `"`nlf'"', write text replace
file write `nfh' "opa:" _n
file write `nfh' `"  githubFolder: "C:/opa/github""' _n
file write `nfh' `"  datalib: "Z:/opa-lib""'          // deliberately unterminated
file close `nfh'
capture getuserconfig, user(opb) config(`"`nlf'"') init library("Z:/opb-lib")
local i6rc = _rc
capture getuserconfig, user(opa) config(`"`nlf'"')
local i6a `"`r(datalib)'"'
local i6ag `"`r(githubFolder)'"'
capture getuserconfig, user(opb) config(`"`nlf'"')
local i6b `"`r(datalib)'"'
if (`i6rc'!=0) | (`"`i6a'"'!="Z:/opa-lib") | (`"`i6ag'"'!="C:/opa/github") | (`"`i6b'"'!="Z:/opb-lib") {
    di as err "FAIL i06: first operator now reads datalib=`i6a' github=`i6ag'; new operator datalib=`i6b'."
    local ++fails
}
else di as txt "pass i06 (unterminated file appended safely; neither block corrupted)"

* i07 — `replace` must REPLACE, never emit a second top-level key. R's
* yaml::read_yaml (r/R/datalib_config.R) hard-errors on a duplicate map key,
* while Stata and Python tolerate it last-wins — so counting the keys is the
* only way a Stata suite can see this breakage at all.
local ++total
local rpf `"`ib'/replace.yml"'
capture erase `"`rpf'"'
tempname rpfh
file open `rpfh' using `"`rpf'"', write text replace
file write `rpfh' "opx:" _n `"  datalib: "Z:/opx""' _n "" _n
file write `rpfh' "opy:" _n `"  datalib: "Z:/opy-old""' _n "" _n
file write `rpfh' "opz:" _n `"  datalib: "Z:/opz""' _n
file close `rpfh'
capture getuserconfig, user(opy) config(`"`rpf'"') init library("Z:/opy-new") replace
mata: st_local("nkey", strofreal(sum(strpos(cat(st_local("rpf")), "opy:"):>0)))
capture getuserconfig, user(opy) config(`"`rpf'"')
local rp_y `"`r(datalib)'"'
capture getuserconfig, user(opx) config(`"`rpf'"')
local rp_x `"`r(datalib)'"'
capture getuserconfig, user(opz) config(`"`rpf'"')
local rp_z `"`r(datalib)'"'
if ("`nkey'"!="1") | (`"`rp_y'"'!="Z:/opy-new") | (`"`rp_x'"'!="Z:/opx") | (`"`rp_z'"'!="Z:/opz") {
    di as err "FAIL i07: 'opy:' keys=`nkey' (expect 1); opy=`rp_y' opx=`rp_x' opz=`rp_z'."
    local ++fails
}
else di as txt "pass i07 (replace rewrote in place; one key; neighbours intact)"

* i08 — the documented first-run command on a machine that already has a block
* but no profile.do: write the profile, leave the CONFIG untouched. Appending
* here was what produced a duplicate key.
local ++total
local pxf `"`ib'/profexist.yml"'
capture erase `"`pxf'"'
capture erase `"`iprof'"'
capture getuserconfig, user(opp) config(`"`pxf'"') init library("Z:/opp")
mata: st_local("sz1", strofreal(strlen(cat(st_local("pxf"))[1])))
local n1 : word count `"`c(filename)'"'
capture getuserconfig, user(opp) config(`"`pxf'"') init profile library("Z:/opp")
local i8act "`r(init_action)'"
mata: st_local("nk8", strofreal(sum(strpos(cat(st_local("pxf")), "opp:"):>0)))
capture confirm file `"`iprof'"'
local i8prof = (_rc==0)
if ("`i8act'"!="kept") | ("`nk8'"!="1") | (`i8prof'!=1) {
    di as err "FAIL i08: action=`i8act' keys=`nk8' profile_created=`i8prof'."
    local ++fails
}
else di as txt "pass i08 (profile written, config left alone, still one key)"

* i09 — a BOM-prefixed config must still be recognised. The detector compares a
* trimmed line to "<user>:"; a UTF-8 BOM makes line 1 eight characters, so
* without stripping it the block is missed and a duplicate appended.
local ++total
local bomf `"`ib'/bom.yml"'
capture erase `"`bomf'"'
mata: bfh = fopen(st_local("bomf"), "w");                                     ///
      fwrite(bfh, char(239)+char(187)+char(191)+"opb:"+char(13)+char(10));     ///
      fwrite(bfh, "  datalib: "+char(34)+"Z:/opb"+char(34)+char(13)+char(10)); ///
      fclose(bfh)
capture getuserconfig, user(opb) config(`"`bomf'"') init library("Z:/opb")
local i9act "`r(init_action)'"
mata: st_local("nk9", strofreal(sum(strpos(cat(st_local("bomf")), "opb:"):>0)))
if ("`i9act'"!="kept") | ("`nk9'"!="1") {
    di as err "FAIL i09: action=`i9act' keys=`nk9' (BOM defeated block detection)."
    local ++fails
}
else di as txt "pass i09 (BOM-prefixed config recognised, no duplicate)"

* i10 — the whole reason _uc_dirs uses Mata's dir(): Stata's -dir- macro
* function lowercases names on Windows, and a lowercased path can be wrong for
* the R/Python readers on a case-sensitive filesystem. Assert the real casing
* survives into the written file.
local ++total
local ch `"`ib'/casehome"'
capture mkdir `"`ch'"'
capture mkdir `"`ch'/UNICEF"'
capture mkdir `"`ch'/UNICEF/MixedCase Office - Documents"'
capture _uc_dirs `"`ch'/UNICEF"' "*- Documents"
local cs `"`r(dirs)'"'
if (strpos(`"`cs'"', "MixedCase Office - Documents")==0) {
    di as err `"FAIL i10: casing not preserved, got `cs'."'
    local ++fails
}
else di as txt "pass i10 (directory casing preserved by _uc_dirs)"

* i11 — the generated profile.do must be COMPLETE and guarded. A previous
* attempt embedded a quote in a comment; Stata has no backslash escapes, so the
* -file write- ended early, the writer aborted, and the profile shipped as a
* truncated no-op that still returned rc 0. Assert the code lines are present,
* not merely that writing succeeded. The -which- guard matters because the file
* outlives -ado uninstall datalib- and -capture noisily- on a missing command
* still prints an unrecognized-command error at every launch.
local ++total
capture erase `"`iprof'"'
capture getuserconfig, user(pu3) config(`"`ib'/p3.yml"') init profile library("Z:/somelib")
local i11has 0
local i11guard 0
capture confirm file `"`iprof'"'
if (_rc==0) {
    tempname i11fh
    file open `i11fh' using `"`iprof'"', read text
    file read `i11fh' i11ln
    while (r(eof)==0) {
        if (strpos(`"`macval(i11ln)'"', "capture which getuserconfig")>0)            local i11guard 1
        if (strpos(`"`macval(i11ln)'"', "if !_rc capture noisily getuserconfig")>0)  local i11has 1
        file read `i11fh' i11ln
    }
    file close `i11fh'
}
if (`i11has'!=1) | (`i11guard'!=1) {
    di as err "FAIL i11: generated profile incomplete (call=`i11has' guard=`i11guard')."
    local ++fails
}
else di as txt "pass i11 (generated profile complete and guarded)"

* i05 — PURITY: a read of a missing file must still error and write nothing
local ++total
capture getuserconfig, user(nobody2) config(`"`ib'/absent.yml"')
local i5rc = _rc
capture confirm file `"`ib'/absent.yml"'
if (`i5rc'!=601) | (_rc==0) {
    di as err "FAIL i05: read rc=`i5rc' (expected 601); file created=" (_rc==0) "."
    local ++fails
}
else di as txt "pass i05 (read stays pure: errors 601, creates nothing)"

sysdir set PERSONAL `"`personal_saved'"'
capture erase `"`icfg'"'
capture erase `"`iprof'"'
capture erase `"`ib'/p2.yml"'
capture erase `"`ib'/p3.yml"'
capture erase `"`ib'/nonewline.yml"'
capture erase `"`ib'/replace.yml"'
capture erase `"`ib'/profexist.yml"'
capture erase `"`ib'/bom.yml"'
capture erase `"`ib'/replace.yml.bak"'
capture erase `"`ib'/profexist.yml.bak"'
capture erase `"`ib'/bom.yml.bak"'
capture erase `"`ib'/nonewline.yml.bak"'
capture erase `"`ib'/user_config.yml.bak"'
capture rmdir `"`ib'/casehome/UNICEF/MixedCase Office - Documents"'
capture rmdir `"`ib'/casehome/UNICEF"'
capture rmdir `"`ib'/casehome"'
capture rmdir `"`ib'/personal"'
capture rmdir `"`ib'"'

*------------------------------------------------------------------------------*
* Part 6 — config resolution (the CFG golden cases).
*
* Folded in from stata/tests/test_config_resolution.do in v0.9.6. That file was
* never called by this harness and ran only when hand-typed, which is how it came
* to be cited as passing while nothing had executed it (tests/DIVERGENCES.md).
* Its assertions were bare -assert-, which aborts the run instead of tallying; they
* are rewritten here in the harness idiom so a failure is counted and reported.
*
* Mirrors r/tests/testthat/test-config-resolution.R and
* python/tests/test_config_resolution.py. Stata cannot set an environment variable
* in-session, so the two-file search directory arrives through the Stata-specific
* configdir() option rather than DATALIB_CONFIG_DIR (config/grammar.md section 7).
*------------------------------------------------------------------------------*
di as result _n "Part 6 — config resolution (CFG cases)"

local CFGB = subinstr(`"`c(tmpdir)'"', "\", "/", .)
if (substr(`"`CFGB'"', -1, 1)=="/") local CFGB = substr(`"`CFGB'"', 1, strlen(`"`CFGB'"')-1)
local CFG `"`CFGB'/dl_cfg_case"'
capture mkdir `"`CFG'"'
local GEN `"`CFG'/user_config.yml"'
local PKG `"`CFG'/datalib_config.yml"'

* Writes a `testuser:' block. The dl argument is a SENTINEL, not a path:
*   ABSENT -> erase the file, so it does not exist at all
*   NOKEY  -> write the block with a githubFolder key but no datalib: key
*   EMPTY  -> write datalib: "" (present but empty; the contract counts that absent)
* any other value is written verbatim as the datalib: value.
capture program drop _cfg_wblock
program define _cfg_wblock
    args path dl
    if ("`dl'"=="ABSENT") {
        * confirm-then-erase rather than -capture erase-: capture traps the rc but
        * Stata still prints "(file ... not found)", and a manual gate whose output
        * is full of benign noise trains the operator to skim past real messages.
        capture confirm file `"`path'"'
        if (_rc==0) erase `"`path'"'
        exit
    }
    * quietly: -replace- on a path that does not exist yet still prints
    * "(file ... not found)" from its pre-erase, which is benign but noisy.
    quietly {
        tempname fh
        file open `fh' using `"`path'"', write text replace
        file write `fh' "testuser:" _n
        if ("`dl'"=="NOKEY")      file write `fh' `"  githubFolder: "C:/GitHub""' _n
        else if ("`dl'"=="EMPTY") file write `fh' `"  datalib: """' _n
        else                      file write `fh' `"  datalib: "`dl'""' _n
        file close `fh'
    }
end

* id | generic block | package block | expected stage | expected ${datalib}
foreach spec in                                                              ///
    "CFG-01 Z:/from_generic ABSENT          config_generic Z:/from_generic"  ///
    "CFG-02 ABSENT          Z:/from_package config_package Z:/from_package"  ///
    "CFG-03 Z:/from_generic Z:/from_package config_generic Z:/from_generic"  ///
    "CFG-04 NOKEY           Z:/from_package config_package Z:/from_package"  ///
    "CFG-05 NOKEY           ABSENT          unset          NONE"             ///
    "CFG-09 EMPTY           Z:/from_package config_package Z:/from_package" {

    gettoken id    rest : spec
    gettoken gdl   rest : rest
    gettoken pdl   rest : rest
    gettoken est   rest : rest
    gettoken eroot rest : rest
    if ("`eroot'"=="NONE") local eroot ""

    _cfg_wblock `"`GEN'"' "`gdl'"
    _cfg_wblock `"`PKG'"' "`pdl'"

    local ++total
    global datalib ""
    capture getuserconfig, user(testuser) configdir(`"`CFG'"')
    local grc = _rc
    local gst  `"`r(source_stage)'"'
    local gdlv `"${datalib}"'
    if (`grc'!=0) | ("`gst'"!="`est'") | (`"`gdlv'"'!=`"`eroot'"') {
        di as err `"FAIL `id': rc=`grc' stage=`gst' datalib=`gdlv' (expected stage `est', datalib `eroot')."'
        local ++fails
    }
    else di as txt `"pass `id' (`gdl' + `pdl' -> `gst')"'
}

* CFG-05b — with no key anywhere and no global, datalib_root itself must error.
* Guarded like c04: an ambient DATALIB_ROOT would legitimately resolve instead,
* so the case would fail for a reason that is not a defect.
local envroot : environment DATALIB_ROOT
if (`"`envroot'"'!="") {
    di as txt "skip CFG-05b (DATALIB_ROOT is set: `envroot')"
    local ++skips
}
else {
    _cfg_wblock `"`GEN'"' "NOKEY"
    _cfg_wblock `"`PKG'"' "ABSENT"
    local ++total
    global datalib ""
    capture getuserconfig, user(testuser) configdir(`"`CFG'"')
    capture datalib_root
    if (_rc != 198) {
        di as err "FAIL CFG-05b: datalib_root rc=" _rc " (expected 198)."
        local ++fails
    }
    else di as txt "pass CFG-05b (no key anywhere -> datalib_root errors 198)"
}

* CFG-07 — config() pins exactly one file and disables the two-file fallback:
* the generic file is present and has a key, and must be ignored.
_cfg_wblock `"`GEN'"' "Z:/from_generic"
_cfg_wblock `"`PKG'"' "Z:/pinned"
local ++total
global datalib ""
capture getuserconfig, user(testuser) config(`"`PKG'"')
local grc = _rc
local gst  `"`r(source_stage)'"'
local gdlv `"${datalib}"'
if (`grc'!=0) | ("`gst'"!="config_package") | (`"`gdlv'"'!="Z:/pinned") {
    di as err `"FAIL CFG-07: rc=`grc' stage=`gst' datalib=`gdlv' (expected config_package / Z:/pinned)."'
    local ++fails
}
else di as txt "pass CFG-07 (config() pins one file, fallback off)"

* CFG-10 — datalib_root reports the stage it resolved from, and argument beats
* the session global.
local ++total
global datalib "Z:/from_global"
capture datalib_root
local s1 `"`r(source_stage)'"'
capture datalib_root, root("Z:/explicit")
local s2 `"`r(source_stage)'"'
local r2 `"`r(root)'"'
if ("`s1'"!="global") | ("`s2'"!="argument") | (`"`r2'"'!="Z:/explicit") {
    di as err `"FAIL CFG-10: global->`s1' argument->`s2' root=`r2' (expected global, argument, Z:/explicit)."'
    local ++fails
}
else di as txt "pass CFG-10 (stages: global, argument)"

capture program drop _cfg_wblock
foreach f in `"`GEN'"' `"`PKG'"' {
    capture confirm file `"`f'"'
    if (_rc==0) erase `"`f'"'
}
capture rmdir `"`CFG'"'

*------------------------------------------------------------------------------*
* Part 7 - shared enumerator cases (tests/cases_enumerate.csv).
*
* The contract pins the VALUE SET an enumerator returns, not the container
* (config/grammar.md rule 9), so this part adapts Stata's r() strings to the same
* normalised list R and Python assert from their own return types. Without that
* reframing a shared corpus is impossible, and was abandoned as such: Stata
* returns "HLT IPUMS" and bare integers, R data frames of folder names, Python
* dataclasses.
*------------------------------------------------------------------------------*
di as result _n "Part 7 - shared enumerator cases"

import delimited "tests/cases_enumerate.csv", varnames(1) stringcols(_all) clear
local NE = _N
forvalues i = 1/`NE' {
    foreach v in case_id fn country year survey expect_values {
        local `v' = `v'[`i']
        if ("``v''"==".") local `v' ""
    }
    local ++total
    local got ""
    local erc 0

    if ("`fn'"=="countries") {
        capture datalib_countries, root("`ROOT'")
        local erc = _rc
        local got `"`r(countries)'"'
        local got : list sort got
    }
    else if ("`fn'"=="surveys") {
        capture datalib_surveys, country("`country'") root("`ROOT'")
        local erc = _rc
        local got `"`r(surveys)'"'
        local got : list sort got
    }
    else if ("`fn'"=="vintages") {
        capture datalib_vintages, country("`country'") year("`year'") ///
                                  survey("`survey'") root("`ROOT'")
        local erc = _rc
        local raw `"`r(masters)'"'
        * NUMERIC ascending: -: list sort- is a string sort and would order the
        * masters 9 and 10 as "10 9", which is the trap rule 9 calls out.
        local got ""
        if (`"`raw'"'!="") {
            numlist `"`raw'"', sort
            local got `"`r(numlist)'"'
        }
    }
    else if ("`fn'"=="adaptations") {
        capture datalib_adaptations, country("`country'") year("`year'") ///
                                     survey("`survey'") root("`ROOT'")
        local erc = _rc
        local got `"`r(collections)'"'
        local got : list sort got
    }
    else {
        di as err "FAIL `case_id': unknown fn `fn' in cases_enumerate.csv."
        local ++fails
        continue
    }

    if (`erc'!=0) {
        di as err "FAIL `case_id' (`fn'): rc=`erc' (expected a value list)."
        local ++fails
    }
    else if (`"`got'"'!=`"`expect_values'"') {
        di as err `"FAIL `case_id' (`fn'): expected [`expect_values'] got [`got']."'
        local ++fails
    }
    else di as txt `"pass `case_id' (`fn' -> `got')"'
}

*------------------------------------------------------------------------------*
* Part 8 - the error taxonomy (tests/error_taxonomy.csv).
*
* config/grammar.md section 6 identifies contract errors by NAME and records the
* per-language mapping in that CSV; this part is the Stata enforcer. Nothing had
* ever asserted the table, which is how it came to document an accidental rc 601
* leak as though it were the design.
*
* Stata's mapping is deliberately NOT injective - three usable codes for five
* errors - so a row lists every code its error may reach and the assertion is
* membership, not equality.
*------------------------------------------------------------------------------*
di as result _n "Part 8 - error taxonomy"

* a config file that EXISTS but carries no block for the user we ask about
local taxdir = subinstr(`"`c(tmpdir)'"', "\", "/", .)
if (substr(`"`taxdir'"', -1, 1)=="/") local taxdir = substr(`"`taxdir'"', 1, strlen(`"`taxdir'"')-1)
local taxcfg `"`taxdir'/dl_tax_cfg.yml"'
quietly {
    tempname tfh
    file open `tfh' using `"`taxcfg'"', write text replace
    file write `tfh' "someoneelse:" _n `"  datalib: "Z:/x""' _n
    file close `tfh'
}

import delimited "tests/error_taxonomy.csv", varnames(1) stringcols(_all) clear
local NT = _N
forvalues i = 1/`NT' {
    local ename  = error_name[`i']
    local ercs   = stata_rc[`i']
    local ++total

    * one fixed trigger per contract error, chosen to be hermetic
    if ("`ename'"=="input_invalid") {
        capture datalib_vintages, country(ZWE) year(notayear) survey(MICS) root("`ROOT'")
    }
    else if ("`ename'"=="not_found") {
        * 198 half: a country absent from a library that EXISTS
        capture datalib_surveys, country(XXX) root("`ROOT'")
    }
    else if ("`ename'"=="config_file_missing") {
        capture getuserconfig, user(nobody) config(`"`taxdir'/dl_no_such_cfg.yml"')
    }
    else if ("`ename'"=="user_block_missing") {
        capture getuserconfig, user(nobody) config(`"`taxcfg'"')
    }
    else if ("`ename'"=="root_unset") {
        local envsave : environment DATALIB_ROOT
        global datalib ""
        capture datalib_countries
    }
    else {
        di as err "FAIL taxonomy[`ename']: no trigger defined in this harness."
        local ++fails
        continue
    }
    local trc = _rc

    * root_unset cannot be triggered when the env var supplies a root
    if ("`ename'"=="root_unset") & (`"`envsave'"'!="") {
        di as txt "skip taxonomy[`ename'] (DATALIB_ROOT is set)"
        local --total
        local ++skips
        continue
    }

    local ok 0
    foreach c of local ercs {
        if (`trc'==`c') local ok 1
    }
    if (`ok'!=1) {
        di as err "FAIL taxonomy[`ename']: rc=`trc' is not among the documented [`ercs']."
        local ++fails
    }
    else di as txt "pass taxonomy[`ename'] (rc=`trc' in [`ercs'])"
}

* the 601 half of not_found: the LIBRARY itself is absent. Before v0.9.7 this was
* an unguarded -: dir- leak surfacing Stata's own message, not a datalib one.
local ++total
capture datalib_countries, root("`taxdir'/dl_definitely_not_a_library")
if (_rc != 601) {
    di as err "FAIL taxonomy[not_found/601]: rc=" _rc " (expected 601 for an absent library)."
    local ++fails
}
else di as txt "pass taxonomy[not_found/601] (absent library -> deliberate 601)"

capture confirm file `"`taxcfg'"'
if (_rc==0) erase `"`taxcfg'"'

*------------------------------------------------------------------------------*
* Part 9 - the declared option surface is really accepted (config/surface.yml).
*
* surface.yml is enforced from Python (python/tests/test_surface.py), which parses
* each .ado's -syntax- as TEXT. That parse found six real bugs while being
* written, but it has one weakness no amount of care removes: surface.yml was
* first GENERATED from the parser, so a parser bug would be baked into the
* declaration and the Python guard would confirm it happily.
*
* Ten of the .ado files carry their own .sthlp whose Syntax section agrees exactly
* with the parse - independent, human-written corroboration. datalib_config and
* datalib_map_drive are covered the same way via their aliases
* (getuserconfig.sthlp, mapzdrive.sthlp), and are NOT probed live here because
* their remaining options write files, open an editor, or shell out to `net use`:
* that would trade a real side effect for no extra assurance.
*
* The rest are corroborated the only way that is genuinely independent of the
* parser - by calling each command with EVERY option surface.yml declares for it
* and asserting the call is not rejected. A misparsed or invented option name
* gives rc 198 (invalid syntax / option not allowed) here.
*
* Written out inline rather than looped over a list of call strings: Stata has no
* backslash escapes, so embedding quoted paths in a -foreach- list corrupts them
* (r(132), and a path parsed as a label).
*------------------------------------------------------------------------------*
di as result _n "Part 9 - declared options are accepted"

local p9new = subinstr(`"`c(tmpdir)'"', "\", "/", .)
if (substr(`"`p9new'"', -1, 1)=="/") local p9new = substr(`"`p9new'"', 1, strlen(`"`p9new'"')-1)
local p9new `"`p9new'/dl_p9_create"'
capture mkdir `"`p9new'"'

local ++total
capture quietly datalib_countries, root("`ROOT'")
if (_rc==198) {
    di as err "FAIL surface[countries]: rc=198 - a declared option was rejected by -syntax-."
    local ++fails
}
else di as txt "pass surface[countries] (declared options accepted, rc=" _rc ")"

local ++total
capture quietly datalib_surveys, country(ZWE) survey(MICS) root("`ROOT'")
if (_rc==198) {
    di as err "FAIL surface[surveys]: rc=198 - a declared option was rejected."
    local ++fails
}
else di as txt "pass surface[surveys] (declared options accepted, rc=" _rc ")"

local ++total
capture quietly datalib_vintages, country(ZWE) year(2019) survey(MICS) root("`ROOT'")
if (_rc==198) {
    di as err "FAIL surface[vintages]: rc=198 - a declared option was rejected."
    local ++fails
}
else di as txt "pass surface[vintages] (declared options accepted, rc=" _rc ")"

local ++total
capture quietly datalib_adaptations, country(ZWE) year(2019) survey(MICS) root("`ROOT'")
if (_rc==198) {
    di as err "FAIL surface[adaptations]: rc=198 - a declared option was rejected."
    local ++fails
}
else di as txt "pass surface[adaptations] (declared options accepted, rc=" _rc ")"

local ++total
capture quietly datalib_resolve, country(ZWE) year(2019) survey(MICS) ///
    kind(adaptation) collection(HLT) master_version(2) adaptation_version(1) ///
    root("`ROOT'")
if (_rc==198) {
    di as err "FAIL surface[resolve]: rc=198 - a declared option was rejected."
    local ++fails
}
else di as txt "pass surface[resolve] (declared options accepted, rc=" _rc ")"

local ++total
capture quietly datalib_files, country(ZWE) year(2019) survey(MICS) ///
    kind(adaptation) collection(HLT) master_version(2) adaptation_version(1) ///
    section(doc) pattern(*) root("`ROOT'")
if (_rc==198) {
    di as err "FAIL surface[files]: rc=198 - a declared option was rejected."
    local ++fails
}
else di as txt "pass surface[files] (declared options accepted, rc=" _rc ")"

* Part 9 is hand-written per command rather than a loop over surface.yml, so a newly
* declared command does not get a case for free. Part 11 exercises each of these five
* options, but never all five at once, which is the combination this Part exists to
* pin. `ROOT' is a real library and explorer applies no library test, so it opens fine.
local ++total
capture quietly datalib_explorer, root("`ROOT'") path(ZWE) files sizes maxitems(50)
if (_rc==198) {
    di as err "FAIL surface[explorer]: rc=198 - a declared option was rejected."
    local ++fails
}
else di as txt "pass surface[explorer] (declared options accepted, rc=" _rc ")"

local ++total
capture quietly datalib_catalog, country(ZWE) root("`ROOT'") clear
if (_rc==198) {
    di as err "FAIL surface[catalog]: rc=198 - a declared option was rejected."
    local ++fails
}
else di as txt "pass surface[catalog] (declared options accepted, rc=" _rc ")"

local ++total
capture quietly datalib_root, root("`ROOT'") find set
if (_rc==198) {
    di as err "FAIL surface[root]: rc=198 - a declared option was rejected."
    local ++fails
}
else di as txt "pass surface[root] (declared options accepted, rc=" _rc ")"

local ++total
* NOTE datalib_browse's path() takes a library TOKEN (ZWE, ZWE_2019_MICS), not a
* filesystem path -- it is tokenised on "_" and matched, not opened. Passing an
* absolute path here returned rc 198, which is why this part must use VALID
* values: Stata's 198 conflates "option not allowed" with "invalid value", so a
* live probe corroborates the parse but cannot be the authoritative check. That
* remains the text parse plus each .sthlp Syntax section.
capture quietly datalib_browse, country(ZWE) path(ZWE_2019_MICS) root("`ROOT'") nodisplay
if (_rc==198) {
    di as err "FAIL surface[browse]: rc=198 - a declared option was rejected."
    local ++fails
}
else di as txt "pass surface[browse] (declared options accepted, rc=" _rc ")"

* -create- is passed so the flag itself is proven accepted; it writes into a
* scratch root that is removed below, never into the fixture.
local ++total
capture quietly datalib_create, country(ZWE) year(2030) survey(MICS) ///
    kind(master) collection(HLT) master_version(1) adaptation_version(1) ///
    create root("`p9new'")
if (_rc==198) {
    di as err "FAIL surface[create]: rc=198 - a declared option was rejected."
    local ++fails
}
else di as txt "pass surface[create] (declared options accepted, rc=" _rc ")"

* filename() is passed EMPTY: that proves -syntax- accepts the option without
* changing what the command does, which is all this part is asserting.
local ++total
capture quietly datalib_load, country(ZWE) year(2019) survey(MICS) ///
    kind(adaptation) collection(HLT) master_version(2) adaptation_version(1) ///
    modules(household) filename() nomerge debug clear root("`ROOT'")
if (_rc==198) {
    di as err "FAIL surface[load]: rc=198 - a declared option was rejected."
    local ++fails
}
else di as txt "pass surface[load] (declared options accepted, rc=" _rc ")"

di as txt "  (11 commands probed live; datalib_config and datalib_map_drive are"
di as txt "   corroborated by getuserconfig.sthlp / mapzdrive.sthlp instead)"

capture rmdir `"`p9new'/ZWE/ZWE_2030_MICS/ZWE_2030_MICS_v01_M/Data/Original"'
capture rmdir `"`p9new'/ZWE/ZWE_2030_MICS/ZWE_2030_MICS_v01_M/Data/Stata"'
capture rmdir `"`p9new'/ZWE/ZWE_2030_MICS/ZWE_2030_MICS_v01_M/Data/R"'
capture rmdir `"`p9new'/ZWE/ZWE_2030_MICS/ZWE_2030_MICS_v01_M/Data/Other"'
capture rmdir `"`p9new'/ZWE/ZWE_2030_MICS/ZWE_2030_MICS_v01_M/Data"'
capture rmdir `"`p9new'/ZWE/ZWE_2030_MICS/ZWE_2030_MICS_v01_M/Doc"'
capture rmdir `"`p9new'/ZWE/ZWE_2030_MICS/ZWE_2030_MICS_v01_M/Programs"'
capture rmdir `"`p9new'/ZWE/ZWE_2030_MICS/ZWE_2030_MICS_v01_M"'
capture rmdir `"`p9new'/ZWE/ZWE_2030_MICS"'
capture rmdir `"`p9new'/ZWE"'
capture rmdir `"`p9new'"'

*------------------------------------------------------------------------------*
* Part 10 - -datalib , update- (package maintenance).
*
* Hermetic: the fake net sites below contain a stata.toc and nothing else, so no
* real -net install- can run. The version-comparison cases do not hardcode a
* version for the installed package (which differs per machine, and may be absent
* entirely): each case recomputes the expected verdict NUMERICALLY from
* r(installed) and the site version, then asserts r(status) agrees. That tests the
* comparison against an independent computation rather than against a constant.
*------------------------------------------------------------------------------*
di as result _n "Part 10 - datalib , update"

local UB = subinstr(`"`c(tmpdir)'"', "\", "/", .)
if (substr(`"`UB'"', -1, 1)=="/") local UB = substr(`"`UB'"', 1, strlen(`"`UB'"')-1)

capture program drop _u_mktoc
program define _u_mktoc
    args dir ver
    capture mkdir `"`dir'"'
    tempname fh
    quietly {
        file open `fh' using `"`dir'/stata.toc"', write text replace
        file write `fh' "v 3" _n
        file write `fh' "d DATALIB conformance fixture" _n
        file write `fh' `"d Version `ver' | 2026-07-26"' _n
        file write `fh' "p datalib" _n
        file close `fh'
    }
end

* u01 - a source with no stata.toc cannot be compared, and must not error
capture mkdir `"`UB'/dl_u_none"'
local ++total
capture datalib, update netsource(`"`UB'/dl_u_none"')
if (_rc!=0) | ("`r(status)'"!="unknown") | (`"`r(source_version)'"'!="") {
    di as err "FAIL u01: rc=" _rc " status=`r(status)' srcver=[`r(source_version)']."
    local ++fails
}
else di as txt "pass u01 (no stata.toc -> status unknown, rc 0)"

* u02 - netsource() outranks every other source of the net site
local ++total
_u_mktoc `"`UB'/dl_u_new"' "9.9.9"
capture datalib, update netsource(`"`UB'/dl_u_new"')
if (`"`r(source)'"'!=`"`UB'/dl_u_new"') {
    di as err `"FAIL u02: r(source)=`r(source)', expected `UB'/dl_u_new."'
    local ++fails
}
else di as txt "pass u02 (netsource() outranks the recorded source)"

* u03 - update must work with NO library configured: the machine most likely to
* need an update is the one not yet set up.
local dlsave `"${datalib}"'
local dcsave `"${datalib_checked}"'
global datalib ""
global datalib_checked ""
local ++total
capture datalib, update netsource(`"`UB'/dl_u_new"')
if (_rc!=0) {
    di as err "FAIL u03: rc=" _rc " with no library configured (expected 0)."
    local ++fails
}
else di as txt "pass u03 (no library needed to check for updates)"
global datalib `"`dlsave'"'
global datalib_checked `"`dcsave'"'

* u04/u05/u06 - the verdict, recomputed independently. "0.9.10" vs "0.9.9" is the
* trap: as TEXT 0.9.10 sorts below 0.9.9, so a string compare gets it backwards.
foreach sv in 9.9.9 0.5.0 0.9.10 {
    _u_mktoc `"`UB'/dl_u_v"' "`sv'"
    capture datalib, update netsource(`"`UB'/dl_u_v"')
    local iv `"`r(installed)'"'
    local got "`r(status)'"

    local want "unknown"
    if (`"`iv'"'!="unknown") {
        local inum 0
        local snum 0
        forvalues k = 1/3 {
            local iw = real(word(subinstr(`"`iv'"', ".", " ", .), `k'))
            local sw = real(word(subinstr("`sv'",   ".", " ", .), `k'))
            if (`iw'>=.) local iw 0
            if (`sw'>=.) local sw 0
            local inum = `inum'*1000 + `iw'
            local snum = `snum'*1000 + `sw'
        }
        if (`snum' > `inum')      local want "newer_available"
        else if (`snum' < `inum') local want "source_behind"
        else                      local want "current"
    }
    local ++total
    if ("`got'"!="`want'") {
        di as err "FAIL u-cmp[`sv']: installed=`iv' site=`sv' -> got `got', expected `want'."
        local ++fails
    }
    else di as txt "pass u-cmp[`sv'] (installed=`iv' vs site=`sv' -> `got')"
}

* u07 - installing from an OLDER source is refused without -force-. This is the
* case that matters: a stale net site once downgraded a working install here and
* reinstated a data mutation contract v1 forbids.
_u_mktoc `"`UB'/dl_u_old"' "0.0.1"
capture datalib, update netsource(`"`UB'/dl_u_old"')
local ivx `"`r(installed)'"'
if (`"`ivx'"'=="unknown") {
    di as txt "skip u07 (no version recorded for the installed package on this machine)"
    local ++skips
}
else {
    local ++total
    capture datalib, update install netsource(`"`UB'/dl_u_old"')
    if (_rc!=198) {
        di as err "FAIL u07: install from an older source returned rc=" _rc " (expected 198)."
        local ++fails
    }
    else di as txt "pass u07 (downgrade refused, rc 198, nothing installed)"
}

*------------------------------------------------------------------------------*
* u08-u14 - the REMEMBERED source (PLUS/datalib_netsource.txt).
*
* These need a writable PLUS, and must not touch the operator's real one: the
* memory file describes a real install, so a test that wrote into it would
* re-point the machine running the tests. So PLUS is redirected to a temp tree
* for the duration and restored unconditionally afterwards. Only -_dl_update- is
* called while it is redirected -- it is already loaded, so no ado lookup has to
* succeed against the fake PLUS.
*------------------------------------------------------------------------------*
local plus_saved `"`c(sysdir_plus)'"'
capture mkdir `"`UB'/dl_u_plus"'
capture noisily {
    sysdir set PLUS `"`UB'/dl_u_plus"'
    local FP = subinstr(`"`c(sysdir_plus)'"', "\", "/", .)

    * a trk recording one source, and a memory file naming a different one, so
    * precedence between the two is observable rather than inferred
    tempname th
    file open `th' using `"`FP'stata.trk"', write text replace
    file write `th' "S Z:/dl_u_from_trk" _n
    file write `th' "N datalib.pkg" _n
    file write `th' "d Version 0.0.1" _n
    file write `th' "f d/datalib.ado" _n
    file close `th'

    capture program drop _u_remember
    program define _u_remember
        args plusdir value
        tempname mh
        quietly {
            file open `mh' using `"`plusdir'datalib_netsource.txt"', write text replace
            file write `mh' `"`value'"' _n
            file close `mh'
        }
    end

    * u08 - TRANSITION: a trk-recorded legacy root redirects to the canonical one
    * and says so; an EXPLICIT netsource() is never redirected, because naming a
    * root is an instruction, not a legacy artefact.
    *
    * Written into the fake trk rather than read off the real machine. It used to
    * be guarded on "does this machine still record the legacy root?", which meant
    * it stopped running the moment the migration it tests actually succeeded --
    * dead coverage exactly when the code path still has to keep working for
    * everyone who has not migrated yet.
    tempname t8
    file open `t8' using `"`FP'stata.trk"', write text replace
    file write `t8' "S Z:/_statapkg" _n
    file write `t8' "N datalib.pkg" _n
    file write `t8' "d Version 0.0.1" _n
    file write `t8' "f d/datalib.ado" _n
    file close `t8'
    capture erase `"`FP'datalib_netsource.txt"'
    local ++total
    capture confirm file "Z:/_pkg/datalib/stata/stata.toc"
    if (_rc!=0) {
        local ++skips
        di as txt "skip u08 (canonical root unreadable from this machine)"
    }
    else {
        capture _dl_update
        local m1 = r(migrated)
        local s1 `"`r(source)'"'
        capture _dl_update, netsource("Z:/_statapkg")
        local m2 = r(migrated)
        local s2 `"`r(source)'"'
        if (`m1'!=1) | (`"`s1'"'!="Z:/_pkg/datalib/stata") | (`m2'!=0) | (`"`s2'"'!="Z:/_statapkg") {
            di as err "FAIL u08: bare -> migrated=`m1' src=`s1' ; explicit -> migrated=`m2' src=`s2'."
            local ++fails
        }
        else di as txt "pass u08 (legacy recorded source redirects; explicit netsource() does not)"
    }

    * back to a trk recording a non-legacy source, so u09-u14 measure precedence
    * rather than the redirect
    tempname t9
    file open `t9' using `"`FP'stata.trk"', write text replace
    file write `t9' "S Z:/dl_u_from_trk" _n
    file write `t9' "N datalib.pkg" _n
    file write `t9' "d Version 0.0.1" _n
    file write `t9' "f d/datalib.ado" _n
    file close `t9'

    * u09 - the remembered source outranks the trk record
    _u_remember `"`FP'"' "Z:/dl_u_from_memory"
    local ++total
    capture _dl_update
    if (`"`r(source)'"'!="Z:/dl_u_from_memory") | ///
       (`"`r(remembered_source)'"'!="Z:/dl_u_from_memory") | ///
       (`"`r(recorded_source)'"'!="Z:/dl_u_from_trk") {
        di as err `"FAIL u09: source=`r(source)' remembered=`r(remembered_source)' trk=`r(recorded_source)'."'
        local ++fails
    }
    else di as txt "pass u09 (remembered source outranks the trk record)"

    * u10 - THE DESIGN ASSERTION. A remembered legacy root is a record, not an
    * instruction, so it is migrated forward exactly as a trk record is. If this
    * ever fails, the next move of the net site can no longer complete by itself
    * and every machine has to be re-pointed by hand.
    _u_remember `"`FP'"' "Z:/_statapkg"
    local ++total
    capture confirm file "Z:/_pkg/datalib/stata/stata.toc"
    if (_rc!=0) {
        local ++skips
        di as txt "skip u10 (canonical root unreadable from this machine)"
    }
    else {
        capture _dl_update
        if (r(migrated)!=1) | (`"`r(source)'"'!="Z:/_pkg/datalib/stata") {
            di as err `"FAIL u10: remembered legacy root not migrated (migrated=`=r(migrated)' source=`r(source)')."'
            local ++fails
        }
        else di as txt "pass u10 (a remembered legacy root is still migrated forward)"
    }

    * u11 - but an explicit netsource() still outranks the memory
    local ++total
    capture _dl_update, netsource("Z:/dl_u_explicit")
    if (`"`r(source)'"'!="Z:/dl_u_explicit") | (r(migrated)!=0) {
        di as err `"FAIL u11: netsource() did not outrank the memory (source=`r(source)')."'
        local ++fails
    }
    else di as txt "pass u11 (explicit netsource() outranks the remembered source)"

    *--------------------------------------------------------------------------*
    * u12-u14 - WHICH RECORD SAYS WHAT IS INSTALLED.
    *
    * net install appends a trk entry only when it copies something, so the trk
    * version can lag the files on disk. Our own stamp covers that gap -- but the
    * rule has to be recency, not "the higher version wins", or a deliberate
    * downgrade done with plain -net install- becomes invisible. The trk is
    * append-only, so its entry count answers "did anything install after we wrote
    * our stamp?" The fake trk here holds ONE entry (0.0.1), so a stamp claiming
    * count 1 is contemporaneous and count 0 is older than the trk.
    *--------------------------------------------------------------------------*
    capture program drop _u_stamp
    program define _u_stamp
        args plusdir src ver n
        tempname mh
        quietly {
            file open `mh' using `"`plusdir'datalib_netsource.txt"', write text replace
            file write `mh' `"`src'"' _n
            file write `mh' `"`ver'"' _n
            file write `mh' `"`n'"' _n
            file close `mh'
        }
    end

    * u12 - the trk has recorded nothing since our stamp: our version is used,
    * and the disagreement with the trk is reported rather than swallowed
    _u_stamp `"`FP'"' "Z:/dl_u_from_memory" "0.9.18" 1
    local ++total
    capture _dl_update
    if (`"`r(installed)'"'!="0.9.18") | ("`r(version_from)'"!="stamp") | ///
       (`"`r(recorded_version)'"'!="0.0.1") {
        di as err `"FAIL u12: installed=`r(installed)' from=`r(version_from)' trk=`r(recorded_version)'."'
        local ++fails
    }
    else di as txt "pass u12 (stamp carries the version when the trk recorded nothing since)"

    * u13 - THE DOWNGRADE GUARD. The trk has grown since our stamp, so something
    * installed by other means afterwards and the trk is the newer fact -- even
    * though its version is LOWER. "Prefer the higher version" fails here, which
    * is why it is not the rule: this is how a stale-snapshot downgrade would be
    * hidden, and refusing to hide that is the reason this command exists.
    _u_stamp `"`FP'"' "Z:/dl_u_from_memory" "0.9.18" 0
    local ++total
    capture _dl_update
    if (`"`r(installed)'"'!="0.0.1") | ("`r(version_from)'"!="trk") {
        di as err `"FAIL u13: installed=`r(installed)' from=`r(version_from)' (expected 0.0.1 from trk)."'
        local ++fails
    }
    else di as txt "pass u13 (a later trk entry outranks a higher remembered version)"

    * u14 - a 0.9.17-era one-line stamp still supplies the source, and falls back
    * to the trk for the version rather than guessing
    _u_remember `"`FP'"' "Z:/dl_u_from_memory"
    local ++total
    capture _dl_update
    if (`"`r(source)'"'!="Z:/dl_u_from_memory") | (`"`r(installed)'"'!="0.0.1") | ///
       ("`r(version_from)'"!="trk") | (`"`r(remembered_version)'"'!="") {
        di as err `"FAIL u14: source=`r(source)' installed=`r(installed)' from=`r(version_from)'."'
        local ++fails
    }
    else di as txt "pass u14 (one-line legacy stamp: source honoured, version from the trk)"

}
local rc_plus = _rc
sysdir set PLUS `"`plus_saved'"'
if (`rc_plus'!=0) {
    di as err "FAIL u09-u14: the block errored (rc=`rc_plus') before completing."
    local ++fails
}
* u15 - no false alarm in the ordinary case: the adopath resolves datalib.ado to
* the PLUS copy being reported on, so nothing is shadowed. A warning that always
* fires is a warning nobody reads.
local ++total
capture _dl_update, netsource("Z:/_pkg/datalib/stata")
if (r(shadowed)!=0) {
    di as err `"FAIL u15: false shadow alarm (running_from=`r(running_from)', plus=`r(installed_from)')."'
    local ++fails
}
else di as txt "pass u15 (no shadow warning when the installed copy is the one on the adopath)"

* u17-u19 - the memory-vs-disk check, which is a different hazard from u15/u16.
*
* u15/u16 are about PLACE: the adopath resolving datalib somewhere other than the copy
* being reported on. This is about TIME: the right file, loaded before -net install-
* replaced it. Stata compiles an ado into memory on first use and -net install- does not
* invalidate that, so after an install without -discard- every disk-based indicator --
* `which datalib', the trk, the `*!' stamp -- reports the new version while the session
* keeps executing the old code. Demonstrated with a throwaway package: write zzstale.ado
* at v1, run it, overwrite the file at v2, and -which- says v2 while the program still
* prints v1.
*
* running() is the caller's own compiled-in literal, so a stale front door passes a stale
* value and the mismatch is what gets detected.
capture _dl_update, netsource("Z:/_pkg/datalib/stata")
local u17inst `"`r(installed)'"'
if (`"`u17inst'"'=="") | (`"`u17inst'"'=="unknown") {
    di as txt "skip u17-u19 (no installed version to compare against)"
    local skips = `skips' + 3
    local total = `total' + 3
}
else {
    * u17 - no false alarm when the session matches disk. A warning that fires every
    * time is a warning nobody reads, and it would take the true positives with it.
    local ++total
    capture _dl_update, netsource("Z:/_pkg/datalib/stata") running(`"`u17inst'"')
    if (r(stale)!=0) {
        di as err `"FAIL u17: false stale alarm (running=`r(running)', installed=`r(installed)')."'
        local ++fails
    }
    else di as txt "pass u17 (session matching disk is not reported stale)"

    * u18 - the hazard itself. 0.0.1 can never be what is installed.
    local ++total
    capture _dl_update, netsource("Z:/_pkg/datalib/stata") running(0.0.1)
    if (r(stale)!=1) | (`"`r(running)'"'!="0.0.1") {
        di as err `"FAIL u18: stale=`r(stale)' running=[`r(running)'] (want 1 and 0.0.1)."'
        local ++fails
    }
    else di as txt "pass u18 (a session behind the disk copy is detected and named)"

    * u19 - an older front door passes no running(), and then there is nothing to
    * compare. Report nothing rather than guess: claiming a stale session on the
    * strength of a missing argument would be the false alarm u17 guards against.
    local ++total
    capture _dl_update, netsource("Z:/_pkg/datalib/stata")
    if (r(stale)!=0) | (`"`r(running)'"'!="") {
        di as err `"FAIL u19: stale=`r(stale)' running=[`r(running)'] with no running() (want 0 and empty)."'
        local ++fails
    }
    else di as txt "pass u19 (no running() -> no claim either way)"
}

* u16 - THE HAZARD ITSELF: a clone prepended to the adopath shadows the installed
* package, so every version reported describes files this session will not run.
* Reproduced the way it actually happens -- -adopath ++- on a directory holding
* datalib.ado -- and NOT by redirecting PLUS, which was the first attempt: -sysdir
* set PLUS- replaces PLUS on the adopath instead of leaving the real one behind, so
* findfile then finds nothing at all and the command correctly declines to claim
* shadowing. That made the case pass for the wrong reason in one direction and fail
* in the other.
local ado_saved `"`c(adopath)'"'
local CLONE = subinstr(`"`c(pwd)'"', "\", "/", .) + "/stata/src/d"
capture confirm file `"`CLONE'/datalib.ado"'
if (_rc!=0) {
    local ++skips
    di as txt "skip u16 (no clone copy of datalib.ado at `CLONE')"
}
else {
    local ++total
    quietly adopath ++ `"`CLONE'"'
    capture _dl_update, netsource("Z:/_pkg/datalib/stata")
    local sh = r(shadowed)
    local rf `"`r(running_from)'"'
    quietly adopath - `"`CLONE'"'
    if (`sh'!=1) | (strpos(lower(`"`rf'"'), lower(`"`CLONE'"'))!=1) {
        di as err `"FAIL u16: shadowed=`sh' running_from=`rf' (expected 1, under `CLONE')."'
        local ++fails
    }
    else di as txt "pass u16 (a clone shadowing the install is detected and named)"
}

capture program drop _u_remember
capture program drop _u_stamp
foreach f in stata.trk datalib_netsource.txt {
    capture erase `"`UB'/dl_u_plus/`f'"'
}
capture rmdir `"`UB'/dl_u_plus"'

capture program drop _u_mktoc
foreach d in dl_u_none dl_u_new dl_u_v dl_u_old {
    capture confirm file `"`UB'/`d'/stata.toc"'
    if (_rc==0) erase `"`UB'/`d'/stata.toc"'
    capture rmdir `"`UB'/`d'"'
}

*------------------------------------------------------------------------------*
* Part 11 - datalib_explorer (arbitrary-tree navigation).
*
* Hermetic by construction: a throwaway tree under c(tmpdir) carrying the two
* properties that actually caused bugs while this was written -- a folder name with a
* SPACE in it, and mixed casing that Stata's `: dir' would flatten. Nothing here needs
* Z: to be mounted; the single case that would is guarded and skips.
*------------------------------------------------------------------------------*
di as result _n "Part 11 - datalib_explorer"

local XB = subinstr(`"`c(tmpdir)'"', "\", "/", .)
if (substr(`"`XB'"', -1, 1)=="/") local XB = substr(`"`XB'"', 1, strlen(`"`XB'"')-1)
local XR `"`XB'/dl_explore"'
capture mkdir `"`XR'"'
foreach d in "Afghanistan" "Zed Land" "SLV" {
    capture mkdir `"`XR'/`d'"'
}
capture mkdir `"`XR'/Afghanistan/2010 SDHS"'
capture mkdir `"`XR'/Afghanistan/2010 SDHS/Raw Datasets"'
capture mkdir `"`XR'/SLV/SLV_2014_MICS"'
* two files at the root, so n_files and exts have something to find
tempname xf
foreach f in "notes.txt" "table.DTA" {
    capture file close `xf'
    capture file open `xf' using `"`XR'/`f'"', write text replace
    if (_rc==0) {
        file write `xf' "x" _n
        capture file close `xf'
    }
}

* x01 - the tree opens, and it opens whether or not it is a library.
*
* NOTE the fixture root DOES satisfy _dl_islib, because it contains SLV/SLV_2014_MICS
* -- the ???/???_* country pair the library test looks for. That branch is needed by
* x07, so rather than remove it the not-a-library claim is asserted where it is
* actually true: Afghanistan/ holds "2010 SDHS", which is no country pair at all.
local ++total
capture datalib_explorer, root(`"`XR'"')
local rc1 = _rc
local nd1 = r(n_dirs)
local dp1 = r(depth)
capture _dl_islib `"`XR'/Afghanistan"'
local notlib = (r(islib)==0)
capture datalib_explorer, root(`"`XR'/Afghanistan"')
local rc2 = _rc
local nd2 = r(n_dirs)
if (`rc1'!=0) | (`nd1'!=3) | (`dp1'!=0) | (`rc2'!=0) | (!`notlib') | (`nd2'!=1) {
    di as err "FAIL x01: root rc=`rc1' n_dirs=`nd1' depth=`dp1' ; non-library rc=`rc2' islib0=`notlib' n_dirs=`nd2'"
    local ++fails
}
else di as txt "pass x01 (opens a library root AND a non-library directory)"

* x02 - casing preserved. `: dir' lowercases on Windows; explorer must not. This is
* the reason it reads the directory through Mata rather than the macro extension.
local ++total
local viaMacro : dir `"`XR'"' dirs "*"
capture datalib_explorer, root(`"`XR'"')
local viaExp `"`r(dirs)'"'
local hasUpper 0
foreach d of local viaExp {
    if (`"`d'"'=="Afghanistan") local hasUpper 1
}
local macroLower 0
foreach d of local viaMacro {
    if (`"`d'"'=="afghanistan") local macroLower 1
}
if (!`hasUpper') {
    di as err `"FAIL x02: explorer lost the casing -- got [`viaExp']"'
    local ++fails
}
else di as txt "pass x02 (casing preserved; `: dir' lowercased=`macroLower')"

* x03 - a folder name containing a SPACE round-trips through path()
local ++total
capture datalib_explorer, root(`"`XR'"') path("Afghanistan/2010 SDHS")
if (_rc!=0) | (`"`r(path)'"'!="Afghanistan/2010 SDHS") | (r(n_dirs)!=1) {
    di as err `"FAIL x03: rc=`=_rc' path=[`r(path)'] n_dirs=`=r(n_dirs)'"'
    local ++fails
}
else di as txt "pass x03 (a space in a folder name survives path())"

* x04 - parent and depth are consistent, so a caller can walk back up
local ++total
capture datalib_explorer, root(`"`XR'"') path("Afghanistan/2010 SDHS/Raw Datasets")
local d3 = r(depth)
local p3 `"`r(parent)'"'
capture datalib_explorer, root(`"`XR'"') path("Afghanistan")
local d1 = r(depth)
local p1 `"`r(parent)'"'
if (`d3'!=3) | (`"`p3'"'!="Afghanistan/2010 SDHS") | (`d1'!=1) | (`"`p1'"'!=".") {
    di as err `"FAIL x04: depth3=`d3' parent3=[`p3'] depth1=`d1' parent1=[`p1']"'
    local ++fails
}
else di as txt "pass x04 (depth and parent let a caller walk back up)"

* x05 - r(bytes) is -1 when sizes was NOT asked for. Zero is a real answer for an
* empty node, so a caller must be able to tell "no bytes" from "not measured".
local ++total
capture datalib_explorer, root(`"`XR'"')
local b_off = r(bytes)
capture datalib_explorer, root(`"`XR'"') sizes
local b_on = r(bytes)
if (`b_off'!=-1) | (`b_on' < 0) {
    di as err "FAIL x05: bytes without sizes=`b_off' (want -1), with sizes=`b_on' (want >=0)"
    local ++fails
}
else di as txt "pass x05 (bytes -1 = not measured, `b_on' with sizes)"

* x06 - extensions are lowercased and dot-free, and come free from the name
local ++total
capture datalib_explorer, root(`"`XR'"') files
local ex `"`r(exts)'"'
local nf = r(n_files)
local w1 dta
local w2 txt
if (`nf'!=2) | (!`:list w1 in ex') | (!`:list w2 in ex') {
    di as err `"FAIL x06: n_files=`nf' exts=[`ex'] (want dta and txt)"'
    local ++fails
}
else di as txt `"pass x06 (n_files=2, exts=[`ex'] lowercased)"'

* x07 - looks_grammar separates a renamed branch from an untouched one, which is what
* a migration needs in a mixed tree
local ++total
capture datalib_explorer, root(`"`XR'"') path("SLV/SLV_2014_MICS")
local g1 = r(looks_grammar)
capture datalib_explorer, root(`"`XR'"') path("Zed Land")
local g0 = r(looks_grammar)
if (`g1'!=1) | (`g0'!=0) {
    di as err "FAIL x07: SLV_2014_MICS=`g1' (want 1), 'Zed Land'=`g0' (want 0)"
    local ++fails
}
else di as txt "pass x07 (grammar detected on one branch, not the other)"

* x08 - maxitems caps the listing and says so
local ++total
capture datalib_explorer, root(`"`XR'"') maxitems(1)
local tr = r(truncated)
local nd = r(n_dirs)
if (`tr'!=1) | (`nd'!=3) {
    di as err "FAIL x08: truncated=`tr' (want 1), n_dirs=`nd' (want the true 3)"
    local ++fails
}
else di as txt "pass x08 (listing capped, n_dirs still reports the true total)"

* x12 - the FILE cap. x08 pinned the directory cap and passed, which is why this went
* unnoticed: the two lists were capped by different amounts of code. Five files, cap of
* two -- r(n_files) must stay the true 5, r(files) must hold 2, r(truncated) must fire.
local ++total
capture mkdir `"`XR'/manyf"'
forvalues i = 1/5 {
    capture file close `xf'
    capture file open `xf' using `"`XR'/manyf/f`i'.txt"', write text replace
    if (_rc==0) {
        file write `xf' "123456789" _n
        capture file close `xf'
    }
}
capture datalib_explorer, root(`"`XR'"') path(manyf) files maxitems(2)
local nf12 = r(n_files)
local tr12 = r(truncated)
local ct12 : word count `r(files)'
if (`nf12'!=5) | (`ct12'!=2) | (`tr12'!=1) {
    di as err "FAIL x12: n_files=`nf12' (want 5) stored=`ct12' (want 2) truncated=`tr12' (want 1)"
    local ++fails
}
else di as txt "pass x12 (file listing capped; n_files still the true total; truncated set)"

* x13 - and r(bytes) must agree with what r(files) HOLDS, not with a silent prefix of a
* longer list. Before the fix this returned 20 for a 50-byte node with truncated=0, so a
* caller walking a tree and summing r(bytes) got a quietly short number with nothing to
* check. 10 bytes per file here ("123456789" plus the line terminator), so two listed
* files is 20 and all five would be 50 -- the assertion distinguishes the two.
local ++total
capture datalib_explorer, root(`"`XR'"') path(manyf) files sizes maxitems(2)
local b13 = r(bytes)
local tr13 = r(truncated)
capture datalib_explorer, root(`"`XR'"') path(manyf) files sizes maxitems(400)
local bAll = r(bytes)
local trAll = r(truncated)
if (`b13'>=`bAll') | (`tr13'!=1) | (`trAll'!=0) | (`bAll'<=0) {
    di as err "FAIL x13: capped bytes=`b13' truncated=`tr13'; uncapped bytes=`bAll' truncated=`trAll'"
    di as err "          capped total must be STRICTLY less, and only the capped call truncated."
    local ++fails
}
else di as txt "pass x13 (bytes describes the files listed: `b13' capped vs `bAll' whole)"

* Tear the node down HERE, not with the rest of the fixture: it is a fourth child of the
* root, and x10 asserts the root holds three. Leaving it alive made x10 fail on n_dirs=4
* -- a case that had passed for eleven runs, broken by a fixture added below it.
forvalues i = 1/5 {
    capture erase `"`XR'/manyf/f`i'.txt"'
}
capture rmdir `"`XR'/manyf"'

* x14 - THE SILENT-SWALLOW TRAP. `syntax [, FILES NOFILES ]' -- FILES first -- binds
* NEITHER local when the caller types `nofiles', and raises NO error: Stata reads it as the
* negation of FILES, which for a plain flag means "absent". Probed directly before this was
* believed. So declaration ORDER is load-bearing, and a reordering by someone tidying the
* syntax line would silently disable the option with every test still green. This case is
* the tripwire: it asserts `nofiles' actually SUPPRESSES.
*
* r(n_files) is the TRUE count either way, so asserting on it proves nothing: the first
* version of this case checked exactly that and would have passed with the order broken.
* r(listed) exists so the switch is observable at all.
local ++total
capture datalib_explorer, root(`"`XR'"')
local lst_on  = r(listed)
local nf_on   = r(n_files)
capture datalib_explorer, root(`"`XR'"') nofiles
local lst_off = r(listed)
local nf_off  = r(n_files)
if (`lst_on'!=1) | (`lst_off'!=0) | (`nf_on'!=2) | (`nf_off'!=2) {
    di as err "FAIL x14: listed default=`lst_on' nofiles=`lst_off' (want 1 and 0);" ///
        " n_files `nf_on'/`nf_off' (want 2 and 2 -- nofiles is display-only)"
    local ++fails
}
else di as txt "pass x14 (nofiles bound: r(listed) 1->0, and r() still returns all `nf_off' names)"

* x15 - a companion, and NOT the order tripwire: with the order broken `nofiles' returns rc
* 0 (swallowed) and `nofilez' returns 198, so this case would pass either way. x14 via
* r(listed) is what catches the regression. This one is still worth keeping: it pins that
* the option is spelled as documented and that a near-miss is refused rather than ignored.
local ++total
capture datalib_explorer, root(`"`XR'"') nofiles
local rc15 = _rc
capture datalib_explorer, root(`"`XR'"') nofilez
local rc15b = _rc
if (`rc15'!=0) | (`rc15b'==0) {
    di as err "FAIL x15: nofiles rc=`rc15' (want 0); nofilez rc=`rc15b' (want nonzero)"
    local ++fails
}
else di as txt "pass x15 (nofiles accepted, a near-miss spelling rejected)"

* x16 - paging slices the DISPLAY and nothing else. The distinction matters: maxitems()
* truncates -- the files past it are genuinely absent and r(truncated) says so -- whereas
* perpage() must leave every count and every returned list describing the whole node. A
* pager that quietly shrank r(n_files) would be the same silent-partial-answer defect this
* command shipped with in 0.9.21.
local ++total
capture datalib_explorer, root(`"`XR'"') perpage(1)
local nf16   = r(n_files)
local np16   = r(n_pages)
local pg16   = r(page)
local f16    = r(shown_first)
local l16    = r(shown_last)
local cnt16 : word count `r(files)'
if (`nf16'!=2) | (`np16'!=2) | (`pg16'!=1) | (`f16'!=1) | (`l16'!=1) | (`cnt16'!=2) {
    di as err "FAIL x16: n_files=`nf16' (want 2) n_pages=`np16' (want 2) page=`pg16'" ///
        " first=`f16' last=`l16' (want 1 and 1) r(files) count=`cnt16' (want 2)"
    local ++fails
}
else di as txt "pass x16 (perpage slices the display; counts and r(files) stay whole)"

* x17 - a page past the end CLAMPS rather than returning an empty listing. Asking for page
* 99 of 2 is a typo, and answering it with silence looks identical to an empty folder.
local ++total
capture datalib_explorer, root(`"`XR'"') perpage(1) page(99)
local pg17 = r(page)
local f17  = r(shown_first)
capture datalib_explorer, root(`"`XR'"') perpage(1) page(0)
local rc17 = _rc
if (`pg17'!=2) | (`f17'!=2) | (`rc17'==0) {
    di as err "FAIL x17: page(99)->`pg17' first=`f17' (want 2 and 2); page(0) rc=`rc17' (want nonzero)"
    local ++fails
}
else di as txt "pass x17 (page past the end clamps to `pg17'; page(0) refused)"

* x18 - the link dispatch. A hyperlink that does nothing is worse than plain text, so each
* bucket is pinned: Stata's own format, a text companion, something only the OS can open,
* and the one case that must NOT be linked at all.
* Read from the SHARED corpus, not from a list typed out here. R and Python assert the
* same file, so a bucket that moved in one leg and not the others fails everywhere
* instead of drifting quietly -- which is how datalib.sthlp came to sit five releases
* behind the code it documented.
local ++total
local bad18 0
local fkcases "tests/cases_filekind.csv"
capture confirm file "`fkcases'"
if (_rc!=0) {
    di as txt "skip x18 (tests/cases_filekind.csv not found)"
    local ++skips
}
else {
    preserve
    quietly import delimited using "`fkcases'", varnames(1) clear stringcols(_all)
    local nrows = _N
    if (`nrows' < 10) {
        di as err "FAIL x18: the corpus has only `nrows' rows -- an empty corpus passes silently"
        local ++bad18
    }
    forvalues i = 1/`nrows' {
        local e    = ext[`i']
        local want = kind[`i']
        local why  = why[`i']
        local nm = cond("`e'"=="none", "noext", "a.`e'")
        capture _dl_fileaction `"Z:/x/`nm'"'
        if (`"`r(kind)'"'!="`want'") {
            di as err `"FAIL x18: .`e' -> `r(kind)' (want `want'; `why')"'
            local ++bad18
        }
    }
    restore
}
* An ampersand is NOT refused: measured on the real archive it would have cost 406 of
* tens of thousands of files, and cmd only treats & as syntax OUTSIDE quotes -- verified by echoing it
* through cmd and reading it back intact. A double quote IS refused, because that is what
* actually breaks the quoting.
capture _dl_fileaction `"Z:/x/Health & Nutrition.xlsx"'
if (`"`r(kind)'"'!="open") {
    di as err `"FAIL x18: an ampersand must still be linked, got `r(kind)'"'
    local ++bad18
}
local ++total
if (`bad18' > 0) {
    local ++fails
    local ++fails
}
else di as txt "pass x18 (link dispatch matches the shared corpus; & still linked)"

* x09 - a missing node is 601, not a silent empty listing
local ++total
capture datalib_explorer, root(`"`XR'"') path("no/such/node")
if (_rc!=601) {
    di as err "FAIL x09: rc=" _rc " (want 601)"
    local ++fails
}
else di as txt "pass x09 (missing node -> rc 601)"

* x10 - the option form on the legacy surface reaches the same command
local ++total
capture datalib, explorer library(`"`XR'"')
if (_rc!=0) | (r(n_dirs)!=3) {
    di as err "FAIL x10: datalib , explorer rc=" _rc " n_dirs=" r(n_dirs)
    local ++fails
}
else di as txt "pass x10 (datalib , explorer dispatches to datalib_explorer)"

* x11 - explorer must NOT be a dispatcher subcommand: stata_subcommands is the 13
* canonical contract commands and the surface guard takes its meaning from that count
local ++total
capture datalib explorer
if (_rc==0) {
    di as err "FAIL x11: 'datalib explorer' dispatched -- it must stay an option, not a 14th subcommand"
    local ++fails
}
else di as txt "pass x11 (not a dispatcher subcommand; the 13 stay 13)"

capture erase `"`XR'/notes.txt"'
capture erase `"`XR'/table.DTA"'
forvalues i = 1/5 {
    capture erase `"`XR'/manyf/f`i'.txt"'
}
capture rmdir `"`XR'/manyf"'
foreach d in "Afghanistan/2010 SDHS/Raw Datasets" "Afghanistan/2010 SDHS" "SLV/SLV_2014_MICS" "Afghanistan" "Zed Land" "SLV" {
    capture rmdir `"`XR'/`d'"'
}
capture rmdir `"`XR'"'

*------------------------------------------------------------------------------*
* Part 12 - datalib_index (recursive walk -> dataset).
*
* Its own throwaway tree, three levels deep, with a space and mixed casing in the names --
* the two properties that broke explorer -- plus a file with no extension, because "none"
* is a value a caller will branch on.
*
* NOTE these cases replace the data in memory. They run last for that reason, and the
* harness's own state is restored by the cleanup block that follows.
*------------------------------------------------------------------------------*
di as result _n "Part 12 - datalib_index"

local IB = subinstr(`"`c(tmpdir)'"', "\", "/", .)
if (substr(`"`IB'"', -1, 1)=="/") local IB = substr(`"`IB'"', 1, strlen(`"`IB'"')-1)
local IR `"`IB'/dl_index"'
capture mkdir `"`IR'"'
capture mkdir `"`IR'/Alpha Land"'
capture mkdir `"`IR'/Alpha Land/Deep One"'
capture mkdir `"`IR'/Alpha Land/Deep One/Deeper"'
capture mkdir `"`IR'/BRA"'
tempname if1
foreach f in "top.txt" {
    capture file close `if1'
    capture file open `if1' using `"`IR'/`f'"', write text replace
    if (_rc==0) {
        file write `if1' "abc" _n
        capture file close `if1'
    }
}
foreach spec in "Alpha Land/mid.DTA" "Alpha Land/Deep One/Deeper/leaf.txt" "BRA/NOEXT" {
    capture file close `if1'
    capture file open `if1' using `"`IR'/`spec'"', write text replace
    if (_rc==0) {
        file write `if1' "abc" _n
        capture file close `if1'
    }
}

* i01 - the whole subtree in one call, which is the entire point: 4 files across 4 levels,
* reached without four separate commands.
local ++total
capture datalib_index, root(`"`IR'"') clear
if (_rc!=0) | (r(n_files)!=4) | (_N!=4) | (r(truncated)!=0) {
    di as err "FAIL ix01: rc=`=_rc' n_files=`=r(n_files)' rows=`=_N' truncated=`=r(truncated)' (want 0/4/4/0)"
    local ++fails
}
else di as txt "pass ix01 (whole subtree in one call: 4 files, 4 rows)"

* i02 - relpath keeps the separators, the spaces and the casing, so a caller can hand it
* straight back to explorer or to -use-.
local ++total
capture datalib_index, root(`"`IR'"') clear
quietly count if relpath=="Alpha Land/Deep One/Deeper/leaf.txt"
local hit1 = r(N)
quietly count if relpath=="Alpha Land/mid.DTA"
local hit2 = r(N)
if (`hit1'!=1) | (`hit2'!=1) {
    di as err "FAIL ix02: deep path found=`hit1', mixed-case path found=`hit2' (want 1 and 1)"
    local ++fails
}
else di as txt "pass ix02 (relpath keeps spaces, depth and casing)"

* i03 - depth and parent. leaf.txt is 4 levels below the root.
local ++total
capture datalib_index, root(`"`IR'"') clear
quietly count if relpath=="Alpha Land/Deep One/Deeper/leaf.txt" & depth==4 & parent=="Alpha Land/Deep One/Deeper"
local ok3 = r(N)
quietly count if relpath=="top.txt" & depth==1 & parent=="."
local ok3b = r(N)
if (`ok3'!=1) | (`ok3b'!=1) {
    di as err "FAIL ix03: deep row ok=`ok3', top-level row ok=`ok3b' (want 1 and 1)"
    local ++fails
}
else di as txt "pass ix03 (depth and parent let a caller rebuild the tree)"

* i04 - a file with no extension is "none", not empty. A caller branching on ext must be
* able to tell "no extension" from a folder row (which IS empty).
local ++total
capture datalib_index, root(`"`IR'"') dirs clear
quietly count if name=="NOEXT" & ext=="none" & is_dir==0
local ok4 = r(N)
quietly count if is_dir==1 & ext!=""
local bad4 = r(N)
if (`ok4'!=1) | (`bad4'!=0) {
    di as err "FAIL ix04: NOEXT->none=`ok4' (want 1); folder rows with an ext=`bad4' (want 0)"
    local ++fails
}
else di as txt "pass ix04 (no extension is 'none'; folders have none at all)"

* i05 - dirs adds folder rows without changing the file count.
local ++total
capture datalib_index, root(`"`IR'"') clear
local f5 = r(n_files)
local n5 = _N
capture datalib_index, root(`"`IR'"') dirs clear
local f5d = r(n_files)
local n5d = _N
if (`f5'!=`f5d') | (`n5d' <= `n5') | (`n5d' != `f5' + r(n_dirs)) {
    di as err "FAIL ix05: files `f5' vs `f5d'; rows `n5' vs `n5d'; n_dirs=`=r(n_dirs)'"
    local ++fails
}
else di as txt "pass ix05 (dirs adds folder rows, file count unchanged)"

* i06 - maxdepth stops the descent, and does NOT pretend to be complete.
local ++total
capture datalib_index, root(`"`IR'"') maxdepth(2) clear
quietly summarize depth, meanonly
local mx6 = r(max)
if (`mx6' > 2) {
    di as err "FAIL ix06: maxdepth(2) produced depth `mx6'"
    local ++fails
}
else di as txt "pass ix06 (maxdepth caps the descent at `mx6')"

* i07 - THE ONE THAT MATTERS. maxnodes must set r(truncated), because a short answer that
* looks complete is the defect explorer shipped with in 0.9.21 (r(bytes) was a silent
* partial sum). One node can only see the root's own files.
local ++total
capture datalib_index, root(`"`IR'"') maxnodes(1) clear
local t7 = r(truncated)
local f7 = r(n_files)
capture datalib_index, root(`"`IR'"') clear
local t7b = r(truncated)
local f7b = r(n_files)
if (`t7'!=1) | (`t7b'!=0) | (`f7' >= `f7b') {
    di as err "FAIL ix07: capped truncated=`t7' files=`f7'; full truncated=`t7b' files=`f7b'"
    di as err "          capped must be flagged AND strictly fewer files."
    local ++fails
}
else di as txt "pass ix07 (node cap flagged: `f7' files capped vs `f7b' whole)"

* i08 - bytes is MISSING without sizes, not zero, and r(bytes) is -1. Zero is a real size.
local ++total
capture datalib_index, root(`"`IR'"') clear
local rb8 = r(bytes)
quietly count if bytes<.
local nz8 = r(N)
capture datalib_index, root(`"`IR'"') sizes clear
local rb8s = r(bytes)
quietly count if bytes<.
local nz8s = r(N)
if (`rb8'!=-1) | (`nz8'!=0) | (`rb8s'<=0) | (`nz8s'==0) {
    di as err "FAIL ix08: no-sizes r(bytes)=`rb8' nonmissing=`nz8'; with sizes r(bytes)=`rb8s' nonmissing=`nz8s'"
    local ++fails
}
else di as txt "pass ix08 (bytes missing until measured; r(bytes) -1 vs `rb8s')"

* i09 - pattern filters files only. Folders must still be traversed or the walk could not
* reach a nested match at all -- which is the trap: filtering the traversal too would
* silently return nothing for a deep pattern.
local ++total
capture datalib_index, root(`"`IR'"') pattern(*.txt) clear
quietly count if ext=="txt"
local ok9 = r(N)
quietly count if ext!="txt"
local bad9 = r(N)
quietly count if relpath=="Alpha Land/Deep One/Deeper/leaf.txt"
local deep9 = r(N)
if (`ok9'==0) | (`bad9'!=0) | (`deep9'!=1) {
    di as err "FAIL ix09: txt=`ok9' non-txt=`bad9' deep-match-found=`deep9'"
    local ++fails
}
else di as txt "pass ix09 (pattern filters files, still descends to a deep match)"

* i10 - a missing node is 601, matching explorer rather than inventing a second convention.
local ++total
capture datalib_index, root(`"`IR'"') path("no/such/node") clear
if (_rc!=601) {
    di as err "FAIL ix10: rc=`=_rc' (want 601)"
    local ++fails
}
else di as txt "pass ix10 (missing node -> rc 601, same as explorer)"

* i11 - reachable from the legacy surface, and NOT as a 14th subcommand.
local ++total
capture datalib, index library(`"`IR'"') clear
local rc11 = _rc
local f11 = r(n_files)
capture datalib index
local rc11b = _rc
if (`rc11'!=0) | (`f11'!=4) | (`rc11b'==0) {
    di as err "FAIL ix11: option form rc=`rc11' files=`f11'; bare subcommand rc=`rc11b' (must be nonzero)"
    local ++fails
}
else di as txt "pass ix11 (datalib , index works; 'datalib index' is not a subcommand)"

capture erase `"`IR'/top.txt"'
capture erase `"`IR'/Alpha Land/mid.DTA"'
capture erase `"`IR'/Alpha Land/Deep One/Deeper/leaf.txt"'
capture erase `"`IR'/BRA/NOEXT"'
foreach d in "Alpha Land/Deep One/Deeper" "Alpha Land/Deep One" "Alpha Land" "BRA" {
    capture rmdir `"`IR'/`d'"'
}
capture rmdir `"`IR'"'
clear

* --- restore session state and clean up -------------------------------------
global datalib      `"`dl_saved'"'
global zDrive       `"`zd_saved'"'
global githubFolder `"`gh_saved'"'
global teamsRoot    `"`tr_saved'"'
global zDriveUNC    `"`zu_saved'"'
global datalib_checked ""   // session cache set by -datalib-; do not leak it
quietly cd `"`pwd_saved'"'
capture rmdir `"`TMP'/place/datalib"'
capture rmdir `"`TMP'/place"'
capture rmdir `"`TMP'/notalib"'
capture rmdir `"`TMP'"'

*------------------------------------------------------------------------------*
di as result _n "Conformance: `=`total'-`fails''/`total' passed, `skips' skipped."
if (`fails' > 0) {
    di as err "`fails' case(s) FAILED."
    exit 9
}
