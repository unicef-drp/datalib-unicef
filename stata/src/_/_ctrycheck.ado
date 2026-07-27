*******************************************************
** _ctrycheck: Datalib Country Check Utility
* Author: Joao Pedro Azevedo
*! Version: 1.0       Date: <2024-08-15>       
** Description: 
* This program checks the countries for which data is archived in 
* the datalib repository by extracting unique survey names from 
* a specified path. It returns a list of unique country codes 
* and the number of unique surveys found.
*
** Filename patterns:
* MASTER FILE: - <country>_<year>_<survey>_<vintage>_m_<module>
* ADAPTATION FILE: - <country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>_<module>
*
** Folder structure patterns:
* - datalib/<country>/<country>_<year>_<survey>/<country>_<year>_<survey>_<vintage>_m/
* - datalib/<country>/<country>_<year>_<survey>/<country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>/
*******************************************************

capture program drop _ctrycheck 
program define _ctrycheck, rclass

    version 15

    * Define the syntax with required and optional parameters
    syntax ,                     ///
        path(string)            /// Required: Path to the data directory
        [                       ///
        Master                  /// Optional: Specify if checking master files
        Adaptation              /// Optional: Specify if checking adaptation files
        ]

    *-----------------------------------------
    * Extract folder names in the specified path
    local list : dir "`path'/" dirs "*"

    * Initialize an empty macro to hold unique country/survey names
    local ctrylist
    local ctrylist_unique

    *-----------------------------------------
    * Generate a list of all surveys available in the specified path
    foreach folder in `list' {
        local ctrytmp = word(subinstr("`folder'", "_", " ", .), 1)
        local ctrylist "`ctrylist' `ctrytmp'"
    }
    
    *-----------------------------------------
    * Remove duplicate country codes to create a list of unique values
    foreach item in `ctrylist' {
        if strpos("`ctrylist_unique'", "`item'") == 0 {
            local ctrylist_unique "`ctrylist_unique' `item'"
        }
    }

    *-----------------------------------------
    * Display the unique country codes
    di "`ctrylist_unique'"

    *-----------------------------------------
    * Return local macros for use outside the program
    return local ctrylist = upper(trim("`ctrylist_unique'"))
    return local ctrynumb = wordcount("`ctrylist_unique'")

end 

/*******************************************************
 Usage Example:
 
 _ctrycheck , path("D:\datalib\")
 return list

 _ctrycheck , path("D:\datalib\ZWE\")
 return list

 _ctrycheck , path("D:\datalib\ZWE\ZWE_2019_MICS")
 return list
*******************************************************/

