{smcl}
{hline}
{cmd:help datalib}{right:Version 0.9.19}
{right:Authors: Joao Pedro Azevedo and Minh Cong Nguyen}
{right:Date: 2026-07-26}
{hline}

{title:Title}
{p2colset 5 27 32 2}{...}
{p2col :datalib}{hline 1} UNICEF Microdata Library: interactive navigation and data
loading.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 19 2}{cmd:datalib} [{cmd:,} {cmd:library(string)} {cmd:country(string)}
{cmd:year(string)} {cmd:survey(string)} {cmd:subfoldr(string)} {cmd:path(string)}
{cmd:module(string)} {cmd:filename(string)} {cmd:master} {cmd:adaptation} {cmd:latest}
{cmd:collection(string)} {cmd:harmonization(string)} {cmd:vm(string)} {cmd:va(string)}
{cmd:debug} {cmd:data} {cmd:doc} {cmd:programs} {cmd:nomerge} {cmd:clear}]{p_end}

{p 6 19 2}{cmd:datalib} {it:subcommand} [{cmd:,} {it:subcommand_options}]{p_end}

{pstd}where {it:subcommand} is one of the contract v1 wrappers
({help datalib##subcommands:see below}): {cmd:resolve}, {cmd:load}, {cmd:catalog},
{cmd:countries}, {cmd:surveys}, {cmd:vintages}, {cmd:adaptations}, {cmd:files},
{cmd:create}, {cmd:config}, {cmd:root}, {cmd:browse}, or {cmd:map_drive}.{p_end}

{title:Description}
{pstd}{cmd:datalib} is the interactive front end of the UNICEF Microdata Library. It
dispatches each call to one of two modes, depending on how complete the request is:{p_end}

{phang2}{bf:Interactive navigation.} A bare {cmd:datalib} opens a clickable country
picker. {cmd:country()} alone -- or {cmd:country()} with only one of
{cmd:year()}/{cmd:survey()} -- opens a clickable list of that country's survey folders.
{cmd:subfoldr()} jumps straight to a named library folder. Nothing is loaded in this mode;
the click-through links eventually issue a fully specified {cmd:datalib} call for
you.{p_end}

{phang2}{bf:Loading.} When {cmd:country()}, {cmd:year()}, and {cmd:survey()} are all
specified, the request is passed to the {helpb _dlw} engine, which resolves the vintage
folder and loads (and, for multiple modules, merges) the data. A load must also say
{it:what} to load: give {cmd:collection()} or {cmd:adaptation} (registry modules), or
{cmd:master} plus {cmd:module()}/{cmd:filename()}, or {cmd:filename()} directly.{p_end}

{pstd}Inputs are case-normalized once at the engine boundary: {cmd:country()},
{cmd:survey()}, and {cmd:collection()} are trimmed and uppercased, and matching is exact
(country) or exact-suffix (survey) -- never substring.{p_end}

{marker library}{...}
{title:Which library}
{pstd}On the {bf:legacy (option-only) surface} -- a bare {cmd:datalib}, navigation, or a
load -- the library is resolved before anything else, in this order:{p_end}

{p 8 12 2}1. {cmd:library({it:path})} -- outranks everything else.{p_end}
{p 8 12 2}2. {cmd:${datalib}} -- filled by {helpb getuserconfig} from the {cmd:datalib:}
key of {it:~/.config/user_config.yml} (see {helpb getuserconfig} for the two-file search),
then the {cmd:DATALIB_ROOT} environment variable.{p_end}
{p 8 12 2}3. {bf:Discovery} -- only when nothing at all is configured: a library named
{cmd:datalib} under {cmd:${zDrive}}, then {cmd:Z:/}.{p_end}

{pstd}A candidate may name {it:either} the library {it:or} the place holding it:
{it:path}{cmd:/datalib} is tried first, then {it:path} itself. So {cmd:library(Z:/)} and
{cmd:library(Z:/datalib)} both resolve to {cmd:Z:/datalib}, while a differently-named
library such as {cmd:Z:/datalib-hlt} is used as given. Backslashes and trailing separators
are normalized.{p_end}

{pstd}A directory that exists but is {bf:not} a library is refused, so a missing library
cannot quietly resolve to its parent -- whose subfolders would then be read as country
codes. A library is a directory named {cmd:datalib}, or carrying a {cmd:.datalib} marker,
or holding a {it:CCC}{cmd:/}{it:CCC}{cmd:_}{it:YYYY}{cmd:_}{it:SURVEY} pair (see
{helpb _dl_islib}).{p_end}

{pstd}A candidate that {it:is} set but is not a library -- a stale {cmd:library()},
{cmd:${datalib}} or {cmd:DATALIB_ROOT} -- is an {bf:error} (rc 198) naming the path. It is
never replaced by a discovered library: the substitution would be invisible afterwards.
Nothing configured and nothing discovered is likewise rc 198, naming {cmd:library()} --
rather than the bare {it:directory not found} that {helpb _foldernav} used to raise
later.{p_end}

{pstd}The resolved library is published to {cmd:${datalib}}, so it {bf:persists} for the
rest of the session -- the clickable navigation links carry no {cmd:library()} option and
must find the same library on the next call. Use {cmd:library()} again, or
{cmd:datalib root, root({it:path}) set}, to switch.{p_end}

{pstd}The library is validated {bf:once per session}: the validated value is recorded in
{cmd:${datalib_checked}} and the disk probes are skipped while {cmd:${datalib}} is
unchanged, which keeps a slow network share from being probed on every navigation click.
If the library moves or is unmounted mid-session it is not re-diagnosed -- pass
{cmd:library()} again, use {cmd:datalib root, root({it:path}) set}, or clear
{cmd:${datalib_checked}} to force revalidation.{p_end}

{pstd}{bf:One exception to all of the above.} Supplying {cmd:path()} {it:together with}
{cmd:subfoldr()} bypasses resolution entirely: the path is used as given, is not tested
for being a library, and is not published to {cmd:${datalib}}. This is the internal form
the clickable navigation links use -- so if {cmd:${datalib}} is not already set, the links
printed from such a call will not resolve.{p_end}

{pstd}{bf:The subcommand form is different.} {cmd:datalib} {it:subcommand} hands the call
straight to {cmd:datalib_}{it:subcommand}, which resolves its own root ({cmd:root()} ->
{cmd:${datalib}} -> {cmd:DATALIB_ROOT}, exact, no descent and no discovery) and leaves
{cmd:${datalib}} untouched. {cmd:library()} is not accepted by the root-taking wrappers --
use {cmd:root()}: {cmd:datalib countries, root(Z:/datalib-hlt)}.{p_end}

{pstd}Three subcommands are deliberate exceptions to that rule.
{cmd:datalib root, root({it:path}) set} {bf:writes} {cmd:${datalib}} -- that is how you
switch library for the session. {cmd:datalib root, find} opts into the same disk
resolution the legacy surface uses (container-or-library descent, then discovery).
{cmd:datalib config} publishes the operator's globals and fills {cmd:${datalib}} from the
{cmd:datalib:} key when it is unset; it also has its own, unrelated {cmd:library()}
option, which names the value to {it:write into} the user config rather than a library to
read -- see {helpb getuserconfig}.{p_end}

{pstd}{bf:The config chain is only read by the legacy surface.} A bare {cmd:datalib},
navigation or a load fills {cmd:${datalib}} from the config file for you on first use;
{cmd:datalib} {it:subcommand} does not read the config file at all. In a fresh session
with no startup {it:profile.do}, run {cmd:datalib config} once, or pass {cmd:root()},
before using the subcommand form.{p_end}

{pstd}{cmd:datalib} is also the front door to the scriptable, language-neutral
{cmd:datalib_*} wrapper family shared with the R and Python implementations: {cmd:datalib}
{it:subcommand} dispatches to {cmd:datalib_}{it:subcommand} unchanged, so
{cmd:datalib resolve, country(ZWE)} and {cmd:datalib_resolve, country(ZWE)} are the same
call -- see {help datalib##subcommands:Subcommands} and {helpb datalib_api}.{p_end}

{title:Options}
{synoptset 27 tabbed}{...}
{synopthdr:Options}
{syntab:Package maintenance (see {help datalib##update:Updating})}
{synopt:{opt update}}Check whether the net site this machine installed from holds a newer
{cmd:datalib} than the one installed, and report three coordinates: the installed version,
the site's version, and which way they differ. Reports only -- add {opt install} to act.
See {help datalib##update:Updating}.{p_end}
{synopt:{opt install}}With {opt update}: reinstall from the net site. Refuses to move you
{it:backwards} unless {opt force} is also given.{p_end}
{synopt:{opt force}}With {opt update install}: permit a downgrade. Only meaningful when
the net site is older than what is installed.{p_end}
{synopt:{opt netsource(string)}}The net site to check, for this call only. Default: the
source {cmd:net install} recorded for this machine, else {cmd:${datalib_netsource}}, else
{cmd:${zDrive}_statapkg}, else {cmd:Z:/_statapkg}.{p_end}
{synoptline}
{synopt:{opt lib:rary(string)}}The library to use for this call, outranking
{cmd:${datalib}}, the config chain and discovery. May name the library or the folder
holding it; a path that is not a library is an error. Publishes to {cmd:${datalib}}, so it
persists for the session. Legacy surface only -- the root-taking wrappers take
{cmd:root()} instead. (Unrelated to {cmd:datalib config}'s own {cmd:library()}, which
names a value to write into the user config.) See
{help datalib##library:Which library}.{p_end}
{synopt:{opt country(string)}}Country code (e.g. {cmd:ZWE}). Without both {cmd:year()} and
{cmd:survey()}, starts interactive navigation of the country's survey folders.{p_end}
{synopt:{opt year(string)}}Survey year. Loading requires {cmd:country()}, {cmd:year()} and
{cmd:survey()} together. {cmd:year()} or {cmd:survey()} {it:without} {cmd:country()} does
nothing at all: navigation starts only from {cmd:country()}, from {cmd:subfoldr()}, or
from a bare {cmd:datalib}.{p_end}
{synopt:{opt survey(string)}}Survey acronym (e.g. {cmd:MICS}, {cmd:DHS}). Same rule as
{cmd:year()} -- including that it does nothing without {cmd:country()}.{p_end}
{synopt:{opt subfoldr(string)}}A country, a {it:CCC_YYYY_SSSS} survey folder or a vintage
folder is opened directly. {cmd:DATA}, {cmd:DOC} and {cmd:PROGRAMS} are
{it:section links}: they resume from the vintage folder the previous {cmd:datalib} call
left in {cmd:r(subfoldr)}, so issued without that click-state they stop with rc 198
({it:the folder being navigated is no longer known}) -- re-run the navigation step, or
address the vintage directly with {cmd:country()}/{cmd:year()}/{cmd:survey()}. Used by the
clickable navigation links.{p_end}
{synopt:{opt path(string)}}Base path for the country / survey / vintage listings reached
via {cmd:subfoldr()}; defaults to {cmd:${datalib}}. The {cmd:DATA}, {cmd:DOC} and
{cmd:PROGRAMS} sections always resolve under {cmd:${datalib}} and {bf:ignore} {cmd:path()}
-- use {cmd:library()} or {cmd:datalib root, root({it:path}) set} to point at another
library.{p_end}
{synopt:{opt mod:ule(string)}}Module(s) to load. For adaptation loads, defaults to all
registry modules of the collection (HLT: {cmd:household hhmembers adult children}; IPUMS:
{cmd:bh ch fs hh hl mn wm}). For {cmd:master} loads there is no registry, so
{cmd:module()} or {cmd:filename()} is required.{p_end}
{synopt:{opt filename(string)}}Load or view one specific file inside the resolved vintage
folder; combine with {cmd:data}, {cmd:doc}, or {cmd:programs}.{p_end}
{synopt:{opt mas:ter}}Load master (original) vintage files ({it:..._vNN_M}). Requires
{cmd:module()} or {cmd:filename()}. Mutually exclusive with
{cmd:adaptation}/{cmd:collection()}.{p_end}
{synopt:{opt adaptation}}Load adaptation files ({it:..._vNN_M_vNN_A_CLCT}). Without
{cmd:collection()}, the collection defaults to {cmd:HLT}.{p_end}
{synopt:{opt latest}}Accepted for compatibility; {bf:not used} by the engine. The latest
year is selected whenever {cmd:year()} is empty, which cannot happen through {cmd:datalib}
-- a load requires {cmd:country()}, {cmd:year()} and {cmd:survey()} together.{p_end}
{synopt:{opt collection(string)}}Adaptation collection ({cmd:HLT} and {cmd:IPUMS} are
registered). Specifying {cmd:collection()} implies {cmd:adaptation}.{p_end}
{synopt:{opt harmonization(string)}}Accepted for compatibility; not currently used by the
engine. {cmd:r(harmonization)} returns the resolved vintage folder name.{p_end}
{synopt:{opt vm(string)}}Master vintage. Accepts {cmd:1}, {cmd:01}, {cmd:v01}, or
{cmd:V01}. Default: the numerically latest master vintage found on disk.{p_end}
{synopt:{opt va(string)}}Adaptation vintage (same spellings). Default: the numerically
latest adaptation of the requested collection under the chosen master.{p_end}
{synopt:{opt debug}}Verbose output for debugging.{p_end}
{synopt:{opt data}}With {cmd:filename()}: load the named data file from
{it:Data/Stata/}.{p_end}
{synopt:{opt doc}}With {cmd:filename()}: open the named document from {it:Doc/}.{p_end}
{synopt:{opt programs}}With {cmd:filename()}: open the named file from
{it:Programs/}.{p_end}
{synopt:{opt nom:erge}}Do not merge when multiple modules are loaded.{p_end}
{synopt:{opt clear}}Replace the data in memory.{p_end}
{synoptline}

{marker subcommands}{...}
{title:Subcommands}

{pstd}{cmd:datalib} {it:subcommand} [{cmd:,} {it:options}] runs
{cmd:datalib_}{it:subcommand} with the same options and returns its {cmd:r()} results
unchanged. Matching is exact and lowercase (no abbreviations), so existing option-only
calls are unaffected. The root-taking wrappers resolve the library root themselves
({cmd:root()} argument -> {cmd:${datalib}} -> {cmd:DATALIB_ROOT}); {cmd:config} and
{cmd:map_drive} take no {cmd:root()}. All thirteen are documented in {helpb datalib_api};
the two aliases additionally have their own pages, {helpb getuserconfig} and
{helpb mapzdrive}.{p_end}

{pstd}A first token that is {it:not} in the list below is never dispatched: it falls
through to the option-only surface, which rejects it as a syntax error -- there is no
{it:unknown subcommand} message, so check the spelling against the list. A bare
{cmd:datalib} is likewise not dispatched, and starts interactive navigation.{p_end}

{synoptset 27 tabbed}{...}
{synopthdr:Subcommand}
{synoptline}
{synopt:{cmd:resolve}}Resolve (country, year, survey, kind, collection, vintages) to one
vintage folder. See {helpb datalib_api}.{p_end}
{synopt:{cmd:load}}Load (and merge) modules from a resolved vintage.{p_end}
{synopt:{cmd:catalog}}One-pass tree scan into a dataset in memory.{p_end}
{synopt:{cmd:countries}}List the country folders of the library.{p_end}
{synopt:{cmd:surveys}}List a country's survey folders.{p_end}
{synopt:{cmd:vintages}}List master vintages of a survey.{p_end}
{synopt:{cmd:adaptations}}List unique adaptation collections.{p_end}
{synopt:{cmd:files}}List files in a resolved vintage section.{p_end}
{synopt:{cmd:create}}Create (or, by default, only report) a vintage folder
skeleton.{p_end}
{synopt:{cmd:config}}Read per-operator paths from the user config file(s); alias of
{helpb getuserconfig}.{p_end}
{synopt:{cmd:root}}Resolve (and optionally {cmd:set}) the library root.{p_end}
{synopt:{cmd:browse}}Stateless navigation: child choices of one library-tree node in
{cmd:r(choices)}.{p_end}
{synopt:{cmd:map_drive}}Map the configured network drive; alias of
{helpb mapzdrive}.{p_end}
{synoptline}

{title:Merging}
{pstd}When more than one module is loaded, modules are merged on the explicit keys of the
collection registry, validated per module with {cmd:isid}: person-level modules chain
{cmd:1:1} on the person keys, then household-level modules attach {cmd:m:1} on the
household keys. A module whose keys do not uniquely identify its rows stops the merge with
an actionable error (use {cmd:nomerge} to inspect modules singly). On every {bf:module}
load -- master and adaptation alike -- the provenance columns {cmd:ctrycode} and
{cmd:year} are added when absent and never overwritten. Loaders change nothing else. A
{cmd:filename()} load is different: a named file has no registry module, so it is loaded
exactly as stored -- no provenance columns are added and no merge keys are
inferred.{p_end}

{title:Subroutines}

{pstd}{cmd:datalib} relies on the following subroutines. They are legacy internals
retained for the dispatcher; new code should prefer the {cmd:datalib_*} wrappers
({helpb datalib_api}).{p_end}

{pstd}{help _foldernav}: interactive folder navigation (countries, surveys, vintages, and
the DATA/DOC/PROGRAMS sections).{p_end}

{pstd}{help _dlw}: the loading, processing, and merging engine.{p_end}

{pstd}{help _mkdir}: directory-structure creation for new deposits. Note {cmd:datalib}
does {it:not} call it -- the creation path is {helpb datalib_create}, which issues its own
{cmd:mkdir} calls; {cmd:_mkdir} is listed here only because it ships with the
package.{p_end}

{title:Return Macros}
{pstd}{cmd:datalib} returns whatever its subroutine returned ({cmd:return add}) --
{bf:except} a bare {cmd:datalib}, which returns nothing. The navigation click-state in
{cmd:r(subfoldr)} is propagated only by the {cmd:country()}, {cmd:subfoldr()} and load
forms, so a bare {cmd:datalib} issued between a navigation step and a
{cmd:DATA}/{cmd:DOC}/{cmd:PROGRAMS} click clears the state those links need.{p_end}

{pstd}From {cmd:_dlw} (numbered per module/file loaded):{p_end}
{pstd}{cmd:r(filename1)}, {cmd:r(filename2)}, ...: names of the files loaded.{p_end}
{pstd}{cmd:r(data1)}, ...: full paths of data files loaded via
{cmd:filename() data}.{p_end}
{pstd}{cmd:r(doc1)}, ...: full paths of documents opened via {cmd:filename() doc}.{p_end}
{pstd}{cmd:r(programs1)}, ...: full paths of program files opened via
{cmd:filename() programs}.{p_end}
{pstd}{cmd:r(harmonization)}: the resolved vintage folder name.{p_end}

{pstd}From {cmd:_foldernav}:{p_end}
{pstd}{cmd:r(subfoldr)}: the current subfolder being navigated.{p_end}
{pstd}{cmd:r(subfoldr{it:N})}: the subfolder at token depth {it:N}.{p_end}
{pstd}{cmd:r(fullfoldr)}: the complete folder path (for DATA, DOC, PROGRAMS
sections).{p_end}

{title:Verification subroutines used by {cmd:_mkdir}}

{pstd}{cmd:_ctrycheck} returns:{p_end}
{pstd}{cmd:r(ctrylist)}: list of unique country codes found in the directory.{p_end}
{pstd}{cmd:r(ctrynumb)}: number of unique country codes found.{p_end}

{pstd}{cmd:_svycheck} returns:{p_end}
{pstd}{cmd:r(svylist)}: list of unique survey names found.{p_end}
{pstd}{cmd:r(svynumb)}: number of unique surveys found (fixed to 1 when {cmd:survey()} is
passed).{p_end}
{pstd}{cmd:r(adptlist)}: list of unique adaptation collection names found.{p_end}
{pstd}{cmd:r(adptnumb)}: number of unique adaptation collections found.{p_end}
{pstd}{cmd:r(mastervintages)}, {cmd:r(masteradaptvintages)}, {cmd:r(adaptationvintages)}:
vintage lists.{p_end}
{pstd}{cmd:r(latestyear)}, {cmd:r(latestsurvey)}: latest survey year and name
found.{p_end}
{pstd}{cmd:r(multiplevintages)}, {cmd:r(mastercheck)}, {cmd:r(masteradaptcheck)},
{cmd:r(adaptationcheck)}: presence flags.{p_end}
{pstd}{cmd:r(masterfiles)}, {cmd:r(masteradaptfiles)}, {cmd:r(mavintage)},
{cmd:r(masterlatestfile)}, {cmd:r(masteradaptlatestfile)}: folder lists and combined
master+adaptation vintage strings.{p_end}

{pstd}{cmd:_vcheck} returns:{p_end}
{pstd}{cmd:r(Mcheck)}, {cmd:r(Acheck)}: master/adaptation presence flags.{p_end}
{pstd}{cmd:r(MFolders)}, {cmd:r(Mvintagelist)}, {cmd:r(Mlatestvintage)},
{cmd:r(Mnumvintages)}, {cmd:r(Mnumvintagelist)}: master folders and vintages.{p_end}
{pstd}{cmd:r(AFolders)}, {cmd:r(Avintagelist)}, {cmd:r(Alatestvintage)},
{cmd:r(Anumvintages)}, {cmd:r(Anumvintagelist)}: adaptation folders and vintages (only
when adaptations exist). "Latest" here reflects directory-listing order, not the numeric
maximum; see {helpb _vcheck}.{p_end}

{pstd}{cmd:_adaptcheck} returns:{p_end}
{pstd}{cmd:r(adaptations)}: list of adaptation collections found ({cmd:"0"} when
none).{p_end}
{pstd}{cmd:r(adaptcount)}: number of adaptation folders found.{p_end}

{title:Examples}
{p 6 16 2}Interactive navigation: pick a country, then click through to the data.{p_end}
{p 8 12}{stata "datalib" :. datalib}{p_end}

{p 6 16 2}Browse Zimbabwe's survey folders interactively (country alone navigates; it does
not load).{p_end}
{p 8 12}{stata "datalib , country(ZWE)" :. datalib , country(ZWE)}{p_end}

{p 6 16 2}Load and merge all HLT modules of the 2019 MICS for Zimbabwe (latest
vintages).{p_end}
{p 8 12}{stata "datalib , country(ZWE) year(2019) survey(MICS) collection(HLT) clear" :. datalib , country(ZWE) year(2019) survey(MICS) collection(HLT) clear}{p_end}

{p 6 16 2}Load two HLT modules without merging ({cmd:adaptation} without
{cmd:collection()} defaults to HLT).{p_end}
{p 8 12}{stata "datalib , country(ZWE) year(2019) survey(MICS) adaptation module(household adult) nomerge clear" :. datalib , country(ZWE) year(2019) survey(MICS) adaptation module(household adult) nomerge clear}{p_end}

{p 6 16 2}Load a module from the master (original) files.{p_end}
{p 8 12}{stata "datalib , country(ZWE) year(2019) survey(MICS) master module(household) clear" :. datalib , country(ZWE) year(2019) survey(MICS) master module(household) clear}{p_end}

{p 6 16 2}Open one document from the vintage's {it:Doc/} folder ({cmd:doc} requires
{cmd:filename()}).{p_end}
{p 8 12}{cmd:. datalib , country(ZWE) year(2019) survey(MICS) collection(HLT) filename(questionnaire.pdf) doc}{p_end}

{p 6 16 2}Work in a different library for this call ({cmd:library()} beats
{cmd:${datalib}} and discovery).{p_end}
{p 8 12}{cmd:. datalib , library(Z:/datalib-hlt) country(ZWE)}{p_end}

{p 6 16 2}Point at the {it:place} the library is stored in -- the {cmd:datalib} folder
inside it is found automatically.{p_end}
{p 8 12}{cmd:. datalib , library(Z:/) country(ZWE)}{p_end}

{p 6 16 2}Subcommand dispatch: the same wrapper calls, through the front door.{p_end}
{p 8 12}{stata "datalib countries" :. datalib countries}{p_end}
{p 8 12}{cmd:. datalib resolve, country(ZWE) year(2019) survey(MICS) collection(HLT)}{p_end}
{p 8 12}{cmd:. datalib load, country(ZWE) year(2019) survey(MICS) collection(HLT) modules(household adult children) clear}{p_end}
{p 8 12}{stata "datalib catalog, clear" :. datalib catalog, clear}{p_end}

{marker update}{...}
{title:Updating}

{pstd}{cmd:datalib , update} compares the {cmd:datalib} installed on this machine
against the net site it was installed from, and prints three coordinates: what is
installed, what the site advertises, and which way they differ. It writes nothing.
Add {opt install} to reinstall, and {opt force} only to permit a downgrade.{p_end}

{pstd}The installed version is not read from a {cmd:*!} stamp inside an ado-file:
this package bumps only the files whose contents changed, so an individual file's
stamp is not the package version. It comes from the {it:stata.trk} record that
{cmd:net install} writes -- {bf:except} when this command's own record is the later
of the two, for the reason in the next paragraph. Which record was used is reported
whenever the two disagree, and returned in {cmd:r(version_from)}.{p_end}

{pstd}{bf:Why there are two records.} {cmd:net install} appends its {it:stata.trk}
entry only when it actually copies something. When it judges the files already
current it prints {it:all files already exist and are up to date} and writes
nothing -- so its recorded version can lag the files on disk, and then this command
reports an update that is permanently available and that installing cannot clear,
because there is nothing left to copy. That happened on a real machine carrying
0.9.17 files under a 0.9.16 record. So every {opt install} also records the version
here, and the two records are ranked by {bf:recency, not by version number}: a
higher number does not win, because a deliberate downgrade performed with plain
{cmd:net install} would then be invisible, and not hiding downgrades is the whole
point of this command.{p_end}

{pstd}{bf:It also checks that it is describing the copy you will run.} All of the
above concerns the package in {cmd:PLUS}, which is where {cmd:net install} always
puts it. If the adopath resolves {it:datalib.ado} somewhere earlier -- a clone added
with {helpb adopath}, a copy in {cmd:PERSONAL} -- then the installed package is
shadowed and every version above describes files this session will not execute. That
path is printed when it happens, and returned in {cmd:r(running_from)}. Normal when
you are working from a clone; worth investigating otherwise.{p_end}

{pstd}The net site is resolved in this order: {opt netsource()} for one call, then
{cmd:${datalib_netsource}} for the session, then
{bf:the source remembered by the last install}, then
{bf:the source recorded for this machine} by {cmd:net install}, then
{cmd:${zDrive}_pkg/datalib/stata}, then {cmd:Z:/_pkg/datalib/stata}. The GitHub URL
is not a default: the repository is private, so an anonymous {cmd:net install}
answers HTTP 404.{p_end}

{pstd}{bf:It remembers where you installed from.} Every {opt install} writes the
source to {it:datalib_netsource.txt} beside the package, and every check reads it
back and reports it as {cmd:remembered}. Before this existed the only memory was
{cmd:net install}'s own {it:stata.trk} record, which nothing but {cmd:net install}
can write -- and that had a dead end. A machine whose recorded root had been
retired was told "the net site moved" on every check, under a status
({cmd:current}) that gives nobody a reason to install, so the advice to install
was unreachable and the notice never stopped. It now offers the re-point
explicitly, at the same version, whatever the status.{p_end}

{pstd}The remembered source is a {it:record}, not an {it:instruction}, and the
difference is deliberate: a root that has since been retired is redirected
forward, exactly as the {it:stata.trk} record is. An explicit {opt netsource()} or
{cmd:${datalib_netsource}} is never second-guessed. Persisting the global instead
would have been less code, but it would have made the next move of the net site
impossible to migrate automatically.{p_end}

{pstd}{bf:It will not silently downgrade you.} If the net site is {it:older} than
what you have installed, {opt install} is refused and says so. That guard exists
because the failure is real: a stale snapshot on this net site once downgraded a
working install and reinstated a data-mutation bug that contract v1 forbids. Text
comparison would not catch it either -- as strings, {cmd:0.9.10} sorts below
{cmd:0.9.9} -- so the comparison is numeric per component.{p_end}

{pstd}{bf:After installing, run} {cmd:discard} {bf:before using datalib again.}
Stata keeps ado-programs in memory once they are loaded, so the
files on disk are new but this session is still running the old ones -- a check
re-run immediately after installing reports the old behaviour and looks like a
failed update. Restarting Stata has the same effect as {cmd:discard}.{p_end}

{pstd}Stata's own {helpb adoupdate} will also reinstall from the recorded source.
The difference is that it answers a yes/no question and will move you in whichever
direction the source happens to point.{p_end}

{title:Authors}
{p 4 4 2}Joao Pedro Azevedo (jpazevedo@unicef.org){p_end}
{p 4 4 2}Minh Cong Nguyen{p_end}

{p 4 4 2}{cmd:datalib} began as joint work by the two authors on treating survey
microdata as a versioned, citable asset: the folder and naming grammar, the
resolver, and the harmonized-adaptation model this package still rests on. That
design is written up in an unpublished working draft (Azevedo and Nguyen), kept in
{it:paper/} in the canonical repository.{p_end}

{title:Version}
{p 4 4 2}0.9.19{p_end}

{title:Date}
{p 4 4 2}2026-07-26{p_end}

{title:Acknowledgements}

{pstd}This is the UNICEF adaptation of {cmd:datalib}, prepared for the UNICEF Chief
Statistician Office (CSO). The generic package and the design paper are developed
upstream in {cmd:jpazvd/datalib-dev}, from which this repository is built; the
public release of that generic package is {cmd:jpazvd/datalib}.{p_end}

{pstd}{cmd:datalib} is joint work with {bf:Minh Cong Nguyen}. The folder and naming
grammar, the resolver, and the harmonized-adaptation model that this package rests
on were designed together, and are written up in the paper cited below. This
repository is the UNICEF adaptation of that work; the generic package remains
upstream.{p_end}

{pstd}The conventions build on established harmonization practice rather than
inventing their own: the {bf:IHSN} cataloguing conventions, the World Bank
{bf:ECAPOV} harmonization guideline (ECATSD), {bf:GLAD} (Global Learning Assessment
Database), the {bf:SARMD} South Asia microdata base, and {bf:datalibweb}, the World
Bank Stata front end this package's architecture most closely resembles. The
vintage/adaptation model descends from the LAC handbook lineage. The reference
documents behind each are catalogued in {it:docs/pdf/} in the repository.{p_end}

{pstd}{bf:Citation.} If you use {cmd:datalib} in your research, please cite the
design paper as a draft:{p_end}

{p 8 8 2}Azevedo, Joao Pedro and Nguyen, Minh Cong. {it:Harmonized Microdata Access}
{it:with datalib: A Framework for Survey Data Management in Stata}. 2026.
Unpublished working draft; not submitted or forthcoming. Kept in {it:paper/} in
{cmd:jpazvd/datalib-dev}.{p_end}

{title:Version History}
{p 4 4 2}v0.9.1 to v0.9.18 (2026-07-25/26): {cmd:datalib , update} checks the net
site this machine installed from, reports installed-versus-published, and refuses to
downgrade; the library is validated once per session ({cmd:${datalib_checked}}); the
click-state survives root resolution; and the help pages were corrected against the
code (several options had documented behaviour the engine does not implement). Full
detail in {it:CHANGELOG.md}.{p_end}

{p 4 4 2}v0.9.0 (2026-07-25): {cmd:datalib} {it:subcommand} dispatch to the contract v1
{cmd:datalib_*} wrappers; {cmd:library()} option; the legacy surface resolves the library
up front in {cmd:find} mode (container-or-library, structural library test, discovery only
when nothing is configured) with an actionable error instead of a later
{it:directory not found}.{p_end}

{p 4 4 2}v0.7.0 (2026-07-10): Package root moved to {it:stata/}; {cmd:_dlw} engine
repaired (registry-keyed validated merges, no data mutation, numeric-latest vintage
defaults, exact case-normalized matching, master loading); contract v1 {cmd:datalib_*}
wrapper API added (see {helpb datalib_api}). Full history: {it:CHANGELOG.md} in the
repository.{p_end}

{p 4 4 2}v0.2 (2024-12-19): Refactored {cmd:_foldernav} into a standalone program file to
resolve a command recognition issue.{p_end}

{p 4 4 2}v0.1 (2024-08-18): Initial release with interactive folder navigation and data
loading utilities.{p_end}

{title:Also see}

{psee}
Contract API: {helpb datalib_api}{break}
Subroutines: {helpb _dlw} {helpb _foldernav} {helpb _mkdir} {helpb _ctrycheck}
{helpb _svycheck} {helpb _vcheck} {helpb _adaptcheck} {helpb _dl_islib}{break}
Configuration: {helpb getuserconfig} {helpb mapzdrive}
{p_end}
