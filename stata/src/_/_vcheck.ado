*******************************************************
** _vcheck: Datalib Vintage Check Utility
* Author: Joao Pedro Azevedo
*! Version: 1.2.0       Date: 2024-08-18
** Description: 
* This program checks the vintage of data archived 
* in the datalib repository.
*
** Filename patterns:
* MASTER FILE: - <country>_<year>_<survey>_<vintage>_m_<module>
* ADAPTATION FILE: - <country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>_<module>
*
** Folder structure patterns:
* - datalib/<country>/<country>_<year>_<survey>/<country>_<year>_<survey>_<vintage>_m/
* - datalib/<country>/<country>_<year>_<survey>/<country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>/
*******************************************************

capture program drop _vcheck 
program define _vcheck, rclass

    version 15

    syntax ,                             ///
        path(string)                     ///
    
    * Extract folder names in path
    local list : dir "`path'/" dirs "*"

    * Initialize variables
    local MFolders ""
    local AFolders ""
    local Mcheck 0
    local Acheck 0

    * Loop through all folders. Folder case is normalized to lower() so
    * that the checks work on case-sensitive filesystems.
    foreach folder in `list' {

        local lfolder = lower("`folder'")

        * Extract list of master data only
        local Mflag = word(subinstr("`lfolder'","_"," ",.),-1)
        if ("`Mflag'" == "m") {
            local MFolders "`MFolders' `folder'"
            local Mcheck = 1
        }
        else {
            local Mflag = word(subinstr("`lfolder'","_"," ",.),-2)
            if ("`Mflag'" == "a") {
                local AFolders "`AFolders' `folder'"
                local Acheck = 1
            }
        }
    }

    if (`Mcheck'==0) & (`Acheck'==0) {
        noi di as err "No master or adaptation collections found in the path."
        exit 198
    }

    * Extract vintage numbers of Master data
    local Mvintagelist ""
    foreach folder in `MFolders' {
        local Mvintage = word(subinstr("`folder'","_"," ",.),-2)
        local Mvintage = "`Mvintage'00"
        local Mvintagelist "`Mvintagelist' `Mvintage'"
    }
    local Mvintagelist = trim(subinstr("`Mvintagelist'","v","",.))
    local Mlatestvintage = trim(word("`Mvintagelist'",-1))
    local Mnumvintages = wordcount("`Mvintagelist'")

    * Generate numeric equivalents of the vintage numbers
    local Mnumvintagelist ""
    foreach v in `Mvintagelist' {
        local numvintage = real(substr("`v'",1,2))
        local Mnumvintagelist "`Mnumvintagelist' `numvintage'"
    }
    local Mnumvintagelist = trim("`Mnumvintagelist'")

    * Extract vintage numbers of Adaptation data
    local Avintagelist ""
    if (`Acheck'==1) {
        foreach folder in `AFolders' {
            local MMAvintage = word(subinstr("`folder'","_"," ",.),-5)
            local AMAvintage = word(subinstr("`folder'","_"," ",.),-3)
            local MAvintage "`MMAvintage'`AMAvintage'"
            local Avintagelist "`Avintagelist' `MAvintage'"
        }
        local Avintagelist = trim(subinstr("`Avintagelist'","v","",.))
        local Alatestvintage = trim(word("`Avintagelist'",-1))
        local Anumvintages = wordcount("`Avintagelist'")

        * Generate numeric equivalents of the vintage numbers
        local Anumvintagelist ""
        foreach v in `Avintagelist' {
            local numvintage = real(substr("`v'",3,2))
            local Anumvintagelist "`Anumvintagelist' `numvintage'"
        }
        local Anumvintagelist = trim("`Anumvintagelist'")
        
    }

    * Return local macros with trimmed values
    return local Mcheck = `Mcheck'
    return local Acheck = `Acheck'

    return local MFolders = trim("`MFolders'")
    return local Mvintagelist = "`Mvintagelist'"
    return local Mlatestvintage = "`Mlatestvintage'"
    return local Mnumvintages = `Mnumvintages'
    return local Mnumvintagelist = "`Mnumvintagelist'"

    if (`Acheck'==1) {
        return local AFolders = trim("`AFolders'")
        return local Avintagelist = "`Avintagelist'"
        return local Alatestvintage = "`Alatestvintage'"
        return local Anumvintages = `Anumvintages'
        return local Anumvintagelist = "`Anumvintagelist'"
    }

end 

/*******************************************************
 Usage Examples:

 * Checks the vintage of data in the specified path for the 2014 DHS survey in Zimbabwe.
 _vcheck , path("D:\datalib\ZWE\ZWE_2014_DHS")
 return list

 * Checks the vintage of data in the specified path for the 2019 MICS survey in Zimbabwe.
 _vcheck , path("D:\datalib\ZWE\ZWE_2019_MICS")
 return list

 * Checks the vintage of data in the specified path for the 2014 DHS survey in Kenya.
 _vcheck , path("D:\datalib\KEN\KEN_2014_DHS")
 return list

 * Checks the vintage of data in the specified path for the 2019 MICS survey in Bangladesh.
 _vcheck , path("D:\datalib\BGD\BGD_2019_MICS")
 return list

*******************************************************

* Version History:
* v1.2.0 - 2024-08-18: Added generation of numeric equivalents of vintage numbers for both master and adaptation vintages; trimmed return values.
* v1.1.0 - 2024-08-15: Initial release with basic vintage checking functionality.
