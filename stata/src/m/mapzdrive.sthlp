{smcl}
{* *! version 1.0.0  10jul2026}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:mapzdrive} {hline 2}}Map the Z: (or configured) network drive from
{cmd:user_config.yml}{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 15 2}{cmd:mapzdrive} [{cmd:,} {it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt letter(X:)}}drive letter to mount; default {cmd:$zDrive} or {cmd:Z:}{p_end}
{synopt:{opt unc(\\host\share)}}share to map; default {cmd:$zDriveUNC}{p_end}
{synopt:{opt user(name)}}username passed to {helpb getuserconfig}{p_end}
{synopt:{opt config(path)}}config path passed to {helpb getuserconfig}{p_end}
{synopt:{opt persistent(yes|no)}}persist the mapping across logon; default
{cmd:yes}{p_end}
{synopt:{opt force}}remap even if the letter is in use by another share{p_end}
{synopt:{opt dry:run}}print the {cmd:net use} command without running it{p_end}
{synopt:{opt disc:over}}print the UNC of the letter's current mapping and exit{p_end}
{synoptline}

{title:Description}

{pstd}
{cmd:mapzdrive} is {bf:Windows-only}: it exits with an error (198) on any other
operating system.

{pstd}
{cmd:mapzdrive} maps a Windows network drive using the values in
{cmd:~/.config/user_config.yml} (read via {helpb getuserconfig}).  It is safe by
default: if the drive letter is already available it does nothing; it remaps only
when {opt force} is given and the letter points at a different share.  No
credentials are stored or required when the operator's identity already has access
to the share (e.g. an Entra-authenticated Azure file share).

{pstd}
Use {opt discover} to read the UNC of a drive that is already mapped (handy for
populating {cmd:zDriveUNC} in your config), and {opt dryrun} to preview the exact
{cmd:net use} command without changing anything.

{title:Stored results}

{pstd}{cmd:mapzdrive} stores in {cmd:r()}: {cmd:r(status)}
(mapped | already-mapped | dryrun | failed), {cmd:r(letter)}, and {cmd:r(unc)}.

{title:Also see}

{psee}Online: {helpb getuserconfig}, {helpb _uc_init} (writes the {cmd:zDrive} and
{cmd:zDriveUNC} keys from this command's {opt discover} output), {helpb datalib},
{helpb datalib_api}{p_end}

{title:Author}

{pstd}Joao Pedro Azevedo, UNICEF
({browse "mailto:jpazevedo@unicef.org":jpazevedo@unicef.org}).{p_end}
