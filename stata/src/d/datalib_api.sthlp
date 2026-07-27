{smcl}
{hline}
{cmd:help datalib_api}{right:Version 0.9.11}
{right:Authors: Joao Pedro Azevedo and Minh Cong Nguyen}
{right:Date: 2026-07-26}
{hline}

{title:Title}

{p2colset 5 24 26 2}{...}
{p2col:{bf:datalib_* API}}Contract v1 -- the shared datalib function surface{p_end}
{p2colreset}{...}

{title:Description}

{pstd}
The {cmd:datalib_*} commands are the Stata face of the language-neutral datalib
contract (also implemented in R and Python -- same names, same semantics; see
{it:config/grammar.md} in the repository). All follow the shared rules:
inputs are case-normalized once, matching is exact, vintages are numeric
("latest" = numeric maximum), loaders never mutate data (module loads add only the
provenance columns; a {cmd:filename()} load is returned exactly as stored), and the
library root
resolves from {opt root()} -> {cmd:${datalib}} -> env {cmd:DATALIB_ROOT} -> error.
The optional {cmd:datalib:} key in {cmd:~/.config/user_config.yml} enters this
chain through the global: {helpb getuserconfig} / {cmd:datalib_config} fills
{cmd:${datalib}} from it when the global is unset -- so a config-derived global
outranks the environment variable once loaded.

{title:Commands}

{p2colset 5 26 28 2}{...}
{p2col:{cmd:datalib_resolve}}Resolve (country, year, survey, kind, collection,
vintages) -> vintage folder and section paths. Pure; the conformance-critical
path algebra. Returns {cmd:r(vintage_folder)}, {cmd:r(file_stem)},
{cmd:r(data_stata)}, {cmd:r(doc)}, {cmd:r(programs)}, resolved
{cmd:r(master_version)}/{cmd:r(adaptation_version)}, ...{p_end}
{p2col:{cmd:datalib_catalog}}One-pass tree scan -> dataset in memory (requires
{opt clear}): one row per survey-vintage with country, year, survey, kind,
vintages, collection, folders. {cmd:r(n)}.{p_end}
{p2col:{cmd:datalib_countries}}{cmd:r(countries)} (sorted), {cmd:r(n)}.{p_end}
{p2col:{cmd:datalib_surveys}}Survey folders for a country; {cmd:r(surveys)},
{cmd:r(latest_year)}, {cmd:r(latest_survey)}, {cmd:r(n)}.{p_end}
{p2col:{cmd:datalib_vintages}}{cmd:r(masters)} (integers), {cmd:r(latest_master)},
{cmd:r(adaptations)} ({it:COLLECTION:vm:va} triples), {cmd:r(has_master)},
{cmd:r(has_adaptation)}.{p_end}
{p2col:{cmd:datalib_adaptations}}Unique adaptation collections;
{cmd:r(collections)}, {cmd:r(n)} (empty when none).{p_end}
{p2col:{cmd:datalib_files}}List files in a resolved vintage section
({opt section(data|data-original|data-r|data-other|doc|programs)}), optionally
filtered with {opt pattern()} (e.g. {cmd:pattern(*.dta)}); a missing section
directory is an empty listing, not an error. {cmd:r(files)},
{cmd:r(dir)}, {cmd:r(n)}.{p_end}
{p2col:{cmd:datalib_load}}Load (and merge) modules -- thin wrapper over the
{cmd:_dlw} engine with contract argument names: {opt modules()},
{opt kind(master|adaptation)}, {opt collection()}, {opt master_version()},
{opt adaptation_version()}, {opt nomerge}, {opt root()}. Also accepts
{opt filename()} to load one named file instead of registry modules,
{opt clear} to replace the data in memory, and {opt debug} for verbose
output.{p_end}
{p2col:{cmd:datalib_create}}Create (or, by default, only report) a vintage
folder tree {it:Data/{Original,Stata,R,Other}, Doc, Programs}. Without
{opt create} it is side-effect-free.{p_end}
{p2col:{cmd:datalib_config}}Canonical alias of {helpb getuserconfig}: reads
{cmd:~/.config/user_config.yml} and publishes the per-operator globals
(including {cmd:${datalib}} from the optional {cmd:datalib:} key). With
{opt init} it bootstraps a prepopulated configuration instead -- resolving the
library with {cmd:datalib_root, find} and handing the value to the generic
writer ({helpb _uc_init}); add {opt profile} to also install a startup
{it:profile.do}. The plain read never writes.{p_end}
{p2col:{cmd:datalib_root}}Resolve the library root in the Stata precedence
order ({opt root()} -> {cmd:${datalib}} -> env {cmd:DATALIB_ROOT}); returns
{cmd:r(root)}, {cmd:r(source_stage)}, {cmd:r(descended)}; {opt set} also fills
{cmd:${datalib}}. By default this is pure candidate selection, as in R and
Python: the first candidate present wins and the disk is never touched. Stata
returns the candidate as a literal string; R normalises it and Python returns a
{cmd:Path}, so the three agree on the resolved directory, not on its spelling. {opt find}
opts into Stata-only disk resolution -- a
candidate may name the library {it:or} the folder holding it
({it:cand}{cmd:/datalib} first, {cmd:r(descended)}=1), a directory that is not a
library is refused ({helpb _dl_islib}), a configured-but-missing root is an error
rather than being substituted, and a library named {cmd:datalib} is discovered
under {cmd:${zDrive}}/{cmd:Z:/} only when nothing is configured
({cmd:r(source_stage)}={cmd:discovered}). {opt find} is what {helpb datalib} uses;
the other wrappers take an exact {opt root()}. See {it:config/grammar.md} sec.7 and
{it:tests/DIVERGENCES.md}.{p_end}
{p2col:{cmd:datalib_browse}}Stateless navigation: returns the child choices of
one library node in {cmd:r(choices)} ({opt country()} -> survey folders;
a survey/vintage {opt path()} -> vintages/sections). {opt nodisplay} suppresses
the printed list and returns {cmd:r()} only, for programmatic callers;
{opt root()} names the library.{p_end}
{p2col:{cmd:datalib_map_drive}}Canonical alias of {helpb mapzdrive} (map the
configured network drive from the user config; Windows-only).{p_end}
{p2colreset}{...}

