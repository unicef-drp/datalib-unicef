*==================================================
*project:       Equity Adjusted Coverage rate using Health outcomes  
*Author:        Joao Pedro Azevedo, Tashirik Ahmed, and George Mwinnyaa
*E-email:       jpazevedo@unicef.org
*Created:       18 March, 2024
*-----------------------------------------------------------------------------

version 15

quietly {
    }


* set paths
cap: mkdir "${rawdata}/datalib"
if (_rc==0) {
    noi di "Created datalib folder"
}
else {
    noi di "datalib folder already exists"
}

* collection name, this needs to be edited depending on the collection being organized.
* for instance, for the health collection, the collection name is "HLT". All collections will be in capital letters and have three letters.
local clct "HLT"


/*

The storage of data and other materials in Datalib is organized by country. One folder has been created for each country. The folder name is the ISO 3-letter code for each country, as spelled in the WDI and available through the wbopendata command in Stata3. As some datasets are multi-country, the following folders were also created:
- WLD: for datasets containing data from countries belonging to more than one region
- ECA: for datasets containing data from countries belonging to more than one country from ECA
If necessary, folders for other regions can be created here too. One folder will then be created for each survey. This folder name will be as follows:
CCC_YYYY_SSSS
where
- CCC = WDI country code (3 letters) (capitalized)
- YYYY = survey year (4 digits); we use the year when data collection started
- SSSS = survey acronym (e.g., LSMS, CWIQ, HBS, etc) (capitalized)

For instance, the folder for the HBS 2005 from Albania will be ALB_2005_HBS. For multi-country datasets, CCC will be WLD (World) or ECA.
One survey may have more than one version of the dataset. So under the survey folder, we will have as many sub-folders as we have versions. Even when we only have one version, we will create the sub-folder. The sub-folder name will identify the version.
The subfolder name will be as follows:

CCC_YYYY_SSSS_ vNN _M_vNN_A_CLCT

Where
- CCC = WDI country code (3 letters) (capitalized)
- YYYY = survey year; we use the year when data collection started
- SSSS = survey acronym (e.g., LSMS, CWIQ, HBS, etc) (capitalized)
- vNN_M = the “M” comes from Master file. The Master file is the full dataset, typically as provided by the country. vNN is the version name; NN is a sequential number; it will always start with 01 and when a newer version is available it should be named v02, then v03 etc. The description of the version will be found in the DDI metadata. Note that when a new version comes, the previous one(s) must be kept too.
- vNN_A_HHHH = “A” for Adaptations, and "CLCT” or "HHHH" for the name of the adaptation or collection. These are often subsets of the data, such as harmonized datasets; in our case, for now, the adaptions we have are ECAPOV, SILC and HOI. This part of the code will only appear when it’s not the original data, and it will be the name of the source folder where this data is being stored. The vNN follows the same rule as the numbering for original data, but this one refers for the version of the adaptation.
For instance, the harmonized dataset produced by PREM for the ECAPOV project using the Tajikistan Living Standards Survey of 2009 would be named “TJK_2009_TLSS_v01_M_v01_A_ECAPOV” (See figure 1). This sub-folder name is where we will store the Nesstar file (the Nesstar filename will be the same as the name of the folder), as well as the DDI and the Dublin Core XML files. All other materials (data in Stata or other format, documents, programs) will be stored in sub-folders as described below.
In the master version folder (in the case described, TJK_2009_TLSS_v01_M), we will create the following folders:
- “Data” to store the data files.
o “Data\Original”: Under “Data” one sub-folder “Original” is created to store the dataset as received. This dataset will always be kept unchanged (i.e. in whatever format we receive it). If necessary, additional sub-folders can be created (for instance, if the original dataset is provided in multiple formats).
o “Data\Stata”: For every survey, we will store the data in Stata format. This Stata files will be the ones obtained by exporting the microdata from the Nesstar file. The variable/value labels will thus be strictly identical to what we find in the Nesstar file.
o “Data\Other”: Optionally, we can also save the data files in other formats (e.g., SPSS or ASCII). Again, this will have to correspond exactly to the data stored in the Nesstar file.
- “Doc” to store the document files.
o “Doc\Questionnaires” to store all questionnaires (in PDF, XLS or other). Sub-folders can be created is needed.
o “Doc\Reports” to store the survey reports (and related, such as PPT presentations, papers, briefs, etc). Sub-folders can be created is needed.
o “Doc\Technical” to store all technical documents (code lists, interviewer’s manuals, sampling description, etc) and other materials such as photos, maps, etc. Sub-folders can be created is needed.
- “Programs” to store all programs: data entry, editing, tabulation, analysis. Sub-folders can be created if needed.
Note that all folders will be created, even if we do not have content for them (see Figure 2 for an example using Tajikistan 2009 TLSS).

How to name and organize the do files
For each country (CCC) and each year (YYYY), COLLECTION generates up to four datasets starting from the original survey (see Annex I for further details) using the format:

CCC_YYYY_SurveyName_vnn_M_vmm_A_COLLECTION_i 

where:
Collection     stands for the name of the collection of datasets (e.g., HLT, EDU, NUT, GMD, etc.);
vnn 		(nn=01, 02, … ) stands for the version of the master file;
vmm 	(mm=01, 02, …) stands for the version of the harmonization, as there can be revisions after the first release;
i	denotes the specific GMD dataset, and in particular: 
i=adult 	    Contains basic information collected for adults in the household;
i=children 	    Contains basic information collected for children in the household;
i=hhmembers 	Contains basic information collected for hhmembers in the household;
i=household 	Contains basic information collected for household;

*/

