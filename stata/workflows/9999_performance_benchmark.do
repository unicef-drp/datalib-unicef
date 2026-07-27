*==================================================
*project:       D&A Datalib collection / SDG 2025 Report
*Author:        Joao Pedro Azevedo
*E-email:       jpazevedo@unicef.org
*Created:       7th December, 2024
*==================================================

* this script needs to be excecuted from the beining
* Define the country of interest and datalib path; if country omitted, the full root will be reviewed

local clct "datalib"  // Replace with the desired collection code

 * This needs to be edited depending on the collection
 * Stubs: bh ch fs hh hl mn wm 
 * Input:  long fsizebh long fsizech long fsizefs long fsizehh long fsizehl  long fsizemn  long fsizewm
 * Output: (`fsizebh') (`fsizech') (`fsizefs') (`fsizehh') (`fsizehl') (`fsizemn') (`fsizewm')

*global datalib "C:/path/to/datalib"  // Replace with the correct datalib path
/*
    tempfile filelist
    filelist, dir("${datalib}") save("`filelist'")


    use "`filelist'", clear
    save tmp`clct', replace
    gen flag = 1 if strpos(filename, ".dta") > 0
    gen fsizeMB = fsize/1024^2
    keep if flag == 1
    local N = _N
    forvalue i = 1(1)`N' {
        local file  = filename in `i'
        local fsize = fsizeMB in `i'
        local loc`i' "`file' `fsize'"
    }
*/


    program define timem
        timer off 1
        timer list 1
        timer clear 1
        timer on 1
    end

    use "c:/data/tmp", replace

    * Create a frame to store results
    cap frame drop timing_results
    frame create timing_results str10 ctry strL filename svyyear str10 svyname str10 masterVint str5 adaptVint str5 adapt ///
                            long filesize long time

    local N = _N

*    forvalues i = 1(1)`N' {
    forvalues i = 1/1001 {

        use "c:/data/tmp", replace

        local filename = filename[`i']
        local filesize = fsize[`i']

        noi di "`filename'"

        local ctry = word(subinstr("`filename'","_"," ",.),1)
        local year = word(subinstr("`filename'","_"," ",.),2) 
        local svy  = word(subinstr("`filename'","_"," ",.),3)
        local vm   = word(subinstr("`filename'","_"," ",.),4)
        local va   = word(subinstr("`filename'","_"," ",.),6)
        local clct = word(subinstr("`filename'","_"," ",.),8)
        
        if ("`ctry'" != "WLD") {

            * Start timing
            timer clear
            timer on 1

           noi datalib, country(`ctry') year(`year') survey(`svy') vm(`vm') va(`va') collection(`clct') ///
                            filename(`"`filename'"') nomerge clear data 

            * Stop timing and calculate elapsed time
            timer off 1
            timer list 1
            local elapsedtime = r(t1) 

            frame post timing_results   ("`ctry'") ("`filename'")  ///
                (`year') ("`svy'") ("`vm'") ("`va'") ("`clct'") ///
                (`filesize') (`elapsedtime')

        }
    }

frame change timing_results

    gen fsizeMB = filesize/1024^2

    gen module = word(subinstr(filename,"_"," ",.),9)
    replace module = subinstr(module,".dta","",.)

    graph twoway scatter time fsizeMB
    graph twoway (scatter time fsizeMB) (qfit time fsizeMB)

    encode module, gen(mod)
    alorenz time, by(mod) gp point(40) title("")

save c:/data/datalib_performance, replace

  noi di ""
  noi di ""
  noi disp as res "Start Documentation files (started at $S_TIME)..."




* Initialize a timer
clear
timer clear

* Create a frame to store results
frame create timing_results code_snippet str50 description time_seconds

* Measure time for first operation
timer on 1
sysuse auto, clear
timer off 1

timer list 1

di `r(t1)'

* Record results
local time_elapsed = r(t1)

timer on 2
datalib, country(AFG) year(2022) survey(MICS) vm(V01) va(V02) collection(IPUMS) filename(`"afg_2022_mics_v01_m_v02_a_ipums_ch.dta"') nomerge clear data 
timer off 2

timer list 2

di r(t2)


frame append timing_results, values("1. Load auto dataset" `time_elapsed')

datalib, country(AFG) year(2022) survey(MICS) vm(V01) va(V02) collection(IPUMS) filename(`"afg_2022_mics_v01_m_v02_a_ipums_ch.dta"') nomerge clear data 
local t = c(rmsg_time)
di "`t'"

* Measure time for second operation
timer on 2
gen weight_kg = weight / 2.20462
timer off 2

* Record results
local time_elapsed = r(t2)
frame append timing_results, values("2. Generate weight in kg" `time_elapsed')

* Measure time for a more complex operation
timer on 3
bysort foreign (price): gen price_rank = _n
timer off 3

* Record results
local time_elapsed = r(t3)
frame append timing_results, values("3. Generate price rank by foreign" `time_elapsed')

* Display the timing results
frame change timing_results
list
