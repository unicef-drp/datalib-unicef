{smcl}
{hline}
{help datalib}{right:Version 1.7.1}
{cmd:help _svycheck}{right:Author: Joao Pedro Azevedo}
{right:Date: 2024-08-18}
{hline}

{title:Title}
{p2colset 9 24 22 2}{...}
{p2col :_svycheck}{hline 1} Datalib Survey Check Utility.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 16 2}{cmd:_svycheck}, {cmd:path(string)} [{cmd:country(string)} {cmd:survey(string)}
{cmd:year(string)} {cmd:master} {cmd:adaptation}]{p_end}

{title:Description}
{pstd}{cmd:_svycheck} checks the surveys archived in a specified directory (datalib) by
extracting unique survey names based on the folder structure and filenames. This utility
is particularly useful for managing and verifying survey data stored in a structured
repository.{p_end}
{pstd}The program identifies and lists unique survey names by evaluating the directory
structure and filename patterns, and it supports filtering based on master and adaptation
file types. It also returns flags indicating the presence of multiple vintages, master and
adaptation files, and the latest survey year available.{p_end}
{pstd}{cmd:_svycheck} is a legacy internal helper retained for the {cmd:datalib}
dispatcher; new code should prefer the contract wrappers, e.g. {helpb datalib_surveys}
(see {helpb datalib_api}).{p_end}

{title:Filename Patterns}
{p 6 16 2}
- {cmd:<country>_<year>_<survey>_<vintage>_m}
{p_end}
{p 6 16 2}
- {cmd:<country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>}
{p_end}

{title:Folder Structure Patterns}
{p 6 16 2}
- {cmd:datalib/<country>/<country>_<year>_<survey>/<country>_<year>_<survey>_<vintage>_m/}
{p_end}
{p 6 16 2}
-
{cmd:datalib/<country>/<country>_<year>_<survey>/<country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>/}
{p_end}

{title:Options}
{synoptset 27 tabbed}{...}
{synopthdr:Options}
{synoptline}
{synopt:{opt path(string)}}Specifies the directory path to check for surveys. This option
is required.{p_end}
{synopt:{opt country(string)}}Specifies the country code to filter the survey search. This
option is optional.{p_end}
{synopt:{opt survey(string)}}Specifies the survey name to filter the search. This option
is optional.{p_end}
{synopt:{opt year(string)}}Specifies the year to filter the survey search. This option is
optional.{p_end}
{synopt:{opt master}}Indicates that the program should check for master files. This option
is optional.{p_end}
{synopt:{opt adaptation}}Indicates that the program should check for adaptation files.
This option is optional.{p_end}
{synoptline}

{title:Examples}
{p 6 16 2}Lists all unique surveys found in the {cmd:D:\datalib\} directory. Returns an
error if folder does not contain survey names.{p_end}
{p 8 12}{stata "_svycheck , path(D:\datalib\)" :. _svycheck , path(D:\datalib\)}{p_end}

{p 6 16 2}Lists all unique surveys found in the {cmd:D:\datalib\ZWE\} directory.{p_end}
{p 8 12}{stata "_svycheck , path(D:\\datalib\\ZWE\)" :. _svycheck , path(D:\datalib\ZWE\)}{p_end}

{p 6 16 2}Lists unique master surveys found in the {cmd:D:\datalib\KEN} directory.{p_end}
{p 8 12}{stata "_svycheck , path(D:\datalib\KEN) master" :. _svycheck , path(D:\datalib\KEN) master}{p_end}

{p 6 16 2}Lists unique adaptation surveys found in the {cmd:D:\datalib\MDG}
directory.{p_end}
{p 8 12}{stata "_svycheck , path(D:\datalib\MDG) adaptation" :. _svycheck , path(D:\datalib\MDG) adaptation}{p_end}

