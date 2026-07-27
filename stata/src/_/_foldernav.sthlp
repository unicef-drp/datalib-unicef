{smcl}
{hline}
{help datalib}{right:Version 1.0}
{cmd:help _foldernav}{right:Author: Joao Pedro Azevedo}
{right:Date: 2024-03-21}
{hline}

{title:Title}
{p2colset 9 24 22 2}{...}
{p2col :_foldernav}{hline 1} Folder Navigation Utility for datalib repository.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 16 2}{cmd:_foldernav} [varlist] {cmd:,} [{cmd:country(string)} {cmd:path(string)}
{cmd:subfoldr(string)} {cmd:filename(string)}]{p_end}

{title:Description}
{pstd}{cmd:_foldernav} is designed to navigate through folder structures in the datalib
repository, enabling the selection of subfolders based on the structure of the data
collection. It dynamically constructs folder paths and displays available options for
browsing the data repository structure.{p_end}
{pstd}{cmd:_foldernav} is a legacy internal helper retained for the {cmd:datalib}
dispatcher; new code should prefer the contract wrappers, e.g. {helpb datalib_browse} (see
{helpb datalib_api}).{p_end}

{title:Options}
{synoptset 27 tabbed}{...}
{synopthdr:Options}
{synoptline}
{synopt:{opt country(string)}}Specifies the country code to filter the folder navigation.
If not specified, all available countries are displayed. This option is optional.{p_end}
{synopt:{opt path(string)}}Specifies the base path for folder navigation. If not
specified, the global macro {cmd:${datalib}} is used by default. This option is
optional.{p_end}
{synopt:{opt subfoldr(string)}}Specifies the subfolder to navigate to. The folder depth is
determined by the number of underscore-separated tokens in the subfolder name. This option
is optional.{p_end}
{synopt:{opt filename(string)}}Specifies the filename for reference purposes during
navigation. This option is optional.{p_end}
{synoptline}

{title:Details}
{pstd}The {cmd:_foldernav} program automatically determines folder structure depth based
on the number of underscore-separated tokens in the subfolder specification (e.g.
{cmd:ZWE_2019_MICS} has 3 tokens):{p_end}
{p2colset 5 30 32 2}{...}
{p2col :Tokens{hline 1}}Path Construction{p_end}
{p2colset 5 30 32 2}{...}
{p2col :1}Single-level folder (a country){p_end}
{p2col :3}Two-level path: stub1/folder (a survey folder){p_end}
{p2col :5}Three-level path: stub1/stub1_stub2_stub3/folder (a master vintage
folder){p_end}
{p2col :8}Three-level path: stub1/stub1_stub2_stub3/folder (an adaptation vintage folder;
exactly 8 tokens){p_end}
{p2colreset}{...}

{pstd}Special handling is provided for DATA, DOC, and PROGRAMS subfolders, which list
their contents and provide clickable links back to the {cmd:datalib} command.{p_end}

{title:Examples}
{p 6 16 2}Display all available countries in the datalib repository:{p_end}
{p 8 12}{stata "_foldernav"}{p_end}

{p 6 16 2}Display all available surveys for Zimbabwe:{p_end}
{p 8 12}{stata "_foldernav, country(ZWE)"}{p_end}

{p 6 16 2}Navigate to a specific subfolder structure:{p_end}
{p 8 12}{stata "_foldernav, subfoldr(ZWE_2019_MICS)"}{p_end}

{p 6 16 2}Display data files in the DATA subfolder:{p_end}
{p 8 12}{stata "_foldernav, subfoldr(DATA)"}{p_end}

{title:Saved Results}
{pstd}{cmd:_foldernav} saves the following in {cmd:r()}:{p_end}
{synoptset 20 tabbed}
{synopthdr:Results}
{synoptline}
{synopt:{cmd:r(subfoldr)}}The current subfolder being navigated{p_end}
{synopt:{cmd:r(subfoldrN)}}The Nth level subfolder specification (where N is the depth
level){p_end}
{synopt:{cmd:r(fullfoldr)}}The complete folder path (for DATA, DOC, PROGRAMS
subfolders){p_end}
{synoptline}

{title:Author}
{p 4 4 2}Joao Pedro Azevedo (jpazevedo@unicef.org){p_end}

{title:Version}
{p 4 4 2}1.0{p_end}

{title:Date}
{p 4 4 2}2024-03-21{p_end}

{title:Also see}

{psee}
Related functions: {helpb datalib} {helpb _dlw} {helpb _mkdir} {helpb _ctrycheck}
{helpb _svycheck} {helpb _vcheck} {helpb _adaptcheck}
{p_end}
