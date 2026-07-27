*******************************************************
* _mkdir.ado 
* Joao Pedro Azevedo
*! v1.02       <20240817>       JPAzevedo
*******************************************************

capture program drop _mkdir
program define _mkdir, rclass

    version 15

    ** Declare local macros at the top
    local Mcheck
    local Acheck
    local Mlatestvintage
    local Alatestvintage
    local MAlatestvintage
    local clct
    local vmstr
    local vastr
    local vmLtest = 0
    local vaLtest = 0
    local vm 00
    local va 00
    local vcheck
    local svycheck
    local latest
    local YRlist
    local survey
    local i = 1
    local path
    local root
    local mast
    local data_M
    local doc_M
    local data_M_original
    local data_M_stata
    local adapt
    local data_A
    local data_A_original
    local data_A_stata
    local checkVm1 = 0
    local checkVm2 = 0
    local checkVa1 = 0
    local checkVa2 = 0

    syntax                              ///
            ,                           ///
            path(string)                ///
            country(string)             ///
        [                               ///
            year(string)                ///
            survey(string)              ///
            MODule(string)              ///
            MASter                      ///
            ADAPtation                  ///
            collection(string)          ///
            harmonization(string)       ///
            va(string)                  ///
            vm(string)                  ///
            DEBUG                       ///
            MKDIR                       ///
            OVERWRITE                   ///
            CHECK                       ///
            latest                      ///        
        ]

    ** Flow control
    * Check if country has been selected. Error if not.
    if ("`country'" == "") {
        noi di as err "Error: country needs to be specified."
        exit 198
    }

    * Select master files
    if ("`master'" != "") {
        noi di as err "Error: Option master not currently supported."
    }

    if ("`adaptation'" == "" & "`collection'" != "") {
        local adaptation "adaptation"
        noi di in y "Adaptation folders created since collection was specified."
    }

    if ("`adaptation'" != "" & "`mkdir'" != "" & "`collection'" == "") {
        noi di as err "Error: Need to specify collection name when adaptation and MKDIR options are enabled."
        exit 198
    }

    * Check if VA has been selected with adaptation enabled. If not, error break. 
    if ("`va'" != "" & "`adaptation'" == "") {
        noi di as err "Error: VA option can only be specified if adaptation option is enabled."
        exit 198
    }

    * Check if VA has been selected. If not, default value is 01.
    if ("`va'" == "" & "`adaptation'" != "") {
        noi di in y "Option VA not specified; default value of 01 used, unless latest vintage is higher."
        local vastr "v01"
        local va 01
        local vaval = 1
        local vaLtest = 1
     }

    * Check if VA follows the proper format. If not, error break.
    if ("`va'" != "" & "`adaptation'" != "") {
        local vacheck1 = real("`va'")
        local vacheck2 = length("`va'")
        if (`vacheck1' == . | `vacheck2' != 2) {
            noi di as err "Error: VA option can only be two-digit values from 01 to 99."
            exit 198
        }
        local vastr "v`va'"
        local vaval = real("`va'")
    }

    * Check if harmonization has been selected. If not, default value is empty.
    if ("`harmonization'" != "") {
        noi di as err "Error: Option harmonization not currently supported."
    }
    
    if ("`vm'" == "") {
        noi di in y "Option VM not specified; default value of 01 used, unless latest vintage is higher."
        local vmstr "v01"
        local vm 01
        local vmval = 1
        local vmLtest = 1
    }

    * Check if VM follows the proper format. If not, error break.
    if ("`vm'" != "") {
        local vmcheck1 = real("`vm'")
        local vmcheck2 = length("`vm'")
        if (`vmcheck1' == . | `vmcheck2' != 2) {
            noi di as err "Error: VM option can only be two-digit values from 01 to 99."
            exit 198
        }
        local vmstr "v`vm'"
        local vmval = real("`vm'")
    }

    if ("`vm'" != "") & ("`va'" == "") {
        local va 00
    }
    * Check if year is specified. If not, latest option is the default.
    if ("`year'" == "") {
        noi di in y "Year not specified. Latest available survey will be used."
        local latest latest
    }

    * Check if datalib path has been specified. If not, error break. 
    if ("${datalib}" == "") {
        noi di as err "Error: Path to datalib needs to be specified. Global datalib needs to be specified."
        exit 198
    }

    * Default collection set as health; future collections can be added as needed.
    if ("`collection'" != "") {
        local clct "`collection'"
        *local collection "HLT"
    }

    * Supported modules by collection
    if ("`clct'" == "HLT") {
        local allmodule "household hhmembers adult children "
        * Sort merge variables
        local sort_household_hhmembers "svy_id household_id "
        local sort_adult_children "svy_id household_id line_number "
    }

    * Check if module has been selected. If not, all modules will be selected.
    if ("`module'" == "") {
        local module "`allmodule'"
    }

    * Word count number of modules
    local cntmod = wordcount("`module'")

    * Noisily or quietly based on debug flag
    if ("`debug'" != "") {
        local noi noisily
    } 
    else {
        local noi quietly
    }

    `noi' {

        *-----------------------------------------
        * Check datalib folder
        *-----------------------------------------
        * Country check
        *-----------------------------------------
        _ctrycheck , path("`path'/")
        local ctrylist "`r(ctrylist)'"

        local tmpctrycheck = strpos("`ctrylist'", "`country'")
        if (`tmpctrycheck' == 0) {
            local ctrycheck = 0
            if ("`mkdir'" == "") {
                noi di as err "`country' collection does not exist in datalib. Please change country choice or create new collection using MKDIR option."
                exit 198
            }
        } 
        else {
            local ctrycheck = 1
        }

        *-----------------------------------------
        * Survey check
        *-----------------------------------------
        if ("`survey'" != "") {
            _svycheck , path("${datalib}/`country'") survey("`survey'")
            local svynumb = `r(svynumb)'
            local svylist = r(svylist)
            local survey = "`survey'"
            if (`svynumb' == 0) {
                local svycheck = 0
                if ("`mkdir'" == "") {
                    noi di as err "`survey' for `country' not available. Please select an eligible survey name or create new collection using MKDIR option."
                    noi di as err "If you omit the survey name and a survey is available, datalib will pull the latest survey available."
                    exit 198
                }
            } 
            else if (`svynumb' == 1) {
                noi di as err "Only one survey is available for `country'. `survey' was selected."
            }
        } 
        else {
            _svycheck , path("${datalib}/`country'")
            local svynumb = `r(svynumb)'
            local svylist = r(svylist)
            local survey = r(latestsurvey)
            if (`svynumb' == 0) {
                local svycheck = 0
                if ("`mkdir'" == "") {
                    noi di as err "No survey available for `country'. Please select an eligible survey name or create new collection using MKDIR option."
                    exit 198
                }
            } 
            else if (`svynumb' == 1) {
                noi di as err "Only one survey is available for `country'. `survey' was selected."
            } 
            else if (`svynumb' > 1) {
                noi di as err "Multiple surveys available for `country' (i.e., `svylist'). Latest available will be used."
            }
        }

        *-----------------------------------------
        * Year check
        *-----------------------------------------
        if ("`year'" == "") {
            local year = r(latestyear)
            return local latestyear = "`r(latestyear)'"
            return local latestsurvey = "`r(latestsurvey)'"
            noi di as err "Year not specified. Latest available year (i.e., `year') will be used."
        } 
        else {
            local year = "`year'"
        }

        if (`svynumb' > 0) {
            local svycheck = 1
        }

        *-----------------------------------------
        * Return survey-related variables
        *-----------------------------------------
        return local svylist = "`r(svylist)'"
        return local adptlist = "`r(adptlist)'"
        return local svynumb = "`r(svynumb)'"
        return local adptnumb = "`r(adptnumb)'"
        return local multiplevintages = "`r(multiplevintages)'"
        return local mastercheck = "`r(mastercheck)'"
        return local masteradaptcheck = "`r(masteradaptcheck)'"
        return local adaptationcheck = "`r(adaptationcheck)'"
        return local mastervintages = trim("`r(mastervintages)'")
        return local masteradaptvintages = trim("`r(masteradaptvintages)'")
        return local adaptationvintages = trim("`r(adaptationvintages)'")

        if (`ctrycheck' == 1) {
            if (`"`svylist'"' == "" & "`survey'" != "" & "`mkdir'" != "") {
                noi di as err "`survey' for `country' not available. Please select an eligible survey name."
                exit 198
            }
            if (`"`svylist'"' == "" & "`survey'" != "" & "`mkdir'" == "mkdir") {
                noi di "`survey' for `country' not available. New collection will be created."
                local svycheck = 0
            }

            if (`svycheck' == 1 & "`survey'" == "" & "`latest'" == "latest" & "`year'" == "") {
                _svycheck , path("${datalib}/`country'") country(`country')
                local svylist = r(svylist)
                local year = r(latestyear)
                local survey = r(latestsurvey)
            }

            if (`svycheck' == 1 & "`survey'" != "") & ("`year'" == "") {
                _svycheck , path("${datalib}/`country'") country(`country') survey("`survey'")
                local svylist = "`survey'"
                local year = r(latestyear)
                local survey = "`survey'"
            }

            if (`svycheck' == 1 & "`survey'" != "") & ("`year'" != "") {
                _svycheck , path("${datalib}/`country'") country(`country') survey("`survey'") year("`year'")
                if (`r(svynumb)' == 1) {
                    _svycheck , path("${datalib}/`country'/`country'_`year'_`survey'")
                    local svylist = "`survey'"
                    local year  = `year'
                    local survey = "`survey'"
                }
            }
        }

        local svy = upper("`survey'")

        *-----------------------------------------
        * Loop through countries and years to create folders
        *-----------------------------------------
        foreach ctry in `country' {
            local i = 1
            foreach yr in `year' {

                * Create country folder if it does not exist
                if (`ctrycheck' == 0 & "`mkdir'" == "") {
                    noi di as err "`ctry' collection does not exist in datalib. Please create or select MKDIR option."
                    exit 198
                } 
                else if (`ctrycheck' == 0 & "`mkdir'" == "mkdir") {
                    mkdir "`path'/`ctry'"
                    noi di "`ctry' collection created in datalib"
                } 
                else if (`ctrycheck' == 1) {
                    noi di "`ctry' collection already exists in datalib"
                }

                * Create country_year_survey folder if it does not exist
                cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'"
                if (_rc == 0) {
                    noi di "`ctry'_`yr'_`svy' collection created in datalib"
                } 
                else {
                    noi di "`ctry'_`yr'_`svy' collection already exists in datalib"
                }

                *-----------------------------------------
                * Check collection name if adaptation is selected
                *-----------------------------------------

                if ("`adaptation'" != "") {
                    _adaptcheck, path("`path'/`ctry'/`ctry'_`yr'_`svy'")
                    local adaptations = "`r(adaptations)'"
                    local adaptcount = `r(adaptcount)'

                    if (`adaptcount' == 0) & ("`mkdir'" == "") {
                        noi di as err "No adaptations found in `ctry'_`yr'_`svy' collection. Select a different collection or create a new one using MKDIR."
                        exit 198
                    }

                    * Check if collection name is provided
                    if ("`clct'" != "") {
                        local chckadpt1 = strpos("`adaptations'", "`clct'")
                        if (`chckadpt1' == 0) & ("`mkdir'" == "mkdir") {
                            noi di "Collection `clct' is new. Collection vintage 01."
                            local new new
                        } 
                        else if (`adaptcount' > 0) {
                            noi di "Collection `clct' already exists."
                            local chckadpt1 = 1
                        }
                    }

                    * if collection is not provided, select the latest available adaptation
                    if ("`clct'" == "") {
                        if (`adaptcount' == 1) {
                            local clct = "`r(adaptations)'"
                            local chckadpt1 = 1
                        }
                        if (`adaptcount' > 1) {
                            local clct = word("`r(adaptations)'",-1)
                            local chckadpt1 = 1
                        }
                    } 

                }


                *-----------------------------------------
                * Check if subfolders exist and find the latest vintage of the data
                *-----------------------------------------
                cap: _vcheck, path("`path'/`ctry'/`ctry'_`yr'_`svy'")
                local vcheck = _rc
                
                if (`vcheck' == 0) {
                    local Mcheck = `r(Mcheck)'
                    local Acheck = `r(Acheck)'
                    local Mnumvintagelist = "`r(Mnumvintagelist)'"
                    if ("`adaptation'" == "") {
                        local Mlatestvintage = real(substr("`r(Mlatestvintage)'", 1, 2))
                        local vm = substr("`r(Mlatestvintage)'", 1, 2)
                    }
                    if ("`adaptation'" != "") {
                        local Anumvintagelist = "`r(Anumvintagelist)'"
                        local Mlatestvintage = substr("`r(Alatestvintage)'", 1, 2)
                        local Alatestvintage = substr("`r(Alatestvintage)'", 3, 2)
                        if ("`vm'" == "") {
                            local vm = substr("`r(Mlatestvintage)'", 1, 2)
                        }
                        if ("`va'" == "") {
                            local va = substr("`r(Alatestvintage)'", 3, 2)
                        }
                        if (`Acheck' == 0) {
                            local Mlatestvintage = substr("`r(Mlatestvintage)'", 1, 2)
                        }
                    }
                } 
                else {
                    local Mcheck = 0
                    local Acheck = 0
                    local Mlatestvintage = 0
                    local Alatestvintage = 0
                    local MAlatestvintage = 0                
                }

                *-----------------------------------------
                * Check for vintage numbers
                *-----------------------------------------
                if (`Mcheck' == 1 & "`mkdir'" == "" & "`adaptation'" == "") {
                    local vmval = real("`vm'")
                    local chckvm1 = strpos("`Mnumvintagelist'", "`vmval'")
                    if (`chckvm1' == 0) {
                        noi di as err "Error: Selected Master vintage does not exist. Choose a different vintage or create a new collection using MKDIR option."
                        exit 198
                    }
                    local checkVm1 = 1
                }

                if (`Mcheck' == 1 & `Acheck' == 1 & "`mkdir'" == "") {
                    local vmval = real("`vm'")
                    local vaval = real("`va'")
                    local chckvm1 = strpos("`Mnumvintagelist'", "`vmval'")
                    local chckva1 = strpos("`Anumvintagelist'", "`vaval'")
                    if (`chckvm1' == 0) {
                        noi di as err "Error: Selected Master vintage does not exist. Choose a different vintage or create a new collection using MKDIR option."
                        exit 198
                    }
                    if (`chckva1' == 0 & "`adaptation'" == "adaptation") {
                        noi di as err "Error: Selected Adaptation vintage does not exist. Choose a different vintage or create a new collection using MKDIR option."
                        exit 198
                    }
                    local checkVa1 = 1
                }

                * Check if new master vintage numbers are eligible
                if (`Mcheck' == 1 & "`mkdir'" == "mkdir" & "`adaptation'" == "") {
                    local vmval = real("`vm'")
                    local chckvm2 = `vmval' - `Mlatestvintage'
                    if (abs(`chckvm2')>1) {
                        noi di as err "Error: Selected Master vintage is not eligible. Vintage numbers need to increase in increments of 1. You have selected `vm' while the latest existing vintage is `Mlatestvintage'."
                        exit 198
                    }
                    local checkVm2 = 1
                }

                * Check if new master and adaptation vintage numbers are eligible
                if (`Mcheck' == 1 & "`mkdir'" == "mkdir" & "`adaptation'" == "adaptation") {
                    local vmval = real("`vm'")
                    local chckvm1 = strpos("`Mnumvintagelist'", "`vmval'")
                    local vmval = real("`vm'")
                    local chckvm2 = `vmval' - `Mlatestvintage'
                    if (`chckvm1' == 0 | `chckvm2' != 1) {
                        if ("`overwrite'" == "") {
                            noi di as err "Error: Selected Master vintage does not exist or proposed value is not eligible. Choose a different Master vintage number."
                            exit 198
                        }
                        if ("`overwrite'" == "overwrite") {
                            if (`chckvm2' == 0) {
                                noi di "Overwrite selected. Existing files will be replaced."
                                local chckvm2 = 1
                            }
                        }
                    }
                    if (`Acheck' == 1) {
                        local vaval = real("`va'")
                        local chckva2 = `vaval' - `Alatestvintage'
                        if (`chckva2' != 1) {
                            if ("`overwrite'" == "") {
                                noi di as err "Error: Selected Adaptation vintage is not eligible. Vintage numbers need to increase in increments of 1. You have selected `va' while the latest existing vintage is `Alatestvintage'."
                                exit 198
                            }
                            if ("`overwrite'" == "overwrite") {
                                if (`chckvm2' == 0) {
                                    noi di "Overwrite selected. Existing files will be replaced."
                                    local chckvm2 = 1
                                }
                            }                           
                        }
                    } 
                    else if (`Acheck' == 0) {
                        local vaval = real("`va'")
                        local chckva1 = `vaval' - 0
                        if (`chckva1' != 1) {
                            noi di as err "Error: New Adaptation. Selected vintage must be 01."
                            exit 198
                        }
                    }
                    local checkVa2 = 1
                }

                if ("`adaptation'" == "") {
                    if (`vmLtest' == 1) & (`vmval' != 1) {
                        local vmstr = "v" + "`vm'"
                    }
                }
                if ("`adaptation'" != "") {
                    if (`vaLtest' == 1) & (`vaval' != 1) {
                        local vmstr = "v" + "`vm'"
                        local vastr = "v" + "`va'"
                    }
                }

                *-----------------------------------------
                * Master collection
                *-----------------------------------------
                if ("`adaptation'" == "") {
                    if (`vcheck' == 0 & `Mcheck' == 1) {
                        noi di "`ctry'_`yr'_`svy'_`vmstr'_M vintage already exists in datalib. No subfolders created."
                    }
                    if (`vcheck' != 0 & `Mcheck' == 0 & "`mkdir'" != "") {
                        cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M"
                        if (_rc == 0) {
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Data"
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Data/Original"
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Data/Stata"                   
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Data/Other" 
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Doc"
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Programs"
                            noi di "`ctry'_`yr'_`svy'_`vmstr'_M vintage created in datalib"
                        }
                    }
                    if (`vcheck' == 0 & `Mcheck' == 1 & "`mkdir'" != "" & `checkVm2' == 1) {
                        cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M"
                        if (_rc == 0) {
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Data"
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Data/Original"
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Data/Stata"                   
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Data/Other" 
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Doc"
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Programs"
                            noi di "`ctry'_`yr'_`svy'_`vmstr'_M vintage created in datalib"
                        }
                    }
                }

                *-----------------------------------------
                * Adaptation collection
                *-----------------------------------------
                if ("`adaptation'" != "") {
                    if (`vcheck' == 0 & `Mcheck' == 1 & `Acheck' == 1 & `chckadpt1' == 1) {
                        noi di "`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct' vintage already exists in datalib"
                    }
                    if (`vcheck' == 0 & `Mcheck' == 1 & `Acheck' == 0 & "`mkdir'" != "" & "`new'" == "new") {
                        cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'"
                        if (_rc == 0) {
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Data"
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Data/Original"
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Data/Stata"
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Data/Other"
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Doc"
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Programs"
                            noi di "`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct' vintage created in datalib"
                        }
                    }
                    if (`vcheck' == 0 & `Mcheck' == 1 & `Acheck' == 1 & "`mkdir'" != "" & `checkVa2' == 1) {
                        cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'"
                        if (_rc == 0) {
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Data"
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Data/Original"
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Data/Stata"
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Data/Other"
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Doc"
                            cap: mkdir "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Programs"
                            noi di "`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct' vintage created in datalib"
                        }
                    }
                }

                *-----------------------------------------
                * Return local macros
                *-----------------------------------------
                if wordcount("`year'") == 1 {
                    return local path = "`path'"
                    return local root "`ctry'_`yr'_`svy'"
                    return local mast "`ctry'_`yr'_`svy'_`vmstr'_M"
                    return local data_M "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Data/"
                    return local doc_M "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Doc/"
                    return local data_M_original "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Data/Original"
                    return local data_M_stata "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Data/Stata"
                    if ("`clct'" != "" & "`adaptation'" != "") {
                        return local adapt "`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'"
                        return local data_A "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Data/"
                        return local data_A_original "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Data/Original"
                        return local data_A_stata "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Data/Stata"
                    }
                } 
                else {
                    return local path = "`path'"
                    return local root "`ctry'_`yr'_`svy'"
                    return local mast "`ctry'_`yr'_`svy'_`vmstr'_M"
                    return local data_M`i' "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Data/"
                    return local doc_M`i' "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Doc/"
                    return local data_M_original`i' "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Data/Original"
                    return local data_M_stata`i' "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M/Data/Stata"
                    if ("`clct'" != "" & "`adaptation'" != "") {
                        return local adapt "`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'"
                        return local data_A`i' "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Data/"
                        return local data_A_original`i' "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Data/Original"
                        return local data_A_stata`i' "`path'/`ctry'/`ctry'_`yr'_`svy'/`ctry'_`yr'_`svy'_`vmstr'_M_`vastr'_A_`clct'/Data/Stata"
                    }
                }

                local i = `i' + 1

            }
        }

    }

end
 
/*******************************************************
 Usage Examples:

cap: _mkdir , path("D:\datalib\") country(ZZZ) survey(MICS) year(2012)
 return list

 * Checks the vintage of data in the specified path for the 2014 DHS survey in Zimbabwe.
 _mkdir , path("D:\datalib\") country(ZWE) survey(DHS) year(2014)
 return list

 * Checks the vintage of data in the specified path for the 2019 MICS survey in Zimbabwe.
 _mkdir , path("D:\datalib\") country(ZWE) survey(MICS) year(2019)
 return list

 * Checks the vintage of data in the specified path for the 2019 MICS survey in Zimbabwe, including master and adaptation files.
 cap: _mkdir , path("D:\datalib\") country(ZWE) survey(MICS) year(2019) vm(01) va(01) adaptation
 return list

 * Checks the vintage of data in the specified path for the 2014 DHS survey in Kenya.
 _mkdir , path("D:\datalib\") country(KEN) survey(DHS) year(2014)
 return list

 * Checks the vintage of data in the specified path for the 2019 MICS survey in Bangladesh.
 _mkdir , path("D:\datalib\") country(BGD) survey(MICS) year(2019)
 return list

 _mkdir , path("D:\datalib\") country(ZWE) survey(MICS) year(2019) adaptation
 return list

*******************************************************
* Version History
* v1.02       <20240817>       JPAzevedo
*   - Enhanced the handling of the `year' option to ensure the correct year
*     is used in all folder creation and checks.
*   - Added logic to correctly handle multiple survey years.
*   - Updated error messages and included debug output for better diagnostics.
* v1.01       <20240812>       JPAzevedo
*   - Added error handling for missing options.
*   - Improved logic for handling vintage numbers (VM and VA).
*   - Incorporated checks for adaptations and collections.
* v1.00       <20240801>       JPAzevedo
*   - Initial version with basic functionality for checking and creating 
*     directories based on country, survey, and year.
*******************************************************