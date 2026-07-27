*******************************************************
* datalib_root: contract v1 library-root resolver
* Author: Joao Pedro Azevedo
*! v0.9.19
* Resolves the datalib root in the Stata precedence order documented in
* config/grammar.md: root() argument -> ${datalib} session global (which
* getuserconfig may have filled from the user_config datalib: key) ->
* env DATALIB_ROOT -> error 198. With -set-, also fills ${datalib}.
*
* DEFAULT behaviour is pure candidate selection, as in R and Python: the first
* non-empty candidate wins, WITHOUT touching the disk. r(source_stage) is one of
* the contract values argument/global/env.
*
* Stata returns the candidate as a LITERAL string. R and Python do not: R's
* fs::path_norm collapses "..", expands "~" and strips a trailing separator, and
* Python returns a Path whose Windows string form uses backslashes. So the three
* agree on the resolved DIRECTORY, not on its spelling -- the contract pins
* identity, not bytes (config/grammar.md section 7). Do not assert a returned
* root byte-for-byte against another language's.
*
* -find- opts in to the Stata-only convenience used by the -datalib- front end
* (see tests/DIVERGENCES.md and config/grammar.md section 7):
*   - each candidate is tested with _dl_islib, in precedence order, so a
*     candidate that is not a library never shadows a later one;
*   - a candidate may name the library OR the place that holds it: <cand>/datalib
*     is tried first (r(descended)=1), then <cand> itself;
*   - a candidate that is set but is not a library is an ERROR naming it -- the
*     root is never silently substituted, because provenance matters more than
*     convenience here;
*   - only when NO candidate is set at all is a library named "datalib"
*     discovered under ${zDrive} then Z:/ (r(source_stage)="discovered").
*******************************************************

capture program drop datalib_root
program define datalib_root, rclass

    version 15

    syntax [, root(string) FIND set ]

    quietly {
        * Ordered candidates and their contract source_stage names.
        local c1 `"`root'"'
        local s1 "argument"
        local c2 `"${datalib}"'
        local s2 "global"
        local c3 : environment DATALIB_ROOT
        local s3 "env"

        *----------------------------------------------------------------------
        * Contract default: first non-empty candidate wins, as a string.
        *----------------------------------------------------------------------
        * NB: a bare -exit- inside forvalues does NOT leave the program (it acts
        * like -continue-), so the pick is made in the loop and returned after it.
        if ("`find'"=="") {
            local pick  ""
            local stage ""
            forvalues i = 1/3 {
                if (`"`c`i''"'!="") {
                    local pick  `"`c`i''"'
                    local stage "`s`i''"
                    continue, break
                }
            }
            if (`"`pick'"'=="") {
                di as err "datalib root not set: pass root(), set global datalib, or set DATALIB_ROOT."
                exit 198
            }
            if ("`set'"!="") global datalib `"`pick'"'
            return local root         `"`pick'"'
            return local source_stage "`stage'"
            return scalar descended = 0
            exit
        }

        *----------------------------------------------------------------------
        * find: resolve against the disk, candidate by candidate, in order.
        *----------------------------------------------------------------------
        local found     ""
        local stage     ""
        local descended 0
        local badcand   ""
        local badexists 0
        forvalues i = 1/3 {
            if (`"`c`i''"'=="") continue
            _dl_islib `"`c`i''"'
            local cand `"`r(path)'"'
            * child first: the candidate may hold the library rather than be it
            local sep "/"
            if (substr(`"`cand'"', -1, 1)=="/") local sep ""
            _dl_islib `"`cand'`sep'datalib"'
            if (r(islib)==1) {
                local found     `"`r(path)'"'
                local stage     "`s`i''"
                local descended 1
                continue, break
            }
            _dl_islib `"`cand'"'
            if (r(islib)==1) {
                local found `"`r(path)'"'
                local stage "`s`i''"
                continue, break
            }
            * Set but not a library: stop here rather than trying a later
            * candidate. The root the operator named is never silently replaced.
            local badcand   `"`cand'"'
            local badexists = r(exists)
            continue, break
        }

        if (`"`badcand'"'!="") {
            noi di as err `"{p}No datalib library at: `badcand'{p_end}"'
            if (`badexists'==1) noi di as err `"{p}That directory exists but does not look like a library (no {bf:datalib} folder inside it, no country folders, no {bf:.datalib} marker).{p_end}"'
            noi di as err `"{p}Name the library for one call with {bf:library(}{it:path}{bf:)}, or for the session with {bf:datalib root, root(}{it:path}{bf:) set}.{p_end}"'
            exit 198
        }

        *----------------------------------------------------------------------
        * Discovery: only when nothing at all was configured.
        *----------------------------------------------------------------------
        local searched 0
        if (`"`found'"'=="") {
            local searched 1
            local b1 `"${zDrive}"'
            local b2 "Z:/"
            forvalues i = 1/2 {
                local b `"`b`i''"'
                if (`"`b'"'=="") continue
                _dl_islib `"`b'"'
                local base `"`r(path)'"'
                local sep "/"
                if (substr(`"`base'"', -1, 1)=="/") local sep ""
                _dl_islib `"`base'`sep'datalib"'
                if (r(islib)==1) {
                    local found     `"`r(path)'"'
                    local stage     "discovered"
                    local descended 1
                    continue, break
                }
            }
        }

        if (`"`found'"'=="") {
            if (`searched'==1) noi di as err `"{p}No datalib library found: nothing configured, and no library named {bf:datalib} under ${zDrive} or Z:/.{p_end}"'
            noi di as err `"{p}Name the library for one call with {bf:library(}{it:path}{bf:)}, or set it for the session with {bf:datalib root, root(}{it:path}{bf:) set} — or per machine via {bf:getuserconfig} (the {bf:datalib:} key), {bf:global datalib}, or the {bf:DATALIB_ROOT} environment variable.{p_end}"'
            exit 198
        }

        if ("`set'"!="") global datalib `"`found'"'
        return local root         `"`found'"'
        return local source_stage "`stage'"
        return scalar descended   = `descended'
    }

end
