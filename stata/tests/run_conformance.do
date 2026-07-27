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
