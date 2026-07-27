*==============================================================================*
*! make_fixtures.do — (re)generate the synthetic conformance fixture library
*
* Builds tests/fixtures/library/: a tiny, committed datalib tree that every
* implementation (Stata, R, Python) runs the golden cases against.
* Regenerate only when the contract changes; fixture .dta files are committed
* binaries so all languages consume identical bytes.
*
* Tree:
*   ZWE/ZWE_2019_MICS/  v01_M (empty Data/Stata)  v02_M (household master file)
*                       v02_M_v01_A_HLT (4 modules)  v02_M_v01_A_IPUMS (hh, wm)
*   KEN/KEN_2014_DHS/   v01_M + v01_M_v01_A_HLT (4 modules)
*   KEN/KEN_2022_MICS/  v01_M_v01_A_HLT (4 modules; vintage has NO Doc/ dir)
*   BRA/BRA_2015_PNAD/  v09_M + v10_M (master household files; v09 saved via
*                       saveold version(11), which emits dta format 115)
*     -> pins numeric latest (v10 > v09), latest-year (KEN -> 2022), master loads
*
* HLT synthetic data (3 households A=(c1,h1) B=(c1,h2) C=(c2,h1); C has no
* interviewed persons): household 3 rows / hhmembers 6 / adult 3 / children 2.
* windex5 includes a value 8 (pins the no-recode contract) and is value-labelled.
* hhmembers carries hh_line_number (registry linevar), populated.
* (Note: -input- is not allowed inside programs, so rows are built with gen/cond.)
*==============================================================================*

version 15
clear all
set more off

* Run from the repo root or tests/fixtures — locate the library dir
capture confirm file "tests/fixtures/make_fixtures.do"
if !_rc     local LIB "tests/fixtures/library"
else        local LIB "library"

capture mkdir "`LIB'"

program define _fx_keep
    * git cannot track empty directories: drop a .gitkeep sentinel so the
    * committed fixture tree is identical on a fresh clone (CI!)
    args f
    tempname h
    capture file close `h'
    file open `h' using "`f'/.gitkeep", write replace
    file close `h'
end

program define _fx_dirs
    args base doc
    capture mkdir "`base'"
    capture mkdir "`base'/Data"
    foreach s in Original Stata R Other {
        capture mkdir "`base'/Data/`s'"
        _fx_keep "`base'/Data/`s'"
    }
    if ("`doc'"!="nodoc") {
        capture mkdir "`base'/Doc"
        _fx_keep "`base'/Doc"
    }
    capture mkdir "`base'/Programs"
    _fx_keep "`base'/Programs"
end

program define _fx_household
    args svy stem out old
    clear
    set obs 3
    gen str12 svy_id     = "`svy'"
    gen cluster_id       = cond(_n<=2, 1, 2)
    gen household_id     = cond(_n==2, 2, 1)
    gen line_number      = 1
    gen windex5          = cond(_n==1, 1, cond(_n==2, 8, 3))
    gen hh_size          = cond(_n==1, 3, cond(_n==2, 2, 1))
    gen str3 source      = "TST"
    label define wq5 1 "poorest" 3 "middle" 5 "richest" 8 "dk", replace
    label values windex5 wq5
    if ("`old'"=="old") saveold "`out'/`stem'_household.dta", version(11) replace
    else                save    "`out'/`stem'_household.dta", replace
end

program define _fx_hhmembers
    args svy stem out
    clear
    set obs 6
    gen str12 svy_id     = "`svy'"
    gen cluster_id       = cond(_n<=5, 1, 2)
    gen household_id     = cond(_n<=3, 1, cond(_n<=5, 2, 1))
    gen hh_line_number   = cond(_n<=3, _n, cond(_n<=5, _n-3, 1))
    gen sex              = cond(mod(_n,2)==1, 1, 2)
    gen str3 source      = "TST"
    save "`out'/`stem'_hhmembers.dta", replace
end

program define _fx_adult
    args svy stem out
    clear
    set obs 3
    gen str12 svy_id     = "`svy'"
    gen cluster_id       = 1
    gen household_id     = cond(_n<=2, 1, 2)
    gen line_number      = cond(_n==1, 1, cond(_n==2, 2, 1))
    gen age_in_years     = cond(_n==1, 34, cond(_n==2, 31, 46))
    gen str3 source      = "TST"
    save "`out'/`stem'_adult.dta", replace
end