tempfile tmp

local list : dir "${inputdata_hlt}/" files "*.csv" 

*local list "batch1_s1_adult.csv" 

foreach file in `list' {

    di "`file'"

    if strmatch("`file'","batch*") == 1 {

        * extract type of survey: adult, children, hhmembers, household
        local type = word(subinstr(subinstr("`file'","_"," ",.),".csv","",.), -1)
        di "`type'"

        * import CSV data
        import delimited "${inputdata_hlt}/`file'", varnames(1) asdouble clear ///
             stringcols(1 2)
        describe
        local K = r(k)
        import delimited "${inputdata_hlt}/`file'", varnames(1) asdouble clear ///
             stringcols(1 2)  numericcols(3(1)`K')
        save `tmp', replace
            

        * create svy_id
        levelsof svy_id 
        foreach id in `r(levels)' {

            di "`id'"

                * keep single ctry year svy
                keep if svy_id == "`id'"

                * extract country, year and survey name
                local ctry = upper(word(subinstr("`id'","_"," ",.),1))
                local svy  = upper(word(subinstr("`id'","_"," ",.),2))
                local year = upper(word(subinstr("`id'","_"," ",.),3))

                *create ctry folder if it does not exist
                cap: mkdir "${rawdata}/datalib/`ctry'"
                if (_rc==0) {
                    noi di "Created `ctry' in datalib folder"
                }   
                else {
                    noi di "`ctry' in datalib folder already exists"
                }

                *create ctry folder if it does not exist
                cap: mkdir "${rawdata}/datalib/`ctry'/`ctry'_`year'_`svy'"
                if (_rc==0) {
                    noi di "Created `ctry'_`year'_`svy' in datalib folder"
                }   
                else {
                    noi di "`ctry'_`year'_`svy' in datalib folder already exists"
                }

                *create ctry folder if it does not exist
                cap: mkdir "${rawdata}/datalib/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_v01_M"
                if (_rc==0) {
                    noi di "Created `ctry'_`year'_`svy' in datalib folder"
                    cap: mkdir "${rawdata}/datalib/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_v01_M/Doc"
                    cap: mkdir "${rawdata}/datalib/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_v01_M/Data"
                    cap: mkdir "${rawdata}/datalib/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_v01_M/Programs"
                    cap: mkdir "${rawdata}/datalib/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_v01_M/Data/Original"
                    cap: mkdir "${rawdata}/datalib/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_v01_M/Data/Stata"                   
                    cap: mkdir "${rawdata}/datalib/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_v01_M/Data/Other" 
                }                  
                else {
                    noi di "`ctry'_`year'_`svy' in datalib folder already exists"
                }

                *create ctry folder if it does not exist
                cap: mkdir "${rawdata}/datalib/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_v01_M_v01_A_`clct'"
                if (_rc==0) {
                    noi di "Created `ctry'_`year'_`svy' in datalib folder and subfolders"
                    cap: mkdir "${rawdata}/datalib/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_v01_M_v01_A_`clct'/Doc"
                    cap: mkdir "${rawdata}/datalib/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_v01_M_v01_A_`clct'/Data"
                    cap: mkdir "${rawdata}/datalib/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_v01_M_v01_A_`clct'/Programs"
                    cap: mkdir "${rawdata}/datalib/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_v01_M_v01_A_`clct'/Data/Original"
                    cap: mkdir "${rawdata}/datalib/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_v01_M_v01_A_`clct'/Data/Stata"
                    cap: mkdir "${rawdata}/datalib/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_v01_M_v01_A_`clct'/Data/Other"
                }   
                else {
                    noi di "`ctry'_`year'_`svy' in datalib folder already exists"
                }

                compress

                * save
                save "${rawdata}/datalib/`ctry'/`ctry'_`year'_`svy'/`ctry'_`year'_`svy'_v01_M_v01_A_`clct'/Data/Stata/`ctry'_`year'_`svy'_v01_M_v01_A_`clct'_`type'.dta", replace

            use `tmp', clear

        }

    }
}




