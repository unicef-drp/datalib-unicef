{smcl}
{hline}
{cmd:help _dl_islib}{right:Version 0.9.19}
{right:Author: Joao Pedro Azevedo}
{hline}

{title:Title}
{p2colset 5 20 25 2}{...}
{p2col :_dl_islib}{hline 1} Internal: normalise a path and test whether it is a datalib
library.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 19 2}{cmd:_dl_islib} {it:path}{p_end}

{title:Description}
{pstd}{cmd:_dl_islib} is an internal helper for {helpb datalib_root}'s {opt find} mode. It
normalises {it:path} and reports whether that path is a datalib {it:library}, as opposed
to merely an existing directory. It never touches the data in memory and creates
nothing.{p_end}

{pstd}The distinction matters: accepting any directory that exists would let a missing
library resolve to whatever sits at the candidate path -- for example the parent of the
library, whose subfolders would then be read as country codes. {cmd:_dl_islib} makes that
case fail loudly instead.{p_end}

{title:What counts as a library}
{pstd}The directory must exist, and at least one of the following must hold:{p_end}
{p 8 12 2}1. it is named {cmd:datalib} (case-insensitive);{p_end}
{p 8 12 2}2. it carries a {cmd:.datalib} marker file;{p_end}
{p 8 12 2}3. it holds at least one country-code-shaped (3-character) folder.{p_end}

{pstd}Tests 1 and 2 let a freshly created, still-empty library qualify before any country
folder exists; test 3 accepts a populated library under any name, such as a per-domain
tree ({cmd:Z:/datalib-hlt}).{p_end}

{title:Normalization}
{pstd}Backslashes become forward slashes and trailing separators are dropped -- except on
a drive root, where the separator is preserved ({cmd:Z:/} stays {cmd:Z:/}, since {cmd:Z:}
would mean the current directory on that drive).{p_end}

{title:Return values}
{synoptset 20 tabbed}{...}
{synopthdr:Returned}
{synoptline}
{synopt:{cmd:r(path)}}the normalised path.{p_end}
{synopt:{cmd:r(exists)}}1 if the directory exists, 0 otherwise.{p_end}
{synopt:{cmd:r(islib)}}1 if it exists {it:and} looks like a library, 0 otherwise.{p_end}
{synoptline}

{title:Author}
{p 4 4 2}Joao Pedro Azevedo (jpazevedo@unicef.org){p_end}

{title:Also see}

{psee}
{helpb datalib_root} {helpb datalib} {helpb datalib_api}
{p_end}