program define _fx_children
    args svy stem out
    clear
    set obs 2
    gen str12 svy_id     = "`svy'"
    gen cluster_id       = 1
    gen household_id     = cond(_n==1, 1, 2)
    gen line_number      = cond(_n==1, 3, 2)
    gen child_age_years  = cond(_n==1, 4, 2)
    gen str3 source      = "TST"
    save "`out'/`stem'_children.dta", replace
end

program define _fx_hlt
    args svy stem out
    _fx_household "`svy'" "`stem'" "`out'"
    _fx_hhmembers "`svy'" "`stem'" "`out'"
    _fx_adult     "`svy'" "`stem'" "`out'"
    _fx_children  "`svy'" "`stem'" "`out'"
end

program define _fx_ipums_hh
    args svy stem out
    clear
    set obs 3
    gen str12 svy_id     = "`svy'"
    gen household_id     = _n
    gen hh_size          = 4 - _n
    gen str3 source      = "TST"
    save "`out'/`stem'_hh.dta", replace
end

program define _fx_ipums_wm
    args svy stem out
    clear
    set obs 2
    gen str12 svy_id     = "`svy'"
    gen household_id     = _n
    gen line_number      = 1
    gen age_in_years     = cond(_n==1, 29, 41)
    gen str3 source      = "TST"
    save "`out'/`stem'_wm.dta", replace
end

* ---------------- ZWE 2019 MICS ----------------
capture mkdir "`LIB'/ZWE"
capture mkdir "`LIB'/ZWE/ZWE_2019_MICS"
_fx_dirs "`LIB'/ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v01_M"
_fx_dirs "`LIB'/ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M"
_fx_household "ZWE2019MICS" "ZWE_2019_MICS_v02_M" "`LIB'/ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M/Data/Stata"
_fx_dirs "`LIB'/ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M_v01_A_HLT"
_fx_hlt "ZWE2019MICS" "ZWE_2019_MICS_v02_M_v01_A_HLT" "`LIB'/ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M_v01_A_HLT/Data/Stata"
_fx_dirs "`LIB'/ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M_v01_A_IPUMS"
_fx_ipums_hh "ZWE2019MICS" "ZWE_2019_MICS_v02_M_v01_A_IPUMS" "`LIB'/ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M_v01_A_IPUMS/Data/Stata"
_fx_ipums_wm "ZWE2019MICS" "ZWE_2019_MICS_v02_M_v01_A_IPUMS" "`LIB'/ZWE/ZWE_2019_MICS/ZWE_2019_MICS_v02_M_v01_A_IPUMS/Data/Stata"

* ---------------- KEN 2014 DHS + 2022 MICS ----------------
capture mkdir "`LIB'/KEN"
capture mkdir "`LIB'/KEN/KEN_2014_DHS"
_fx_dirs "`LIB'/KEN/KEN_2014_DHS/KEN_2014_DHS_v01_M"
_fx_dirs "`LIB'/KEN/KEN_2014_DHS/KEN_2014_DHS_v01_M_v01_A_HLT"
_fx_hlt "KEN2014DHS" "KEN_2014_DHS_v01_M_v01_A_HLT" "`LIB'/KEN/KEN_2014_DHS/KEN_2014_DHS_v01_M_v01_A_HLT/Data/Stata"
capture mkdir "`LIB'/KEN/KEN_2022_MICS"
_fx_dirs "`LIB'/KEN/KEN_2022_MICS/KEN_2022_MICS_v01_M"
_fx_dirs "`LIB'/KEN/KEN_2022_MICS/KEN_2022_MICS_v01_M_v01_A_HLT" nodoc
_fx_hlt "KEN2022MICS" "KEN_2022_MICS_v01_M_v01_A_HLT" "`LIB'/KEN/KEN_2022_MICS/KEN_2022_MICS_v01_M_v01_A_HLT/Data/Stata"

* ---------------- BRA 2015 PNAD (v09 + v10 masters) ----------------
capture mkdir "`LIB'/BRA"
capture mkdir "`LIB'/BRA/BRA_2015_PNAD"
_fx_dirs "`LIB'/BRA/BRA_2015_PNAD/BRA_2015_PNAD_v09_M"
_fx_household "BRA2015PNAD" "BRA_2015_PNAD_v09_M" "`LIB'/BRA/BRA_2015_PNAD/BRA_2015_PNAD_v09_M/Data/Stata" old
_fx_dirs "`LIB'/BRA/BRA_2015_PNAD/BRA_2015_PNAD_v10_M"
_fx_household "BRA2015PNAD" "BRA_2015_PNAD_v10_M" "`LIB'/BRA/BRA_2015_PNAD/BRA_2015_PNAD_v10_M/Data/Stata"

di as result "Fixture library (re)generated under `LIB'."
