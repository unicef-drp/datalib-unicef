{smcl}
{hline}
{help datalib}{right:Version 1.10}
{cmd:help _dlw}{right:Author: Joao Pedro Azevedo}
{right:Date: 2026-07-10}
{hline}

{title:Title}
{p2colset 9 24 22 2}{...}
{p2col :_dlw}{hline 1} Data Loading and Processing Engine.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 16 2}{cmd:_dlw} {cmd:,} {cmd:country(string)} [{cmd:year(string)}
{cmd:survey(string)} {cmd:MODule(string)} {cmd:filename(string)} {cmd:MASter}
{cmd:adaptation} {cmd:LATest} {cmd:collection(string)} {cmd:harmonization(string)}
{cmd:vm(string)} {cmd:va(string)} {cmd:DEBUG} {cmd:data} {cmd:doc} {cmd:programs}
{cmd:NOMerge} {cmd:clear}]{p_end}

{title:Description}
{pstd}{cmd:_dlw} is the loading engine behind {helpb datalib} and {cmd:datalib_load}. It
resolves a (country, year, survey) request to a vintage folder in the library, loads the
requested modules or files, and -- when several registry modules are selected -- merges
them on the explicit keys of the collection registry. It reads the library root from the
global {cmd:${datalib}} (the wrappers map {cmd:root()} and the {cmd:DATALIB_ROOT}
environment variable onto it; see {helpb datalib_api}).{p_end}

{pstd}Engine semantics (contract v1, since v1.10):{p_end}
{phang2}- Inputs are normalized once at the boundary: {cmd:country()}, {cmd:survey()}, and
{cmd:collection()} are trimmed and uppercased. Country matching is exact; survey folders
match the exact suffix {it:*_SURVEY} -- never substring.{p_end}
{phang2}- {cmd:master} and {cmd:adaptation}/{cmd:collection()} are mutually exclusive.
{cmd:collection()} implies {cmd:adaptation}; {cmd:adaptation} without {cmd:collection()}
defaults to the {cmd:HLT} collection.{p_end}
{phang2}- Vintages are numeric. {cmd:vm()}/{cmd:va()} accept {cmd:1}, {cmd:01}, {cmd:v01},
{cmd:V01}; when omitted they default to the numerically latest vintage found on disk
(never directory-listing or alphabetical order). When {cmd:year()} is omitted, the
numerically latest year among the matching survey folders is used.{p_end}
{phang2}- The resolved vintage folder is verified to exist before any load is
attempted.{p_end}
{phang2}- Merges use the explicit keys of the collection registry
({it:config/collections.yml}, mirrored in this program), validated per module with
{cmd:isid}: person-level modules chain {cmd:1:1} on the person keys, then household-level
modules attach {cmd:m:1} on the household keys. HLT keys:
{cmd:svy_id cluster_id household_id} (+ {cmd:line_number} for persons); IPUMS keys:
{cmd:svy_id household_id} (+ {cmd:line_number}). A module whose keys do not uniquely
identify its rows stops the merge with an actionable error.{p_end}
{phang2}- A person module whose registry line variable is not already {cmd:line_number} is
renamed to {cmd:line_number} on load (HLT {cmd:hhmembers}: {cmd:hh_line_number}). This
normalization and the provenance columns are the only schema changes a load makes.{p_end}
{phang2}- Provenance columns {cmd:ctrycode} and {cmd:year} are added when absent -- never
overwritten -- on every load, master and adaptation alike. Loaders never mutate data
values (the pre-1.10 {cmd:recode windex5 8=.} mutation was removed; apply
collection-specific recodes in harmonization code instead).{p_end}

{title:Options}
{synoptset 27 tabbed}{...}
{synopthdr:Options}
{synoptline}
{synopt:{opt country(string)}}Country code. Required. Matched exactly (after uppercasing)
against the country folders.{p_end}
{synopt:{opt year(string)}}Survey year. If not specified, the numerically latest available
year is used.{p_end}
{synopt:{opt survey(string)}}Survey acronym. If not specified, the last survey folder
listed for the country/year is used.{p_end}
{synopt:{opt MODule(string)}}Module(s) to load. For adaptation loads, defaults to all
registry modules of the collection (HLT: {cmd:household hhmembers adult children}; IPUMS:
{cmd:bh ch fs hh hl mn wm}). For {cmd:master} loads there is no registry, so
{cmd:module()} or {cmd:filename()} is required.{p_end}
{synopt:{opt filename(string)}}Target one specific file inside the resolved vintage
folder; combine with {cmd:data}, {cmd:doc}, or {cmd:programs}.{p_end}
{synopt:{opt MASter}}Load master (original) vintage files ({it:..._vNN_M}). Supported
since v1.10; requires {cmd:module()} or {cmd:filename()}. Mutually exclusive with
{cmd:adaptation}/{cmd:collection()}.{p_end}
{synopt:{opt adaptation}}Load adaptation files ({it:..._vNN_M_vNN_A_CLCT}). Without
{cmd:collection()}, the collection defaults to {cmd:HLT}.{p_end}
{synopt:{opt LATest}}Use the latest available year; set automatically when {cmd:year()} is
empty.{p_end}
{synopt:{opt collection(string)}}Adaptation collection ({cmd:HLT} and {cmd:IPUMS} are
registered). Specifying {cmd:collection()} implies {cmd:adaptation}. There is no
survey-based defaulting.{p_end}
{synopt:{opt harmonization(string)}}Accepted for compatibility; not currently used.
{cmd:r(harmonization)} returns the resolved vintage folder name.{p_end}
{synopt:{opt vm(string)}}Master vintage; part of every vintage folder name (master and
adaptation alike). Accepts {cmd:1}/{cmd:01}/{cmd:v01}/{cmd:V01}; defaults to the
numerically latest master on disk.{p_end}
{synopt:{opt va(string)}}Adaptation vintage (same spellings); defaults to the numerically
latest adaptation of the requested collection under the chosen master.{p_end}
{synopt:{opt DEBUG}}Enables noisy output for debugging.{p_end}
{synopt:{opt data}}With {cmd:filename()}: load the named data file from
{it:Data/Stata/}.{p_end}
{synopt:{opt doc}}With {cmd:filename()}: open the named document from {it:Doc/}. Has no
effect without {cmd:filename()}.{p_end}
{synopt:{opt programs}}With {cmd:filename()}: open the named file from {it:Programs/}. Has
no effect without {cmd:filename()}.{p_end}
{synopt:{opt NOMerge}}Do not merge when multiple modules are selected.{p_end}
{synopt:{opt clear}}Replace the data in memory.{p_end}
{synoptline}

