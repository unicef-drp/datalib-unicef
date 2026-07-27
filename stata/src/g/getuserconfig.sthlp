{smcl}
{* *! version 1.2.0  25jul2026}{...}
{title:Title}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:getuserconfig} {hline 2}}Load per-operator paths from the user config
file(s){p_end}
{p2colreset}{...}

{title:Syntax}

{pstd}Read the configuration (the normal use):{p_end}
{p 8 15 2}{cmd:getuserconfig} [{cmd:,} {opt user(name)} {opt config(path)}
{opt configdir(path)}]{p_end}

{pstd}Bootstrap a configuration for an operator who has none:{p_end}
{p 8 15 2}{cmd:getuserconfig} {cmd:,} {opt init} [{opt library(path)} {opt profile}
{opt replace} {opt edit} {opt user(name)} {opt config(path)} {opt configdir(path)}]{p_end}

{title:Description}

{pstd}
{cmd:getuserconfig} reads the block for the current (or named) user from a YAML
configuration file and sets the globals {cmd:$githubFolder}, {cmd:$teamsRoot},
{cmd:$zDrive} and {cmd:$zDriveUNC}. It is a zero-dependency Stata port of the
DW-Production R user-config routine: it parses a constrained two-level YAML schema
({it:username:} then indented {it:key: value}) natively, so no YAML or Python
stack is required. This keeps per-operator paths out of tracked code -- adding a
teammate is a config edit, not a code change.

{pstd}
The command is {bf:generic}. It knows the config schema and nothing about any
particular project: a value that needs project knowledge to find is passed in
(see {opt library()}). {cmd:datalib_config} is the canonical alias.

{title:Which file is read}

{pstd}
Configuration resolution is a {bf:two-file, key-presence search}. The user's
block is looked up first in {cmd:~/.config/user_config.yml} -- the file shared
with the CSO Toolkit -- and then in {cmd:~/.config/datalib_config.yml}. The full
block ({cmd:githubFolder}, {cmd:teamsRoot}, ...) comes from the first file that has
the user block; for the library key, the {bf:first file whose block carries a
non-empty} {cmd:datalib:} {bf:key wins} (block-level -- keys are never merged
across files, and an empty value counts as absent). A generic file that exists
but lacks the key falls through to the package file.

{pstd}
Where the value came from is reported in {cmd:r(source_stage)} and
{cmd:r(source_file)}. The stage strings are byte-identical across Stata, R and
Python -- see {it:config/grammar.md} section 7.

{pstd}
The optional {cmd:datalib:} key names the operator's library root. When present,
{cmd:getuserconfig} fills {cmd:${datalib}} from it -- but only when
{cmd:${datalib}} is not already set, since an existing global is never
overwritten -- and returns the value in {cmd:r(datalib)}. This is the config-key
tier of the contract's root-resolution chain ({helpb datalib_api}).

{pstd}
As a non-blocking advisory, {cmd:getuserconfig} also checks whether the Z:
mirror is mounted at the configured {cmd:zDrive} path (default {cmd:Z:/});
if not, it prints a note and continues.

{marker init}{...}
{title:Bootstrapping a configuration}

{pstd}
{opt init} writes a prepopulated block for the operator, filling in everything
Stata can detect, so a new user supplies at most a path or two -- often none. The
work is done by {helpb _uc_init}; see there for the full detection table and the
safety rules. In outline:{p_end}

{p 8 12 2}o the block name comes from {cmd:c(username)}, {cmd:githubFolder} from
{helpb whereis} {cmd:github}, and {cmd:zDrive}/{cmd:zDriveUNC} from
{helpb mapzdrive} {opt discover};{p_end}
{p 8 12 2}o {cmd:datalib:} is written from {opt library()} when the caller
supplies it -- {cmd:datalib config, init} resolves the library with
{helpb datalib_root} {opt find} and passes it in;{p_end}
{p 8 12 2}o anything ambiguous is written as a commented {cmd:TODO} with the
candidates listed, never guessed;{p_end}
{p 8 12 2}o an existing block for this operator is kept -- including when only the
profile is missing, in which case the profile is written and the config is not
touched -- while {opt replace} rewrites the block in place rather than adding a
second one; a file holding other operators' blocks is otherwise only
{bf:appended} to, and never leaves two {it:username}{cmd::} keys.{p_end}

{pstd}
With {opt profile} a startup {it:profile.do} is also managed in
{cmd:c(sysdir_personal)}: checked, created only when absent, and never
overwritten. When the block and the profile are both already in place, nothing is
written and both files are opened for editing.

{pstd}
{bf:The read path never writes.} {opt init} is opt-in, and a plain
{cmd:getuserconfig} on a missing file errors (rc 601) with a message naming
{opt init} rather than creating anything. A read that wrote on failure would make
the CFG conformance cases non-hermetic -- they deliberately exercise the
missing-file and missing-key paths -- and would repeat the {cmd:_mkdir}
side-effect defect recorded in {it:tests/DIVERGENCES.md}. Where an automatic
bootstrap {it:is} wanted, put it in a setup step: {it:profile_datalib.do} runs
{cmd:datalib config, init profile} when this command reports rc 601 (no config
file) or rc 459 (a config that carries colleagues' blocks but not this
operator's -- the usual first run on a machine that already syncs the shared
file).

