*! _foldernav: Folder Navigation Utility
*! Author: Joao Pedro Azevedo
*! Version: 1.1       Date: 2026-07-25
*! Description: 
*! This program is designed to navigate through folder structures 
*! in the datalib repository, enabling the selection of subfolders 
*! based on the structure of the data collection.
*******************************************************

capture program drop _foldernav 
program define _foldernav, rclass

    version 15

    syntax  [varlist]                     ///
            [in] [if]                     ///
            [,                            ///
                country(string)           ///
                path(string)              ///
                subfoldr(string)          ///
                filename(string)          ///
            ]            

    * The DATA / DOC / PROGRAMS sections resume from the folder the PREVIOUS
    * call left in r(subfoldr). Read it once, as a string: any rclass command
    * running between the two calls wipes r(), and -local x = r(subfoldr)- on a
    * missing result yields "." , which used to build "${datalib}/./Data/..."
    * and fail with a confusing r(601).
    local prevfoldr `"`r(subfoldr)'"'

    * Determine subfolder depth and structure
    local stubcnt = wordcount(subinstr("`subfoldr'", "_", " ",.))

    if (`stubcnt'==1) {
        local subfoldr = "`subfoldr'"
    }
    if (`stubcnt'==3) {
        local stub1  = word(subinstr("`subfoldr'", "_", " ",.),1)
        local subfoldr = "`stub1'/`subfoldr'"
    }
    if (`stubcnt'==5) {
        local stub1  = word(subinstr("`subfoldr'", "_", " ",.),1)
        local stub2  = word(subinstr("`subfoldr'", "_", " ",.),2)
        local stub3  = word(subinstr("`subfoldr'", "_", " ",.),3)
        local subfoldr = "`stub1'/`stub1'_`stub2'_`stub3'/`subfoldr'"       
    }
    if (`stubcnt'==8) {
        local subfoldr = "`subfoldr'"
        local stub1  = word(subinstr("`subfoldr'", "_", " ",.),1)
        local stub2  = word(subinstr("`subfoldr'", "_", " ",.),2)
        local stub3  = word(subinstr("`subfoldr'", "_", " ",.),3)
        local subfoldr = "`stub1'/`stub1'_`stub2'_`stub3'/`subfoldr'"      
    }

    * Set the path based on the provided or default value
    if ("`path'"=="") & ("`subfoldr'" == "") {
        local path "${datalib}/"
    } 
    else if ("`path'"=="") & ("`subfoldr'" != "") {
        local path "${datalib}/`subfoldr'/"
    }
    else if ("`path'"!="") & ("`subfoldr'" != "") {
        local path "`path'/`subfoldr'/"
    }

    * Handle navigation for DATA subfolder
    if ("`subfoldr'"=="DATA") {
        local subfoldr `"`prevfoldr'"'
        if (`"`subfoldr'"'=="") | (`"`subfoldr'"'==".") {
            noi di as err `"{p}Cannot open DATA: the folder being navigated is no longer known.{p_end}"'
            noi di as err `"{p}The section links resume from the previous {bf:datalib} call. Re-run the navigation step (for example {bf:datalib, subfoldr(}{it:CCC_YYYY_SURVEY_vNN_M}{bf:)}) and click through again, or address the vintage directly with {bf:datalib, country() year() survey()}.{p_end}"'
            exit 198
        }
        local path "${datalib}/`subfoldr'/Data/Stata/"
        local list : dir "`path'" files "*.dta" 

        local laststub = word(subinstr("`subfoldr'","/"," ",.),-1)
        local ctry  = word(subinstr("`laststub'","_"," ",.),1)
        local year  = word(subinstr("`laststub'","_"," ",.),2)
        local svy   = word(subinstr("`laststub'","_"," ",.),3)
        local vm    = word(subinstr("`laststub'","_"," ",.),4)
        local va    = word(subinstr("`laststub'","_"," ",.),6)
        local clct  = word(subinstr("`laststub'","_"," ",.),8)

        noi di in smcl _newline
        noi di in g in smcl "{hline}"
        foreach files in `list' {
            local module = subinstr(word(subinstr("`files'","_"," ",.),-1),".dta","",.)
            noi di in g in smcl `" {stata `"datalib, country(`ctry') year(`year') survey(`svy') vm(`vm') va(`va') collection(`clct') filename(`"`files'"') nomerge clear data "': {bf: `files'}} "'
        }

        noi di in g in smcl "{hline}"
        return add
        return local fullfoldr = "`subfoldr'/Data/Stata/"
    }
    * Handle navigation for DOC subfolder
    if ("`subfoldr'"=="DOC") {
        local subfoldr `"`prevfoldr'"'
        if (`"`subfoldr'"'=="") | (`"`subfoldr'"'==".") {
            noi di as err `"{p}Cannot open DOC: the folder being navigated is no longer known.{p_end}"'
            noi di as err `"{p}The section links resume from the previous {bf:datalib} call. Re-run the navigation step (for example {bf:datalib, subfoldr(}{it:CCC_YYYY_SURVEY_vNN_M}{bf:)}) and click through again, or address the vintage directly with {bf:datalib, country() year() survey()}.{p_end}"'
            exit 198
        }
        local path "${datalib}/`subfoldr'/Doc/"
        local list : dir "`path'" files "*" 

        local laststub = word(subinstr("`subfoldr'","/"," ",.),-1)
        local ctry  = word(subinstr("`laststub'","_"," ",.),1)
        local year  = word(subinstr("`laststub'","_"," ",.),2)
        local svy   = word(subinstr("`laststub'","_"," ",.),3)
        local vm    = word(subinstr("`laststub'","_","",.),4)
        local va    = word(subinstr("`laststub'","_"," ",.),6)
        local clct  = word(subinstr("`laststub'","_"," ",.),8)

        noi di in smcl _newline
        noi di in g in smcl "{hline}"
        foreach files in `list' {
            local module = subinstr(word(subinstr("`files'","_"," ",.),-1),".dta","",.)
            noi di in g in smcl `" {stata `"datalib, country(`ctry') year(`year') survey(`svy') vm(`vm') va(`va') collection(`clct') filename(`"`files'"') nomerge clear doc "': {bf: `files'}} "'
        }
        
        noi di in g in smcl "{hline}"
        return add
        return local fullfoldr = "`subfoldr'/Doc/"
    }
    * Handle navigation for PROGRAMS subfolder
    if ("`subfoldr'"=="PROGRAMS") {
        local subfoldr `"`prevfoldr'"'
        if (`"`subfoldr'"'=="") | (`"`subfoldr'"'==".") {
            noi di as err `"{p}Cannot open PROGRAMS: the folder being navigated is no longer known.{p_end}"'
            noi di as err `"{p}The section links resume from the previous {bf:datalib} call. Re-run the navigation step (for example {bf:datalib, subfoldr(}{it:CCC_YYYY_SURVEY_vNN_M}{bf:)}) and click through again, or address the vintage directly with {bf:datalib, country() year() survey()}.{p_end}"'
            exit 198
        }
        local path "${datalib}/`subfoldr'/Programs/"
        local list : dir "`path'" files "*" 

        local laststub = word(subinstr("`subfoldr'","/"," ",.),-1)
        local ctry  = word(subinstr("`laststub'","_"," ",.),1)
        local year  = word(subinstr("`laststub'","_"," ",.),2)
        local svy   = word(subinstr("`laststub'","_"," ",.),3)
        local vm    = word(subinstr("`laststub'","_"," ",.),4)
        local va    = word(subinstr("`laststub'","_"," ",.),6)
        local clct  = word(subinstr("`laststub'","_"," ",.),8)

        noi di in smcl _newline
        noi di in g in smcl "{hline}"
        foreach files in `list' {
            local module = subinstr(word(subinstr("`files'","_"," ",.),-1),".dta","",.)
            noi di in g in smcl `" {stata `"datalib, country(`ctry') year(`year') survey(`svy') vm(`vm') va(`va') collection(`clct') filename(`"`files'"') nomerge clear programs "': {bf: `files'}} "'
        }
        
        noi di in g in smcl "{hline}"
        return add
        return local fullfoldr = "`subfoldr'/Programs/"
    }

    
    * Navigate through folders and list available options
    if (`stubcnt'<=8) & ("`subfoldr'"!="DATA") {
    
        * List available folders in the specified path
        if ("`country'"=="") {
            local list : dir "`path'" dirs "*" 
        }
        else {
            local list `"`country'"'
        }

        noi di in smcl _newline
        noi di in g in smcl "{hline}"
        foreach folders in `list' {
            local folders = upper("`folders'")
*            noi di in g in smcl `" {stata `"_foldernav, path(${datalib}) subfoldr(`folders')"': {bf: `folders'}} "'
            noi di in g in smcl `" {stata `"datalib, subfoldr(`folders')"': {bf: `folders'}} "'
        }
        noi di in g in smcl "{hline}"

        * Return the selected subfolder
        return add
        return local subfoldr`stubcnt' = "`subfoldr'"
        return local subfoldr = "`subfoldr'"
    }

end
