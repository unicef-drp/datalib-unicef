{smcl}
{hline}
{help datalib}{right:Version 1.0.0}
{cmd:help _adaptcheck}{right:Author: Joao Pedro Azevedo}
{right:Date: 2024-08-18}
{hline}

{title:Title}
{p2colset 9 24 22 2}{...}
{p2col :_adaptcheck}{hline 2}Datalib Adaptation Check Utility.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 16 2}{cmd:_adaptcheck}, {cmd:path(string)}{p_end}

{title:Description}
{pstd}{cmd:_adaptcheck} is a utility that checks the availability of adaptation folders in
a specified directory (datalib). It scans the subfolders of the given path for the
adaptation pattern ({cmd:_A_}), extracts the adaptation collection name from each matching
folder, and returns the list of names found and their count.{p_end}
{pstd}{cmd:_adaptcheck} is a legacy internal helper retained for the {cmd:datalib}
dispatcher; new code should prefer the contract wrappers, e.g. {helpb datalib_adaptations}
(see {helpb datalib_api}).{p_end}

{title:Filename Patterns}
{p 6 16 2}
- {cmd:<country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>}
{p_end}

{title:Folder Structure Patterns}
{p 6 16 2}
-
{cmd:datalib/<country>/<country>_<year>_<survey>/<country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>/}
{p_end}

{title:Examples}
{p 6 16 2}Checks the availability of adaptation files for the 2014 DHS survey in
Zimbabwe.{p_end}
{p 8 12}{stata "_adaptcheck , path(D:\datalib\ZWE\ZWE_2014_DHS)" : _adaptcheck , path(D:\datalib\ZWE\ZWE_2014_DHS)"}{p_end}

{p 6 16 2}Checks the availability of adaptation files for the 2019 MICS survey in
Bangladesh.{p_end}
{p 8 12}{stata "_adaptcheck , path(D:\datalib\BGD\BGD_2019_MICS)" : _adaptcheck , path(D:\datalib\BGD\BGD_2019_MICS)"}{p_end}

{p 6 16 2}Checks the availability of adaptation files for the 2014 DHS survey in
Kenya.{p_end}
{p 8 12}{stata "_adaptcheck , path(D:\datalib\KEN\KEN_2014_DHS)" : _adaptcheck , path(D:\datalib\KEN\KEN_2014_DHS)"}{p_end}

{title:Saved Results}
{pstd}{cmd:_adaptcheck} saves the following in {cmd:r()}:{p_end}
{synoptset 20 tabbed}
{synopthdr:Results}
{synoptline}
{synopt:{cmd:r(adaptations)}}List of adaptation collection names found. When none are
found, the sentinel value {cmd:"0"} (the string zero) is returned, not an empty
string.{p_end}
{synopt:{cmd:r(adaptcount)}}Number of adaptation folders found ({cmd:0} when none).{p_end}
{synoptline}

{title:Author}
{p 4 4 2}Joao Pedro Azevedo (jpazevedo@unicef.org){p_end}

{title:Version}
{p 4 4 2}1.0.0{p_end}

{title:Date}
{p 4 4 2}2024-08-18{p_end}

{title:Version History}
{pstd}{bf:v1.0.0} (2024-08-18): Initial release with functionality for checking the
availability and consistency of adaptation files within the datalib repository.{p_end}

{title:Also see}

{psee}
Supplementary functions: {helpb datalib} {helpb _dlw} {helpb _mkdir} {helpb _ctrycheck}
{helpb _svycheck} {helpb _vcheck} {helpb _adaptcheck}
{p_end}