{title:Options}

{phang}{opt user(name)} username to look up; default is {cmd:c(username)}. Note the
asymmetry with {opt init}: on a read this means "look at someone else's block", but
on an init it means "write a block {it:labelled} this, using {bf:this} machine's
detected paths" -- so {cmd:user(colleague) init} would put your paths under their
name. Ordinary callers should omit it.

{phang}{opt config(path)} read (or write) exactly this file, disabling the
two-file fallback.

{phang}{opt configdir(path)} search the two-file list in this directory instead
of {cmd:~/.config}. A Stata-specific accommodation: Stata cannot set environment
variables in-session, so it cannot use {cmd:DATALIB_CONFIG_DIR} the way the R and
Python conformance tests do.

{phang}{opt init} write a prepopulated block for the operator (see
{help getuserconfig##init:Bootstrapping a configuration}). When the result is
complete, the command carries on to the read.

{phang}{opt library(path)} value for the {cmd:datalib:} key, supplied by the
caller. Only meaningful with {opt init}.

{phang}{opt profile} with {opt init}, also manage a startup {it:profile.do}.

{phang}{opt replace} with {opt init}, replace this operator's block: the file is
rewritten without it (other operators' blocks untouched) and a fresh block
written. It never leaves two {it:username}{cmd::} keys -- a duplicate top-level key
makes R's {cmd:yaml::read_yaml} fail outright.

{phang}{opt edit} with {opt init}, open the file(s) for editing even when nothing
is outstanding. Files are opened only in the GUI: {cmd:doedit} is not available in
the console build, and in batch mode it would silently open editor tabs during a
scripted run, so both {cmd:c(console)} and {cmd:c(mode)} are checked and the paths
are printed instead.

{title:Isolation hooks}

{pstd}
Used by the CFG conformance cases and available to callers: environment variable
{cmd:DATALIB_CONFIG} consults exactly one file and disables the fallback;
{cmd:DATALIB_CONFIG_DIR} searches the two-file list in another directory.

{title:Stored results}

{pstd}{cmd:getuserconfig} stores in {cmd:r()}:{p_end}
{synoptset 24 tabbed}{...}
{synopt:{cmd:r(user)}}resolved username{p_end}
{synopt:{cmd:r(config)}}config file the block was read from{p_end}
{synopt:{cmd:r(githubFolder)}}GitHub clone root{p_end}
{synopt:{cmd:r(teamsRoot)}}Teams deposit root{p_end}
{synopt:{cmd:r(zDrive)}}Z: mirror path/letter{p_end}
{synopt:{cmd:r(zDriveUNC)}}\\server\share for the mirror{p_end}
{synopt:{cmd:r(datalib)}}library root from the optional {cmd:datalib:} key (empty when
absent){p_end}
{synopt:{cmd:r(source_stage)}}where the library root came from: {cmd:config_generic},
{cmd:config_package}, or {cmd:unset}{p_end}
{synopt:{cmd:r(source_file)}}the file the library root came from{p_end}
{p2colreset}{...}

{pstd}On an {bf:incomplete} {opt init} the command stops after the write and returns
rc 0: none of the globals are published and none of the {cmd:r()} values above are
set -- only the {cmd:r(init_*)} group below. Check {cmd:r(init_todo)} rather than
just the return code.{p_end}

{pstd}With {opt init}, the bootstrap outcome is reported under its own names, so
that carrying on to the read does not replace it:{p_end}
{synoptset 24 tabbed}{...}
{synopt:{cmd:r(init_action)}}{cmd:created}, {cmd:appended}, {cmd:replaced}, or
{cmd:kept}{p_end}
{synopt:{cmd:r(init_file)}}the config file written{p_end}
{synopt:{cmd:r(init_profile)}}the startup profile written or found (empty when not
requested){p_end}
{synopt:{cmd:r(init_todo)}}values left for the operator to fill in{p_end}
{synopt:{cmd:r(init_backup)}}backup of the previous configuration, written before an
existing file was touched{p_end}
{p2colreset}{...}

{title:Examples}

{p 8 12 2}{cmd:. getuserconfig}                              // read{p_end}
{p 8 12 2}{cmd:. getuserconfig, user(azeve)}                  // read someone else's
block{p_end}
{p 8 12 2}{cmd:. getuserconfig, init}                         // bootstrap{p_end}
{p 8 12 2}{cmd:. getuserconfig, init profile}                 // bootstrap + startup
profile.do{p_end}
{p 8 12 2}{cmd:. datalib config, init profile}                // resolves the library
first{p_end}

{title:Also see}

{psee}Online: {helpb _uc_init}, {helpb mapzdrive}, {helpb datalib}, {helpb datalib_api},
{helpb datalib_root}{p_end}

{title:Author}

{pstd}Joao Pedro Azevedo, UNICEF
({browse "mailto:jpazevedo@unicef.org":jpazevedo@unicef.org}).{p_end}
