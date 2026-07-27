{smcl}
{hline}
{help datalib}{right:Version 1.0}
{cmd:help _ctrycheck}{right:Author: Joao Pedro Azevedo}
{right:Date: 2024-08-15}
{hline}

{title:Title}
{p2colset 9 24 22 2}{...}
{p2col :_ctrycheck}{hline 1} Datalib Country Check Utility.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 16 2}{cmd:_ctrycheck}, {cmd:path(string)} [{cmd:master} {cmd:adaptation}]{p_end}

{title:Description}
{pstd}{cmd:_ctrycheck} checks the countries for which data is archived in the specified
directory ({cmd:path}) by extracting unique country codes from the folder names. This
utility is particularly useful for managing and verifying country-specific data stored in
a structured repository.{p_end}
{pstd}The program identifies and lists unique country codes by evaluating the directory
structure and filename patterns. The {cmd:master} and {cmd:adaptation} options are
accepted for syntax compatibility but are currently ignored -- no filtering is
applied.{p_end}
{pstd}{cmd:_ctrycheck} is a legacy internal helper retained for the {cmd:datalib}
dispatcher; new code should prefer the contract wrappers, e.g. {helpb datalib_countries}
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
-
{cmd:datalib/<country>/<country>_<year>_<survey>/<country>_<year>_<survey>_<vintage>_m/}{p_end}
{p 6 16 2}
-
{cmd:datalib/<country>/<country>_<year>_<survey>/<country>_<year>_<survey>_<mastervintage>_m_<adaptationvintage>_a_<adaptationname>/}{p_end}

{title:Options}
{synoptset 27 tabbed}{...}
{synopthdr:Options}
{synoptline}
{synopt:{opt path(string)}}Specifies the directory path to check for ctry codes. This
option is required.{p_end}
{synopt:{opt master}}Accepted but currently ignored (no master filtering is
applied).{p_end}
{synopt:{opt adaptation}}Accepted but currently ignored (no adaptation filtering is
applied).{p_end}
{synoptline}

{title:Examples}
{p 6 16 2}Lists all unique country codes found in the {cmd:D:\datalib\} directory.{p_end}
{p 8 12}{stata "_ctrycheck , path(D:\datalib\)" :. _ctrycheck , path(D:\datalib\)}{p_end}

{p 6 16 2}Lists all unique country codes found in the {cmd:D:\datalib\ZWE\}
directory.{p_end}
{p 8 12}{stata "_ctrycheck , path(D:\datalib\ZWE\)" :. _ctrycheck , path(D:\datalib\ZWE\)}{p_end}

{p 6 16 2}Lists all unique country codes found in the {cmd:D:\datalib\ZWE\ZWE_2019_MICS}
directory.{p_end}
{p 8 12}{stata "_ctrycheck , path(D:\datalib\ZWE\ZWE_2019_MICS)" :. _ctrycheck , path(D:\datalib\ZWE\ZWE_2019_MICS")}{p_end}

{title:Saved Results}
{pstd}{cmd:_ctrycheck} saves the following in {cmd:r()}:{p_end}
{synoptset 20 tabbed}
{synopthdr:Results}
{synoptline}
{synopt:{cmd:r(ctrylist)}}List of unique country codes{p_end}
{synopt:{cmd:r(ctrynumb)}}Number of unique country codes found{p_end}
{synoptline}

{title:Author}
{p 4 4 2}Joao Pedro Azevedo (jpazevedo@unicef.org){p_end}

{title:Version}
{p 4 4 2}1.0{p_end}

{title:Date}
{p 4 4 2}2024-08-15{p_end}

{title:Also see}

{psee}
Suplementary functions: {helpb datalib} {helpb _dlw} {helpb _mkdir} {helpb _ctrycheck}
{helpb _svycheck} {helpb _vcheck} {helpb _adaptcheck}
{p_end}