{title:Examples}

{phang}{stata datalib_countries}{p_end}
{phang}{cmd:. datalib_resolve, country(ZWE) year(2019) survey(MICS) collection(HLT)}{p_end}
{phang}{cmd:. datalib_load, country(ZWE) year(2019) survey(MICS) collection(HLT) modules(household adult children) clear}{p_end}
{phang}{cmd:. datalib_catalog, clear}{p_end}

{title:Conformance}

{pstd}
Golden cases live in {it:tests/} in the repository; run
{cmd:do stata/tests/run_conformance.do} from the repo root. Known divergences
from pre-0.5 behavior: {it:tests/DIVERGENCES.md}.

{title:Authors and acknowledgements}

{pstd}{cmd:datalib} is joint work by {bf:Joao Pedro Azevedo} and
{bf:Minh Cong Nguyen}: the contract this API implements -- the folder grammar, the
resolver and the harmonized-adaptation model -- was designed together. These
{cmd:datalib_*} wrappers are the Stata face of it; R and Python implement the same
contract.{p_end}

{pstd}{bf:Citation.} If you use {cmd:datalib} in your research, please cite the
design paper as a draft:{p_end}

{p 8 8 2}Azevedo, Joao Pedro and Nguyen, Minh Cong. {it:Harmonized Microdata Access}
{it:with datalib: A Framework for Survey Data Management in Stata}. 2026.
Unpublished working draft; not submitted or forthcoming. Kept in {it:paper/} in
{cmd:jpazvd/datalib-dev}.{p_end}

{title:Also see}

{psee}Online: {helpb datalib}, {helpb getuserconfig}, {helpb mapzdrive}{p_end}
