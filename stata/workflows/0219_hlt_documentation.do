*==================================================
*project:       D&A Datalib collection / SDG 2025 Report
*Author:        Joao Pedro Azevedo
*E-email:       jpazevedo@unicef.org
*Created:       7th December, 2024
*==================================================

* this script needs to be excecuted from the beining
* Define the country of interest and datalib path; if country omitted, the full root will be reviewed

local clct "datalib-hlt"  // Replace with the desired collection code
local datalib ${datalib_hlt}

 * This needs to be edited depending on the collection
 * Stubs: adult children hhmembers household
 * Input:  long fsizeadult long fsizechildren long fsizehhmembers long fsizehousehold
 * Output: (`fsizeadult') (`fsizechildren') (`fsizehhmembers') (`fsizehousehold')

*global datalib "C:/path/to/datalib"  // Replace with the correct datalib path


    tempfile filelist
    filelist, dir("${datalib_hlt}") save("`filelist'")


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



  noi di ""
  noi di ""
  noi disp as res "Start Documentation files (started at $S_TIME)..."


qui {

    * Create the directory mapping program using map_folders
    capture program drop map_folders
    program define map_folders
        syntax, folder(string) [Level(numlist min=0 max=10)]

        * Set default level if not provided
        if "`level'" == "" {
            local level 0
        }

        * List all directories within the specified folder
        local folder_list : dir "`folder'" dirs "*"

        * Loop through each directory found
        foreach subfolder in `folder_list' {

            * Print the folder path with indentation based on the level
            local indent = `level' * 4
            di `indent' "{hline 4} `folder'/`subfolder'"

            * Recursively call the program to map subfolders
            map_folders, folder("`folder'/`subfolder'") level(`=`level' + 1')
        }
    end


    * List all country folders for the specified root
    local country_list : dir "${datalib_hlt}/" dirs "*"

    * Create a frame to store the results
    cap frame drop survey_results
    frame create survey_results str10 ctry strL survey svyyear str10 svyname str10 masterVint str5 adaptVint str5 adapt ///
                            int original int stata int docs int progs strL modules 

    * Create a frame to store the results including filesize (adult children hhmembers household)
    cap frame drop survey_results_fsize
    frame create survey_results_fsize str10 ctry strL survey svyyear str10 svyname str10 masterVint str5 adaptVint str5 adapt ///
                            long fsizeadult long fsizechildren long fsizehhmembers long fsizehousehold

     * Create a frame to store the paths
    cap frame drop survey_path_results
    frame create survey_path_results str10 ctry strL survey strL version strL stata_path strL doc_path 

    * Loop through each country folder and count files
    foreach country in `country_list' {

        noi di ""
        noi disp as res "Documenting: `country'..."

        * List all survey folders for the specified country
        local survey_list : dir "${datalib_hlt}/`country'" dirs "*"

        * Loop through each survey folder and count files
        foreach survey in `survey_list' {

        noi disp as res "Survey `survey' found."

            * Extract the survey year and name from the folder name
            local survey_year = word(subinstr("`survey'", "_", " ", .), 2)
            local survey_name = upper(word(subinstr("`survey'", "_", " ", .), 3))

            * List available vintages and adaptations within the survey
            local versions : dir "${datalib_hlt}/`country'/`survey'" dirs "*_m*"

            foreach version in `versions' {
                * Check if it's a master vintage or a master+adaptation
                local is_adaptation = strpos("`version'", "_a_")

                if (`is_adaptation') {
                    * Extract adaptation details
                    local master_vintage = word(subinstr("`version'", "_", " ", .), 4)
                    local adaptation_vintage = word(subinstr("`version'", "_", " ", .), 6)
                    local adaptation_name = word(subinstr("`version'", "_", " ", .), 8)
                } 
                else {
                    * It's a master vintage only, set adaptation details to default values
                    local master_vintage = word(subinstr("`version'", "_", " ", .), 4)
                    local adaptation_vintage = ""
                    local adaptation_name = ""
                }

                * Construct folder paths
                local base_path "${datalib_hlt}/`country'/`survey'/`version'"
                local data_stata_path "`base_path'/Data/Stata"
                local data_other_path "`base_path'/Data"
                local data_original_path "`base_path'/Data/Original"
                local doc_path "`base_path'/Doc"
                local prog_path "`base_path'/Programs"

                * Initialize counts
                local data_stata_count 0
                local data_other_count 0
                local data_original_count 0
                local doc_count 0
                local prog_count 0
                local modules ""


                * Check and count original data files
                cap: local original_files : dir "`data_original_path'" files "*.*"
                if (_rc==0) {
                    if (`"`original_files'"' == `""') {
                        local data_original_count = 0
                        local original_file_path = "`data_original_path'"
                    } 
                    else {
                        local data_original_count = wordcount(`"`original_files'"')
                        local original_file_path = "`data_original_path'"
                    }
                }
                if (_rc!=0) {
                    local data_original_count = -9
                    local original_file_path = ""
                }

                * Check and count Stata data files
                cap: local stata_files : dir "`data_stata_path'" files "*.dta"
                if (_rc==0) {
                    if (`"`stata_files'"' == `""') {
                        local data_stata_count = 0
                        local stata_file_path = "`data_stata_path'"
                    } 
                    else {
                        local data_stata_count = wordcount(`"`stata_files'"')
                        local stata_file_path = "`data_stata_path'"
                        foreach file in `stata_files' {
                            local tmpmod = word(subinstr("`file'", "_", " ", .), -1)
                            local tmpmod = subinstr("`tmpmod'", ".dta", "", .)
                            local modules "`modules' `tmpmod'"
                            local modules = trim("`modules'")
                        }
                    }
                }
                if (_rc!=0) {
                    local data_stata_count = -9
                    local stata_file_path = ""
                }

                * Check and count other data files
                cap: local other_files : dir "`data_other_path'" files "*.*"
                if (_rc==0) {
                    if (`"`other_files'"' == `""') {
                        local data_other_count = 0
                        local other_file_path = "`data_other_path'"
                    } 
                    else {
                        foreach file in `other_files' {
                            if strpos("`file'",".dta")==0 {
                                local data_other_count = `data_other_count' + 1
                            }
                        }
                        local other_file_path = "`data_other_path'"
                    }
                }
                if (_rc!=0) {
                    local data_other_count = -9
                    local other_file_path = ""
                }

                * Check and count document files
                cap: local doc_files : dir "`doc_path'" files "*.*"
                if (_rc==0) {
                    if (`"`doc_files'"' == `""') {
                        local doc_count = 0
                        local doc_file_path = "`doc_path'"
                    } 
                    else {
                        *local doc_count = wordcount(`"`doc_files'"')
                        foreach file in `doc_files' {
                            if strpos("`file'",".zip")==0 {
                                local doc_count = `doc_count' + 1
                            }
                        }
                        local doc_file_path = "`doc_path'"
                    }
                }
                if (_rc!=0) {
                    local doc_count = -9
                    local doc_file_path = ""
                }

                * Check and count program files
                cap: local prog_files : dir "`prog_path'" files "*.*"
                if (_rc==0) {
                    if ("`prog_files'" == "") {
                        local prog_count = 0
                        local prog_file_path = ""
                    } 
                    else {
                        local prog_count = wordcount("`prog_files'")
                        local prog_file_path = ""
                    }
                }
                if (_rc!=0) {
                    local prog_count = -9
                    local prog_file_path = ""
                }

                foreach stub in adult children hhmembers household {
                    local fsize`stub' = 0
                }
                forvalue i = 1(1)`N' {
                    local loc`i' = upper("`loc`i''")
                    foreach stub in adult children hhmembers household {
                    local filenm = upper("`version'_`stub'")
                        if (strpos("`loc`i''","`filenm'") > 0) {
                            local fsize`stub' = word("`loc`i''",2)
                        }
                    }
                }

                * Ensure string variables are correctly quoted
                local stata_file_path = "`stata_file_path'"
                local doc_file_path = "`doc_file_path'"

                * Add results to the frame, ensuring string variables are enclosed in quotes
                frame post survey_results   ("`country'") ("`survey'")  ///
                                            (`survey_year') ("`survey_name'") ("`master_vintage'") ("`adaptation_vintage'") ("`adaptation_name'") ///
                                            (`data_original_count') (`data_stata_count') (`doc_count') (`prog_count') ("`modules'") 


        * Create a frame to store the results including filesize
                frame post survey_results_fsize     ("`country'") ("`survey'")  ///
                                                    (`survey_year') ("`survey_name'") ("`master_vintage'") ("`adaptation_vintage'") ("`adaptation_name'") ///
                                                    (`fsizeadult') (`fsizechildren') (`fsizehhmembers') (`fsizehousehold')


                local modules ""
                
                * Create a frame to store the paths
                *frame create survey_path_results str10 ctry strL survey strL version strL stata_path strL doc_path 
                * Add results to the frame, ensuring string variables are enclosed in quotes
                frame post survey_path_results ("`country'") ("`survey'") ("`base_path'") ///
                                        ("/Data/Stata") ("/Doc/")


            }
        }

    }

}
 
* Display results
*frame survey_results: list
*frame survey_path_results: list
//
* Additional display options or exporting to another format can be done using the frame commands

local clct "datalib-hlt"  // Replace with the desired collection code

local doc_path "${documentation}"

foreach ff in survey_results survey_results_fsize survey_path_results {

    /*-----------------------------------------------------------------------------
    survey results markdown  
    *-----------------------------------------------------------------------------*/
    
    if strmatch("`ff'", "survey_results")==1 {

        log using "`doc_path'/`clct'_`ff'.smcl", replace nomsg 

            frame survey_results: list

        log close

        markdoc "`doc_path'/`clct'_`ff'.smcl" , mini export(md) replace ///
            numbered style("formal")

    }

    /*-----------------------------------------------------------------------------
    survey results file size markdown  
    *-----------------------------------------------------------------------------*/
    
    if strmatch("`ff'", "survey_results_fsize")==1 {

        * Apply numeric formats to the variables
        frame change survey_results_fsize
        foreach var in adult children hhmembers household {
            format fsize`var' %9.1f
        }
        frame change default

        log using "`doc_path'/`clct'_`ff'.smcl", replace nomsg 

            frame survey_results_fsize: list

        log close

        markdoc "`doc_path'/`clct'_`ff'.smcl" , mini export(md) replace ///
            numbered style("formal")

    }

    /*-----------------------------------------------------------------------------
    survey path results markdown  
    *-----------------------------------------------------------------------------*/
    
    if strmatch("`ff'", "survey_path_results")==1 {

        log using "`doc_path'/`clct'_`ff'.smcl", replace nomsg 

            frame survey_path_results: list

        log close

        markdoc "`doc_path'/`clct'_`ff'.smcl" , mini export(md) replace ///
            numbered style("formal")

    }
 
  }

    /*-----------------------------------------------------------------------------
    survey path results markdown  
    *-----------------------------------------------------------------------------*/

    local ff map_folders

        log using "`doc_path'/`clct'_`ff'.smcl", replace nomsg 

            map_folders, folder("${datalib_hlt}") 

        log close

        markdoc "`doc_path'/`clct'_`ff'.smcl" , mini export(md) replace ///
            numbered style("formal")

    *-----------------------------------------------------------------------------
    * Erase all SMCL files

    local doc_path "${documentation}"

    noi disp as res ""
    noi disp as res _newline "Erase all SMCL files from documentation folder."

    local smcl_list : dir "`doc_path'/" files "*.smcl"

    foreach smcl in `smcl_list' {
        erase "`doc_path'/`smcl'"
    }

    *-----------------------------------------------------------------------------

    noi disp as res ""
    noi disp as res _newline "Done processing documentation files (finished at $S_TIME)."
    noi disp as res ""


/*-----------------------------------------------------------------------------
Summary of the do-file:

1. **Country and Path Definitions:**
   - The country of interest is defined using `local country "BRA"`.
   - The datalib path can be defined globally if necessary.

2. **Directory Mapping Program:**
   - A custom program `map_folders` is created to recursively list and map all 
   directories within a specified folder. The program prints folder paths with 
   an indentation level to represent the hierarchy.

3. **Survey Folder Listing and Frame Creation:**
   - All survey folders for the specified country are listed using `local survey_list`.
   - Two frames, `survey_results` and `survey_path_results`, are created:
     - `survey_results` stores survey details and counts of various data files.
     - `survey_path_results` stores paths to specific files within the survey folders.

4. **Loop Through Survey Folders:**
   - The do-file loops through each survey folder and its versions/adaptations.
   - For each version/adaptation:
     - Extracts year, name, and version details.
     - Constructs paths for data, documentation, and program files.
     - Counts the number of files in each category.
     - Stores results in `survey_results` and paths in `survey_path_results`.

5. **Frame Result Display:**
   - Results stored in the frames are displayed using `frame list`.

6. **Markdown Export:**
   - Results from the frames are exported to Markdown files using `markdoc`.
   - Three sections are exported: `survey_results`, `survey_path_results`, and `map_folders` output.

7. **Final Steps:**
   - The do-file exports the directory structure of the specified country’s data in the datalib repository to a Markdown file, documenting the folder hierarchy.

-----------------------------------------------------------------------------


* Apply numeric formats to the variables
frame survey_results_fsize {
    format fsizedom %9.2f
    format fsizepes %9.2f
    format fsizeboth %9.2f
    format fsizetri %9.2f
    format fsizeidbas %9.2f
    format fsizeidrs %9.2f
}
