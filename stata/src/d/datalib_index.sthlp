{smcl}
{* *! version 0.9.24  29jul2026}{...}
{vieweralsosee "datalib" "help datalib"}{...}
{vieweralsosee "datalib_explorer" "help datalib_explorer"}{...}
{vieweralsosee "datalib_files" "help datalib_files"}{...}
{viewerjumpto "Syntax" "datalib_index##syntax"}{...}
{viewerjumpto "Description" "datalib_index##description"}{...}
{viewerjumpto "The cost" "datalib_index##cost"}{...}
{viewerjumpto "Options" "datalib_index##options"}{...}
{viewerjumpto "Examples" "datalib_index##examples"}{...}
{viewerjumpto "Variables created" "datalib_index##vars"}{...}
{viewerjumpto "Stored results" "datalib_index##results"}{...}
{cmd:help datalib_index}{right:Version 0.9.24}
{hline}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:datalib_index}
{cmd:,}
[{it:options}]

{p 8 17 2}
{cmd:datalib} {cmd:,} {opt index} [{it:options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt root(string)}}tree to walk; defaults to {cmd:${datalib}}{p_end}
{synopt:{opt path(string)}}subtree to start from, relative to {opt root()}{p_end}
{synopt:{opt maxn:odes(#)}}stop after this many folders; default 400{p_end}
{synopt:{opt maxd:epth(#)}}stop at this depth; 0 (default) means no limit{p_end}
{synopt:{opt dirs}}also emit one row per folder, not only per file{p_end}
{synopt:{opt sizes}}measure each file (slow: about 1.4 s per file over SMB){p_end}
{synopt:{opt pat:tern(string)}}only files matching this; default {cmd:*}{p_end}
{synopt:{opt clear}}permit replacing the data in memory{p_end}
{synopt:{opt sav:ing(filename)}}also save the index{p_end}
{synopt:{opt replace}}overwrite {opt saving()}{p_end}
{synoptline}
{p2colreset}{...}

{marker description}{...}
{title:Description}

{pstd} {cmd:datalib_index} walks a subtree recursively and returns it as a {bf:dataset}
-- one row per file, and with {opt dirs} one per folder as well. {cmd:datalib , index}
is the same command from the legacy option surface.

{pstd} {bf:Why this is not} {helpb datalib_explorer}{bf:.} {cmd:explorer} answers "what
is in {it:this} folder" and returns it in {cmd:r()}. That is the right shape for
browsing and the wrong shape for work. Reaching one file five levels down takes five
separate calls, and what you have at the end is a display rather than something you can
{helpb tabulate}, {helpb merge} or {helpb export}. {cmd:r()} could not hold the answer
anyway: a macro cannot carry 2,548 rows. So {cmd:index} pays the walk once and hands
back data.

{pstd} It shares {cmd:explorer}'s three rules -- paths are used exactly as given, casing
is preserved, and there is no library test, so it works on trees that were never named
to the grammar. It does {bf:not} compute checksums; see
{help datalib_index##cost:The cost} for where that belongs.

{marker cost}{...}
{title:The cost}

{pstd}
{bf:Measured, not estimated.} On {cmd:<staging-tree>} the walk costs about
{bf:0.35 seconds per folder}, and that figure is near-constant across subtrees of very
different size:

{p2colset 8 34 36 2}{...}
{p2col:{it:Spain}}a large branch, thousands of files{space 4}about nine minutes{p_end}
{p2col:{it:Brazil}}a mid-sized branch, hundreds of files{space 6}about a minute{p_end}
{p2col:{it:Afghanistan}}a small branch, hundreds of files{space 6}well under a minute{p_end}
{p2colreset}{...}

{pstd}
That is SMB round-trip latency on each directory open, not overhead in this command. A
single bulk enumeration is no faster: PowerShell's {cmd:Get-ChildItem -Recurse}, which
walks the whole subtree in one process, took {bf:538 s} on {it:the same branch} and found the same
folders and thousands of files. {bf:There is no fast path from one thread.}

{pstd}
Two consequences worth knowing before you start something long:

{phang2}
1. The whole staging tree -- every country -- is a {bf:6-to-8 hour} walk. That is why
{opt maxnodes()} defaults to 400 rather than infinity, and why hitting the cap is
{bf:announced} rather than silent. For whole-archive work use the scheduled catalogue
under {cmd:<catalogue>}: it pays the same per-folder cost, but in parallel,
off-hours, and it stores the checksums this command deliberately does not
compute.{p_end}

{phang2}
2. {opt sizes} is a second, larger cost on top. Stata cannot read a file's size without
{it:opening} the file, about 1.4 s each over SMB, so {it:Spain} with {opt sizes} is
roughly an hour beyond the walk itself.{p_end}

{pstd}
Progress is printed every 25 folders, and {helpb break:Break} stops the walk.

{marker options}{...}
{title:Options}

{phang} {opt root(string)} is the tree to walk, defaulting to the {cmd:${datalib}}
global. As with {helpb datalib_explorer} it applies no library test and does not fold
case.

{phang} {opt path(string)} is the subtree to start from, relative to {opt root()}, used
exactly as given. Omit it to walk from the root -- but read
{help datalib_index##cost:The cost} first.

{phang} {opt maxnodes(#)} stops the walk after this many folders. Default 400, which is
about two and a half minutes. When it bites, {cmd:r(truncated)} is 1 and the dataset is
a {bf:prefix} of the subtree; the message says so and suggests a larger value with the
time it implies.

{phang} {opt maxdepth(#)} stops descending past this depth. The children of the starting
node are depth 1. {cmd:0}, the default, means no limit. Useful for a cheap survey of
shape before committing to a full walk.

{phang}
{opt dirs} emits a row for every folder as well as every file. Without it, folders are
still traversed and counted in {cmd:r(n_dirs)} -- they are simply not stored as rows.

{phang} {opt sizes} measures every file, filling the {cmd:bytes} variable. Without it
{cmd:bytes} is {bf:missing} rather than zero, because zero is a real size and a caller
must be able to tell {it:empty} from {it:not measured}.

{phang}
{opt pattern(string)} restricts which {it:files} are indexed, e.g. {cmd:pattern(*.dta)}.
Folders are always traversed regardless, or the walk could not reach anything.

{phang}
{opt clear} permits replacing the data in memory. Without it, and with data loaded, the
command refuses rather than discarding your work.

{phang}
{opt saving(filename)} also writes the index to disk; add {opt replace} to overwrite.

{marker examples}{...}
{title:Examples}

{pstd}One survey, folders and files, measured -- small enough to be quick:{p_end}
{phang2}{cmd:. datalib_index , root(<staging-tree>) path("Spain/1975 Vital Statistics") dirs sizes clear}{p_end}

{pstd}What kinds of file does a country hold?{p_end}
{phang2}{cmd:. datalib_index , root(<staging-tree>) path(Afghanistan) clear}{p_end}
{phang2}{cmd:. tabulate ext , sort}{p_end}

{pstd}Only the Stata datasets, saved for later:{p_end}
{phang2}{cmd:. datalib_index , path(Brazil) pattern(*.dta) clear saving(brazil_dta) replace}{p_end}

{pstd}Shape before commitment -- two levels only, to see what you are in for:{p_end}
{phang2}{cmd:. datalib_index , path(India) maxdepth(2) dirs clear}{p_end}

{pstd}Which branches have already been renamed to the grammar?{p_end}
{phang2}{cmd:. datalib_index , path(Brazil) dirs clear}{p_end}
{phang2}{cmd:. tabulate looks_grammar if is_dir}{p_end}

{marker vars}{...}
{title:Variables created}

{synoptset 20 tabbed}{...}
{synopt:{cmd:relpath}}path relative to {opt root()}, forward-slashed, original casing{p_end}
{synopt:{cmd:parent}}{cmd:relpath} of the containing folder; {cmd:.} at the top of the walk{p_end}
{synopt:{cmd:name}}final component{p_end}
{synopt:{cmd:ext}}lowercased, no dot; empty for a folder, {cmd:none} for a file with no extension{p_end}
{synopt:{cmd:depth}}1 for the children of the starting node{p_end}
{synopt:{cmd:is_dir}}1 folder, 0 file{p_end}
{synopt:{cmd:bytes}}size, or {bf:missing} when {opt sizes} was not given{p_end}
{synopt:{cmd:looks_grammar}}1 when this row's own name parses as {it:CCC}{cmd:_}{it:YYYY}{cmd:_}{it:SURVEY}{p_end}
{p2colreset}{...}

{pstd}
{bf:There are deliberately no country or survey columns.} The reason this command and
{helpb datalib_explorer} exist at all is that these trees do {it:not} follow the naming
grammar, so a built-in "component 1 is a country" would smuggle back exactly the
assumption they were written to avoid. Where a tree {it:does} follow it,
{cmd:split relpath , parse("/")} is one line and is yours to name.

{marker results}{...}
{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(root)}}the tree root, as given{p_end}
{synopt:{cmd:r(path)}}the subtree walked, relative to the root{p_end}
{p2colreset}{...}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(nodes)}}folders actually visited{p_end}
{synopt:{cmd:r(n_files)}}files indexed{p_end}
{synopt:{cmd:r(n_dirs)}}folders found, whether or not {opt dirs} stored them{p_end}
{synopt:{cmd:r(bytes)}}total measured size, or {cmd:-1} when {opt sizes} was not given{p_end}
{synopt:{cmd:r(truncated)}}1 when {opt maxnodes()} stopped the walk early{p_end}
{synopt:{cmd:r(seconds)}}wall-clock time of the walk{p_end}
{p2colreset}{...}

{pstd} {bf:Check} {cmd:r(truncated)} {bf:before trusting a total.} When it is 1 the walk
stopped, so the dataset describes a prefix of the subtree. The message reports how many
folders were {it:already queued}, and is explicit that the true remainder is larger: the
walk is breadth-first, so the children of folders never visited were never enumerated
and cannot be counted.

{marker also}{...}
{title:Also see}

{psee}
Online:  {helpb datalib}, {helpb datalib_explorer}, {helpb datalib_files},
{helpb datalib_root}
{p_end}
