*==============================================================================*
* project:   UNICEF Datalib - demo usage of the datalib command
* author:    Joao Pedro Azevedo  (jpazevedo@unicef.org)
*==============================================================================*
* Prerequisites:
*   - profile_datalib.do has been executed in this session (sets ${clone},
*     ${datalib}, and installs the required user-written packages).
*   - The datalib suite of ado-files has been installed locally, e.g.
*        net install datalib, from("${clone}/stata") force
*==============================================================================*

* Point Stata at your local datalib tree. Override this global in your own
* profile if your tree lives elsewhere.
if ("${datalib}" == "") {
    global datalib "${clone}/data/datalib"
}

*-----------------------------------------------------------------------------
* 1) Interactive navigation
*-----------------------------------------------------------------------------
* No arguments -> country picker.
datalib

* Country only -> survey picker.
datalib, country(ZWE)

* Country + survey + year + vintage -> load data.
datalib, country(ZWE) year(2019) survey(MICS) vm(V01) va(V01) ///
        collection(HLT) module(adult) nomerge clear

*-----------------------------------------------------------------------------
* 2) Load each module separately
*-----------------------------------------------------------------------------
foreach mod in adult children hhmembers household {
    datalib, country(ZWE) year(2019) survey(MICS) vm(V01) va(V01) ///
            collection(HLT) module(`mod') nomerge clear
}

*-----------------------------------------------------------------------------
* 3) Country-only queries default to the latest available survey
*-----------------------------------------------------------------------------
datalib, country(AFG) survey(MICS) debug nomerge clear
datalib, country(BOL) survey(DHS)  debug nomerge clear
datalib, country(ALB) survey(MICS) debug module(household adult children) clear

*-----------------------------------------------------------------------------
* 4) Graceful failure when the selection is not available
*-----------------------------------------------------------------------------
* Emits an informative error instead of producing an empty dataset.
cap noi datalib, country(BRA) clear
