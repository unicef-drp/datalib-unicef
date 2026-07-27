{smcl}
{hline}
{help datalib}{right:Version 1.2.0}
{cmd:help _vcheck}{right:Author: Joao Pedro Azevedo}
{right:Date: 2024-08-18}
{hline}

{title:Title}
{p2colset 9 24 22 2}{...}
{p2col :_vcheck}{hline 2}Datalib Vintage Check Utility.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 16 2}{cmd:_vcheck}, {cmd:path(string)}{p_end}

{title:Description}
{pstd}{cmd:_vcheck} checks the vintage of data archived in a specified directory (datalib)
by extracting and listing the vintage numbers of master and adaptation data collections.
This utility is particularly useful for managing and verifying the temporal coverage of
survey data stored in a structured repository.{p_end}
{pstd}The program identifies master and adaptation files, extracts their vintage numbers,
and returns information about the latest vintage available, the total number of vintages
identified, and their numeric equivalents. Note that the "latest" returns reflect
directory-listing order, not the numeric maximum (the pre-contract behavior recorded in
{it:tests/DIVERGENCES.md}).{p_end}
{pstd}{cmd:_vcheck} is a legacy internal helper retained for the {cmd:datalib} dispatcher;
new code should prefer the contract wrappers, e.g. {helpb datalib_vintages}, which
resolves "latest" as the numeric maximum (see {helpb datalib_api}).{p_end}

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

{title:Examples}
{p 6 16 2}Checks the vintage of data in the specified path for the 2014 DHS survey in
Zimbabwe.{p_end}
{p 8 12}{stata "_vcheck , path(D:\datalib\ZWE\ZWE_2014_DHS)" : _vcheck , path(D:\datalib\ZWE\ZWE_2014_DHS)"}{p_end}

{p 6 16 2}Checks the vintage of data in the specified path for the 2019 MICS survey in
Zimbabwe.{p_end}
{p 8 12}{stata "_vcheck , path(D:\datalib\ZWE\ZWE_2019_MICS)" : _vcheck , path(D:\datalib\ZWE\ZWE_2019_MICS)"}{p_end}

{p 6 16 2}Checks the vintage of data in the specified path for the 2014 DHS survey in
Kenya.{p_end}
{p 8 12}{stata "_vcheck , path(D:\datalib\KEN\KEN_2014_DHS)" : _vcheck , path(D:\datalib\KEN\KEN_2014_DHS)"}{p_end}

{p 6 16 2}Checks the vintage of data in the specified path for the 2019 MICS survey in
Bangladesh.{p_end}
{p 8 12}{stata "_vcheck , path(D:\datalib\BGD\BGD_2019_MICS)" : _vcheck , path(D:\datalib\BGD\BGD_2019_MICS)"}{p_end}


{title:Saved Results}
{pstd}{cmd:_vcheck} saves the following in {cmd:r()}:{p_end}
{synoptset 20 tabbed}
{synopthdr:Results}
{synoptline}
{synopt:{cmd:r(Mcheck)}}Indicates whether master data is present ({cmd:1}) or not
({cmd:0}).{p_end}
{synopt:{cmd:r(Acheck)}}Indicates whether adaptation data is present ({cmd:1}) or not
({cmd:0}).{p_end}
{synopt:{cmd:r(MFolders)}}List of folders containing master data.{p_end}
{synopt:{cmd:r(Mvintagelist)}}List of vintage numbers for the master data.{p_end}
{synopt:{cmd:r(Mlatestvintage)}}The latest vintage number found in the master data.{p_end}
{synopt:{cmd:r(Mnumvintages)}}Total number of vintage numbers found in the master
data.{p_end}
{synopt:{cmd:r(Mnumvintagelist)}}Numeric equivalents of the vintage numbers found in
{cmd:r(Mvintagelist)}.{p_end}
{synopt:{cmd:r(AFolders)}}List of folders containing adaptation data (if
applicable).{p_end}
{synopt:{cmd:r(Avintagelist)}}List of vintage numbers for the adaptation data (if
applicable).{p_end}
{synopt:{cmd:r(Alatestvintage)}}The last entry of {cmd:r(Avintagelist)} in
directory-listing order: a concatenated master+adaptation 4-digit string (e.g. {cmd:0101}
for master v01, adaptation v01) -- not the numeric maximum (if applicable).{p_end}
{synopt:{cmd:r(Anumvintages)}}Total number of vintage numbers found in the adaptation data
(if applicable).{p_end}
{synopt:{cmd:r(Anumvintagelist)}}Numeric equivalents of the vintage numbers found in
{cmd:r(Avintagelist)}.{p_end}
{synoptline}

{title:Author}
{p 4 4 2}Joao Pedro Azevedo (jpazevedo@unicef.org){p_end}

{title:Version}
{p 4 4 2}1.2.0{p_end}

{title:Date}
{p 4 4 2}2024-08-18{p_end}

{title:Version History}
{pstd}{bf:v1.2.0} (2024-08-18): Added generation of numeric equivalents of vintage numbers
for both master and adaptation vintages; trimmed return values.{p_end}
{pstd}{bf:v1.1.0} (2024-08-15): Initial release with basic vintage checking
functionality.{p_end}

{title:Also see}

{psee}
Suplementary functions: {helpb datalib} {helpb _dlw} {helpb _mkdir} {helpb _ctrycheck}
{helpb _svycheck} {helpb _vcheck} {helpb _adaptcheck}
{p_end}