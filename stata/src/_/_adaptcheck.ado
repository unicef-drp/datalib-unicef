*******************************************************
** _adaptcheck.ado 
* Author: Joao Pedro Azevedo
*! Version: 1.0       Date: <2024-08-15>
** Description: 
* This program checks the surveys archived in the datalib 
* repository. It extracts unique adaptation names based on the 
* folder structure and filenames following a specified pattern.
*
** Filename patterns:
* MASTER FILE: - <country>_<year>_<survey>_<vintage>_m_<module>
* ADAPTATION FILE: - <country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>_<module>
*
** Folder structure patterns:
* - datalib/<country>/<country>_<year>_<survey>/<country>_<year>_<survey>_<vintage>_m/
* - datalib/<country>/<country>_<year>_<survey>/<country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>/
*******************************************************

capture program drop _adaptcheck
program define _adaptcheck, rclass

    version 15

    syntax, path(string)

    * Extract the list of subfolders in the specified path
    local list : dir "`path'/" dirs "*"

    * Initialize an empty macro to hold adaptation names and a counter
    local adaptations
    local adaptcount = 0

    foreach folder in `list' {
        * Normalize folder to lower() so matching works on case-sensitive filesystems.
        local lfolder = lower("`folder'")
        * Check if the folder matches the pattern for an adaptation
        if strpos("`lfolder'", "_a_") {
            * Extract the adaptation name
            local adaptationname = substr("`lfolder'", strpos("`lfolder'", "_a_") + 3, .)
            local adaptationname = upper(word(subinstr("`adaptationname'", "_", " ", .), 1))
            local adaptations "`adaptations' `adaptationname'"
            local adaptcount = `adaptcount' + 1
        }
    }

    * Trim the final list of adaptations
    local adaptations = trim("`adaptations'")

    * Display the list of adaptation names if any were found
    if ("`adaptations'" == "") {
        di as err "No adaptations found in the specified folder."
        return local adaptations "0"
        return local adaptcount = 0
    }
    else {
        di "Adaptations found: `adaptations'"
        di "Total number of adaptations: `adaptcount'"
        return local adaptations "`adaptations'"
        return local adaptcount = `adaptcount'
    }

end


/*******************************************************
 Usage Examples:

* List the adaptation names and the total number of adaptations available in the specified path
_adaptcheck, path("D:\datalib\BGD\BGD_2019_MICS")
return list

* List the adaptation names and the total number of adaptations available in the specified path
_adaptcheck, path("D:\datalib\ZWE\ZWE_2019_MICS")
return list

* List the adaptation names and the total number of adaptations available in the specified path
_adaptcheck, path("D:\datalib\/KEN/KEN_2014_DHS")
return list

* List the adaptation names and the total number of adaptations available in the specified path
_adaptcheck, path("D:\datalib\/ZWE/ZWE_2014_DHS")
return list

* List the adaptation names and the total number of adaptations available in the specified path
_adaptcheck, path("D:\datalib\/MDG/MDG_2018_MICS")
return list

*******************************************************

