{smcl}
{* *! version 0.9.26  29jul2026}{...}
{vieweralsosee "datalib" "help datalib"}{...}
{vieweralsosee "datalib_browse" "help datalib_browse"}{...}
{vieweralsosee "datalib_files" "help datalib_files"}{...}
{viewerjumpto "Syntax" "datalib_explorer##syntax"}{...}
{viewerjumpto "Description" "datalib_explorer##description"}{...}
{viewerjumpto "Options" "datalib_explorer##options"}{...}
{viewerjumpto "Examples" "datalib_explorer##examples"}{...}
{viewerjumpto "Stored results" "datalib_explorer##results"}{...}
{cmd:help datalib_explorer}{right:Version 0.9.26}
{hline}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:datalib_explorer}
{cmd:,}
[{it:options}]

{p 8 17 2}
{cmd:datalib} {cmd:,} {opt explorer} [{it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt root(string)}}tree to walk; defaults to {cmd:${datalib}}{p_end}
{synopt:{opt path(string)}}node within it, relative to {opt root()}; omit for the root{p_end}
{synopt:{opt files}}accepted, but redundant: files are listed by default{p_end}
{synopt:{opt nofiles}}list folders only, suppressing the file listing{p_end}
{synopt:{opt sizes}}also measure the files (slow on a network share){p_end}
{synopt:{opt maxitems(#)}}cap the listing; default 400{p_end}
{synopt:{opt per:page(#)}}show the files this many at a time; 0 (default) shows all{p_end}
{synopt:{opt page(#)}}which page to show; default 1{p_end}
{synoptline}
{p2colreset}{...}

{marker description}{...}
{title:Description}

{pstd}
{cmd:datalib_explorer} walks a directory tree that does {it:not} follow the datalib
naming grammar. {cmd:datalib , explorer} is the same command reached from the legacy
option surface.

{pstd}
{bf:Why this is not} {helpb datalib_browse}{bf:.} Every other navigation path in this
package reconstructs a folder's ancestry from its own {it:name}: {helpb _foldernav}
counts underscores to rebuild
{it:CCC}{cmd:/}{it:CCC}{cmd:_}{it:YYYY}{cmd:_}{it:SURVEY}{cmd:/},
and {helpb datalib_browse} does the same after uppercasing the path. That is right
inside the grammar, where a name encodes its parents, and useless outside it: a folder
called {it:raw datasets} says nothing about which survey it belongs to. On top of that
{helpb _dl_islib} refuses to start at all on a non-library tree.

{pstd}
So this command follows three different rules. Every link carries the {bf:full} relative
path rather than reconstructing it. Casing is preserved -- Stata's {cmd:: dir} macro
extension lowercases on Windows, returning {it:afghanistan} for {it:Afghanistan}, so the
directory is read through Mata instead. And there is no library test at all: the only
precondition is that the directory exists. A missing node is an error
({search r(601):r(601)}), not a silent empty listing.

{pstd}
{bf:A marker file is not a substitute.} Dropping a {cmd:.datalib} file into an arbitrary
tree would satisfy {helpb _dl_islib} and let the ordinary navigation start -- which would
then compute wrong parent paths and follow them silently. Refusing to start is better
than navigating to the wrong place.

{marker options}{...}
{title:Options}

{phang}
{opt root(string)} is the tree to walk. It defaults to the {cmd:${datalib}} global, so
the common case needs no argument. Unlike {helpb datalib_root} it applies no library
test, and unlike {helpb datalib_browse} it does not uppercase what it is given.

{phang}
{opt path(string)} is the node to open, relative to {opt root()}, used {bf:exactly} as
given -- no case folding, no separator guessing. Forward and backward slashes are both
accepted as separators; leading ones are ignored. Omit it for the root of the tree.

{phang}
{opt nofiles} lists folders only. Files are shown {bf:by default} -- and that is a change
from 0.9.24, where they were hidden unless {opt files} was given. Hiding them bought
nothing: the file names are fetched on every node regardless, because {cmd:r(n_files)}
needs them, so the option only decided whether to print strings already in memory. Worse,
the hint that said "add {bf:files} to list them" could not be {it:clicked}: the links this
command emits carry the current call's options, so a session begun without {opt files}
propagated {opt files}-less links forever and the advice was unreachable.

{phang}
{opt files} is still accepted and now does nothing. {cmd:r(files)} is populated either
way -- {opt nofiles} affects the display only.

{phang}
{opt sizes} also measures the files, populating {cmd:r(bytes)},
{cmd:r(largest)} and {cmd:r(largest_bytes)}. It is off by default because Stata cannot
read a file's size without opening it, and an open over a network share costs about
1.4 seconds regardless of how big the file is -- a node with 200 files takes five
minutes. Without this option {cmd:r(bytes)} is {cmd:-1}, meaning {it:not measured}
rather than zero.

{phang} {opt perpage(#)} shows the files this many at a time. {cmd:0}, the default,
shows all of them. See {help datalib_explorer##results:Stored results} for what does and
does not change when it is in force.

{phang}
{opt page(#)} selects the page, counting from 1. A value past the last page clamps to it.

{phang}
{opt maxitems(#)} caps how many folders and how many files are listed and stored.
Default 400. The counts in {cmd:r(n_dirs)} and {cmd:r(n_files)} always report the
{it:true} totals, and {cmd:r(truncated)} is 1 when the cap bit.

{title:Clickable file names}

{pstd} File names are hyperlinks, and what a click {it:does} depends on the type --
because a link that looks like one and does nothing is worse than plain text:

{p2colset 8 26 28 2}{...}
{p2col:{cmd:.dta}}{cmd:describe using} it{p_end}
{p2col:text formats}open in the {helpb view:viewer} -- including the DHS and SPSS
companions ({cmd:.dct} {cmd:.frq} {cmd:.frw} {cmd:.map} {cmd:.as} {cmd:.var} {cmd:.ivd}
{cmd:.sps}), which is most of the point: you can read a codebook beside the data it
describes{p_end}
{p2col:anything else}handed to the operating system, so {cmd:.pdf} {cmd:.xlsx} {cmd:.sav}
{cmd:.zip} open in whatever owns them{p_end}
{p2colreset}{...}

{pstd} {cmd:describe using} rather than {cmd:use}, deliberately: clicking a name in a
file browser should not silently replace the data in memory. It answers
{it:what is in this?}, which is the question someone exploring an archive is actually
asking, and loading it is then one command away and yours to type.

{pstd}
The buckets come from the archive rather than from taste -- across the tens of thousands of files in the
inventory, {cmd:.dta} is 31.5%, text companions about 22%, and formats Stata cannot read
about 36%.

{pstd} A name containing a double quote is printed as plain text rather than linked,
since that is what would break the quoting of the generated command. An {it:ampersand}
is linked: the first version refused those too, which measured against the real archive
would have cost 406 files for nothing, because the shell treats such characters as
syntax only outside quotes.

{title:Reading a long listing in pieces}

{pstd}
{opt perpage(#)} shows the files a fixed number at a time, with clickable
{bf:next} and {bf:prev} links, and a line saying where you are:

{p 8 12}{cmd:. datalib_explorer , path(Tajikistan/2012 DHS/Working Datasets) perpage(20)}{p_end}

{pstd}
{bf:This is not} {opt maxitems()}{bf:, and the difference matters.} {opt maxitems()}
{it:truncates}: the files past it are genuinely absent from {cmd:r(files)} and
{cmd:r(truncated)} is 1 to say the answer is a prefix. {opt perpage()} only slices what is
{it:displayed} -- {cmd:r(n_files)}, {cmd:r(files)} and the extension summary continue to
describe the whole node. A pager that quietly shrank the counts would be the
silent-partial-answer defect this command has already been fixed for once.

{pstd} {opt perpage()} travels with you as you navigate, because it is a preference.
{opt page()} does not: descending into a folder starts at that folder's beginning, not
at page 7 of a listing that had nothing to do with it. A {opt page()} past the end
clamps to the last page rather than showing nothing, since an empty listing and a
mistyped page number look identical on screen.

{pstd} A node with more than 30 files offers a {bf:show 20 at a time} link, so the
option does not have to be remembered.

{marker examples}{...}
{title:Examples}

{pstd}The root of the default library:{p_end}
{phang2}{cmd:. datalib_explorer}{p_end}

{pstd}Some other tree, one level down, with its files and their sizes:{p_end}
{phang2}{cmd:. datalib_explorer , root(<staging-tree>) path(Afghanistan) files sizes}{p_end}

{pstd}Folder names containing spaces need no special handling:{p_end}
{phang2}{cmd:. datalib_explorer , root(<staging-tree>) path(Afghanistan/2010 SDHS)}{p_end}

{pstd}The same thing from the legacy option surface, where {opt library()} supplies the
root:{p_end}
{phang2}{cmd:. datalib , explorer library(<staging-tree>) path(Afghanistan)}{p_end}

{pstd}Walking a tree programmatically rather than by clicking -- which folders under the
root have already been renamed to the grammar:{p_end}
{phang2}{cmd:. datalib_explorer , root(<staging-tree>)}{p_end}
{phang2}{cmd:. local top `"`r(dirs)'"'}{p_end}
{phang2}{cmd:. foreach d of local top {c -(}}{p_end}
{phang2}{cmd:.     datalib_explorer , root(<staging-tree>) path(`"`d'"')}{p_end}
{phang2}{cmd:.     di "`d': grammar=" r(looks_grammar) " dirs=" r(n_dirs)}{p_end}
{phang2}{cmd:. {c )-}}{p_end}

{marker results}{...}
{title:Stored results}

{pstd}
The {cmd:r()} surface is as much the point as the display: it is enough to walk a tree
programmatically, summarise it, or hand a path to {helpb _dlw}.

{pstd}
{cmd:datalib_explorer} stores the following in {cmd:r()}:

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(root)}}the tree root, as given{p_end}
{synopt:{cmd:r(path)}}relative path of this node; empty at the root{p_end}
{synopt:{cmd:r(fullpath)}}root and path joined, forward-slashed{p_end}
{synopt:{cmd:r(parent)}}relative path of the parent; {cmd:.} at depth 1, empty at the root{p_end}
{synopt:{cmd:r(dirs)}}child folders, each quoted, original casing{p_end}
{synopt:{cmd:r(files)}}child files, each quoted, original casing{p_end}
{synopt:{cmd:r(exts)}}distinct extensions among the files listed, lowercased, no dot; {cmd:none} for a file without one{p_end}
{synopt:{cmd:r(largest)}}name of the largest file listed, when {opt sizes} was given{p_end}
{p2colreset}{...}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(depth)}}0 at the root{p_end}
{synopt:{cmd:r(n_dirs)}}child folder count, before {opt maxitems()}{p_end}
{synopt:{cmd:r(n_files)}}child file count, before {opt maxitems()}{p_end}
{synopt:{cmd:r(bytes)}}total size of the files listed, or {cmd:-1} when {opt sizes} was not given{p_end}
{synopt:{cmd:r(largest_bytes)}}size of the largest file, or {cmd:-1}{p_end}
{synopt:{cmd:r(n_exts)}}number of distinct extensions among the files listed{p_end}
{synopt:{cmd:r(is_empty)}}1 when the node holds neither folders nor files{p_end}
{synopt:{cmd:r(truncated)}}1 when {it:either} listing hit {opt maxitems()}{p_end}
{synopt:{cmd:r(listed)}}1 when the files were displayed, 0 under {opt nofiles}{p_end}
{synopt:{cmd:r(page)}}the page shown, after clamping{p_end}
{synopt:{cmd:r(n_pages)}}how many pages the listing has{p_end}
{synopt:{cmd:r(perpage)}}the value in force; 0 means no paging{p_end}
{synopt:{cmd:r(shown_first)}}index of the first file displayed{p_end}
{synopt:{cmd:r(shown_last)}}index of the last file displayed{p_end}
{synopt:{cmd:r(looks_grammar)}}1 when this node's own name parses as {it:CCC}{cmd:_}{it:YYYY}{cmd:_}{it:SURVEY}{p_end}
{p2colreset}{...}

{pstd}
{cmd:r(dirs)} and {cmd:r(files)} are quoted element by element because folder names
contain spaces -- a fifth of the top-level folders in one staging tree do -- and an
unquoted space-delimited macro would split them. Read them back with
{cmd:foreach d of local dirs}, which respects the quoting.

{pstd}
{bf:What} {opt maxitems()} {bf:does and does not truncate.} {cmd:r(n_dirs)} and
{cmd:r(n_files)} are always the {it:true} totals for the node. {cmd:r(dirs)} and
{cmd:r(files)} are capped. Everything else -- {cmd:r(bytes)}, {cmd:r(exts)},
{cmd:r(n_exts)}, {cmd:r(largest)}, {cmd:r(largest_bytes)} -- describes the files that
were actually listed, so it always agrees with {cmd:r(files)}. {cmd:r(truncated)} is 1
when either list was capped, and that is the flag to check before treating
{cmd:r(bytes)} as a total for the node.

{pstd}
An earlier version of this command got that wrong in the dangerous direction: it summed
only the first {opt maxitems()} files while {cmd:r(n_files)} still reported the true
total and {cmd:r(truncated)} stayed 0, so a caller walking a tree and adding up
{cmd:r(bytes)} got a quietly short number. Cases x12 and x13 pin the corrected
behaviour.

{pstd}
{cmd:r(bytes)} returning {cmd:-1} rather than {cmd:0} is deliberate. Zero is a real
answer for a node with no files, and a caller has to be able to tell {it:no bytes} from
{it:not measured}.

{pstd}
{cmd:r(looks_grammar)} is the useful one for a migration: in a tree where some branches
have been renamed to the convention and others have not, it separates them without a
second pass.

{marker also}{...}
{title:Also see}

{psee}
Manual:  {manlink D dir}

{psee}
Online:  {helpb datalib}, {helpb datalib_browse}, {helpb datalib_files},
{helpb datalib_root}
{p_end}