{p 6 16 2}Lists all unique surveys found in the {cmd:D:\datalib\ZWE\ZWE_2019_MICS}
directory.{p_end}
{p 8 12}{stata "_svycheck , path(D:\datalib\ZWE\ZWE_2019_MICS)" :. _svycheck , path(D:\datalib\ZWE\ZWE_2019_MICS")}{p_end}

{p 6 16 2}Checks the surveys available for a specific survey name in the {cmd:ZWE}
directory.{p_end}
{p 8 12}{stata "_svycheck , path(D:\datalib\ZWE\) country(ZWE) survey(MICS)" :. _svycheck , path(D:\datalib\ZWE\) country(ZWE) survey(MICS)}{p_end}

{p 6 16 2}Lists all surveys found in the {cmd:D:\datalib\ZWE\ZWE_2014_DHS}
directory.{p_end}
{p 8 12}{stata "_svycheck , path(D:\datalib\ZWE\zwe_2014_dhs\)" :. _svycheck , path(D:\datalib\ZWE\zwe_2014_dhs\")}{p_end}

{p 6 16 2}Lists all surveys found in the {cmd:D:\datalib\KEN\KEN_2014_DHS}
directory.{p_end}
{p 8 12}{stata "_svycheck , path(D:\datalib\KEN\ken_2014_dhs\)" :. _svycheck , path(D:\datalib\KEN\ken_2014_dhs\")}{p_end}

{title:Saved Results}
{pstd}{cmd:_svycheck} saves the following in {cmd:r()}:{p_end}
{synoptset 20 tabbed}
{synopthdr:Results}
{synoptline}
{synopt:{cmd:r(svylist)}}List of unique survey names{p_end}
{synopt:{cmd:r(svynumb)}}Number of unique surveys found (fixed to {cmd:1} when
{cmd:survey()} is passed, whether or not that survey exists){p_end}
{synopt:{cmd:r(adptlist)}}List of unique adaptation collection names found{p_end}
{synopt:{cmd:r(adptnumb)}}Number of unique adaptation collections found{p_end}
{synopt:{cmd:r(mastervintages)}}List of master vintages found{p_end}
{synopt:{cmd:r(masteradaptvintages)}}List of master vintages carried by adaptation
folders{p_end}
{synopt:{cmd:r(adaptationvintages)}}List of adaptation vintages found{p_end}
{synopt:{cmd:r(latestyear)}}The latest survey year found{p_end}
{synopt:{cmd:r(latestsurvey)}}The latest survey name found{p_end}
{synopt:{cmd:r(multiplevintages)}}Flag indicating if multiple vintages are found{p_end}
{synopt:{cmd:r(mastercheck)}}Flag indicating if master files are found{p_end}
{synopt:{cmd:r(masteradaptcheck)}}Flag indicating if adaptation folders carrying a master
vintage are found{p_end}
{synopt:{cmd:r(adaptationcheck)}}Flag indicating if adaptation files are found{p_end}
{synopt:{cmd:r(masterfiles)}}List of master vintage folders found{p_end}
{synopt:{cmd:r(masteradaptfiles)}}List of adaptation vintage folders found{p_end}
{synopt:{cmd:r(mavintage)}}Combined master+adaptation vintage strings (e.g.
{cmd:V01V01}){p_end}
{synopt:{cmd:r(masterlatestfile)}}Last master vintage folder in listing order{p_end}
{synopt:{cmd:r(masteradaptlatestfile)}}Last adaptation vintage folder in listing
order{p_end}
{synoptline}

{title:Author}
{p 4 4 2}Joao Pedro Azevedo (jpazevedo@unicef.org){p_end}

{title:Version}
{p 4 4 2}1.7.1{p_end}

{title:Date}
{p 4 4 2}2024-08-18{p_end}

{title:Also see}

{psee}
Suplementary functions: {helpb datalib} {helpb _dlw} {helpb _mkdir} {helpb _ctrycheck}
{helpb _svycheck} {helpb _vcheck} {helpb _adaptcheck}
{p_end}