{title:Examples}
{p 6 16 2}Load and merge all HLT modules of the 2019 MICS for Zimbabwe (latest
vintages):{p_end}
{p 8 12}{stata "_dlw , country(ZWE) year(2019) survey(MICS) collection(HLT) clear"}{p_end}

{p 6 16 2}Load one HLT module without merging ({cmd:adaptation} without {cmd:collection()}
defaults to HLT):{p_end}
{p 8 12}{stata "_dlw , country(ZWE) year(2019) survey(MICS) adaptation module(hhmembers) clear"}{p_end}

{p 6 16 2}Load a module from the master (original) files:{p_end}
{p 8 12}{stata "_dlw , country(ZWE) year(2019) survey(MICS) master module(household) clear"}{p_end}

{p 6 16 2}Omit the year to use the numerically latest available year:{p_end}
{p 8 12}{stata "_dlw , country(ZWE) survey(MICS) collection(HLT) clear"}{p_end}

{p 6 16 2}Load with debugging output enabled:{p_end}
{p 8 12}{stata "_dlw , country(ZWE) year(2019) survey(MICS) collection(HLT) DEBUG clear"}{p_end}

{p 6 16 2}Open one document from the vintage's {it:Doc/} folder ({cmd:doc} requires
{cmd:filename()}):{p_end}
{p 8 12}{cmd:. _dlw , country(ZWE) year(2019) survey(MICS) collection(HLT) filename(questionnaire.pdf) doc}{p_end}

{title:Saved Results}
{pstd}{cmd:_dlw} saves the following in {cmd:r()} (numbered per module/file, {it:#} = 1,
2, ...):{p_end}
{synoptset 20 tabbed}
{synopthdr:Results}
{synoptline}
{synopt:{cmd:r(filename{it:#})}}Name of each file loaded{p_end}
{synopt:{cmd:r(data{it:#})}}Full path of each data file loaded via
{cmd:filename() data}{p_end}
{synopt:{cmd:r(doc{it:#})}}Full path of each document opened via
{cmd:filename() doc}{p_end}
{synopt:{cmd:r(programs{it:#})}}Full path of each program file opened via
{cmd:filename() programs}{p_end}
{synopt:{cmd:r(harmonization)}}Resolved vintage folder name{p_end}
{synoptline}

{title:Author}
{p 4 4 2}Joao Pedro Azevedo (jpazevedo@unicef.org){p_end}

{title:Version}
{p 4 4 2}1.10{p_end}

{title:Date}
{p 4 4 2}2026-07-10{p_end}

{title:Version History}
{p 4 4 2}v1.10 (2026-07-10): Registry-keyed merges validated per module with {cmd:isid}
(person modules chain 1:1, hh modules attach m:1); person-line normalization to
{cmd:line_number}; removed the undocumented {cmd:recode windex5 8=.} mutation;
{cmd:vm()}/{cmd:va()} numeric-latest defaults and {cmd:1}/{cmd:01}/{cmd:v01}/{cmd:V01}
spellings; exact case-normalized country and survey-suffix matching; master files loadable
via {cmd:module()}/{cmd:filename()}; vintage-folder existence verified before load;
provenance columns on every load.{p_end}

{p 4 4 2}v1.01 (2024-08-18): Improved year/survey defaulting, module loading and merging
logic, debugging output, and error handling.{p_end}

{p 4 4 2}v1.00 (2024-03-21): Initial release.{p_end}

{title:Also see}

{psee}
Contract API: {helpb datalib_api}{break}
Related functions: {helpb datalib} {helpb _foldernav} {helpb _mkdir} {helpb _ctrycheck}
{helpb _svycheck} {helpb _vcheck} {helpb _adaptcheck}
{p_end}
