{smcl}
{hline}
{cmd:help _uc_init}{right:Version 0.9.19}
{right:Author: Joao Pedro Azevedo}
{hline}

{title:Title}
{p2colset 5 19 24 2}{...}
{p2col :_uc_init}{hline 1} Internal: bootstrap an operator's user configuration.{p_end}
{p2colreset}{...}

{title:Syntax}
{p 6 19 2}{cmd:_uc_init} [{cmd:,} {opt user(name)} {opt file(path)} {opt datalib(path)}
{opt profile} {opt replace} {opt edit}]{p_end}

{pstd}Reached through {helpb getuserconfig} {opt init} -- or {cmd:datalib config, init},
which resolves the library first -- rather than called directly.{p_end}

{title:Description}
{pstd}{cmd:_uc_init} writes a prepopulated {it:user_config.yml} block for the current
operator, and optionally a startup {it:profile.do} that loads it. It fills in every value
Stata can detect for itself, so a new user supplies at most one or two paths -- and often
none, because the caller can resolve the library and pass it in.{p_end}

{pstd}It is {bf:generic} by design: it belongs to the {helpb getuserconfig} family and
knows the config schema, not any particular project. A value that needs project knowledge
to find is passed in through {opt datalib()}. Project lookups must not be added here --
this command is used outside datalib as well.{p_end}

{pstd}This command {bf:writes}, and is reached only when a caller explicitly asks for it.
The config read path never creates files: a read that wrote on failure would make the CFG
conformance cases non-hermetic and would repeat the {cmd:_mkdir} side-effect defect
recorded in {it:tests/DIVERGENCES.md}.{p_end}

{title:What is detected}
{synoptset 18 tabbed}{...}
{synopthdr:Key}
{synoptline}
{synopt:block name}{cmd:c(username)}.{p_end}
{synopt:{cmd:githubFolder}}{helpb whereis} {cmd:github}, when the operator has stored
it.{p_end}
{synopt:{cmd:teamsRoot}}the single {it:~/UNICEF} child ending in {it:- Documents} when
there is exactly one; otherwise the candidates are written as comments to uncomment,
because guessing among siblings would be silently wrong. Listed case-correctly: Mata's
{cmd:dir()} is used, since the {cmd:dir} macro function lowercases names on Windows and a
lowercased path can be wrong for the R and Python readers.{p_end}
{synopt:{cmd:datalib}}{opt datalib()} when supplied by the caller.{p_end}
{synopt:{cmd:zDrive}, {cmd:zDriveUNC}}{helpb mapzdrive} {opt discover} (Windows
only).{p_end}
{synoptline}

{pstd}Anything undetermined is written as a {cmd:# TODO} line and counted in
{cmd:r(todo)}, so the file is never silently incomplete. When anything is left to fill in,
the file is opened for editing (see {opt edit}).{p_end}

{title:The startup profile}
{pstd}With {opt profile}, a {it:profile.do} is managed in {cmd:c(sysdir_personal)} -- the
right home because it is on the adopath, so Stata runs it at launch, and it needs no
administrator rights (unlike the Stata installation directory). Note that Stata searches
the {bf:current directory first}, so a project folder with its own {it:profile.do} takes
precedence and this one will not run there. It is:{p_end}

{p 8 12 2}{bf:checked} -- {cmd:r(profile)} always reports the path;{p_end}
{p 8 12 2}{bf:created} only when absent. It checks the command exists before calling it,
because the file outlives {cmd:ado uninstall datalib} and {cmd:capture noisily} on a
missing command still {it:prints} {it:command getuserconfig is unrecognized} -- so without
the check every Stata launch would nag after an uninstall;{p_end}
{p 8 12 2}{bf:never overwritten} -- an existing profile is left exactly as found, since it
is likely to hold the operator's own startup code;{p_end}
{p 8 12 2}{bf:opened} for editing along with the config when both already exist, or
whenever {opt edit} is given.{p_end}

{title:Safety}
{pstd}A config that already carries this user's block is left exactly as found --
including when {opt profile} is requested and only the profile is missing, in which case
the profile is written and the config is not touched. When the config exists but has no
block for this user, the block is {bf:appended}, after a newline is written so an
unterminated last line cannot be fused with the new key.{p_end}

{pstd}{opt replace} performs a {bf:real} replace: the file is rewritten without this
user's block (other operators' blocks copied through untouched, via a tempfile so a
failure cannot leave it half-written) and a fresh block is then written. It never emits a
second {it:username}{cmd::} key -- a duplicate top-level key makes R's
{cmd:yaml::read_yaml}, the reader in {it:r/R/datalib_config.R}, fail outright with
{it:Duplicate map key}, taking the operator's R tooling down. Stata and Python tolerate
duplicates (last wins), which is why this invariant is asserted by counting keys rather
than by reading the file back.{p_end}

{pstd}Block detection strips a CR and a UTF-8 BOM before matching, so a config written by
PowerShell or an older editor is still recognised rather than being treated as having no
block.{p_end}

{pstd}An existing file is {bf:backed up} to {it:<file>}{cmd:.bak} before it is touched,
and the path is reported in {cmd:r(backup)}. The write itself is {bf:atomic}: the intended
file is built in full in a tempfile and then moved into place, so a failure part-way
cannot leave a shared configuration half-written, and exactly one blank line separates the
new block from what came before however the previous editor saved the file.{p_end}

{pstd}Files are opened only in the GUI. {cmd:doedit} is unavailable in the console build,
and in {bf:batch} mode {cmd:c(console)} is empty while {cmd:doedit} still returns rc 0 --
so it would quietly open editor tabs during a scripted run. Both {cmd:c(console)} and
{cmd:c(mode)} are therefore checked, and the paths are printed instead.{p_end}

{title:Options}
{synoptset 18 tabbed}{...}
{synopthdr:Option}
{synoptline}
{synopt:{opt user(name)}}operator to write for; default {cmd:c(username)}.{p_end}
{synopt:{opt file(path)}}config file; default {it:~/.config/user_config.yml}.{p_end}
{synopt:{opt datalib(path)}}value for the {cmd:datalib:} key, supplied by the
caller.{p_end}
{synopt:{opt profile}}also manage a startup {it:profile.do} (see above).{p_end}
{synopt:{opt replace}}write a fresh block even when one already exists.{p_end}
{synopt:{opt edit}}open the file(s) for editing even when nothing is outstanding.{p_end}
{synoptline}

{title:Return values}
{synoptset 18 tabbed}{...}
{synopthdr:Returned}
{synoptline}
{synopt:{cmd:r(file)}}the config file.{p_end}
{synopt:{cmd:r(profile)}}the profile written or found; empty when not requested.{p_end}
{synopt:{cmd:r(action)}}{cmd:created}, {cmd:appended}, {cmd:replaced}, or
{cmd:kept}.{p_end}
{synopt:{cmd:r(todo)}}values left for the operator to fill in.{p_end}
{synopt:{cmd:r(opened)}}1 if the file(s) were opened in the do-file editor.{p_end}
{synopt:{cmd:r(backup)}}the backup written before an existing file was touched (empty when
the file was created).{p_end}
{synoptline}

{pstd}Called through {helpb getuserconfig} {opt init}, these are reported as
{cmd:r(init_action)}, {cmd:r(init_file)}, {cmd:r(init_profile)} and {cmd:r(init_todo)} --
under their own names, because when the configuration is complete the command carries on
to the read, whose returns would otherwise replace them.{p_end}

{title:Examples}
{p 8 12 2}{cmd:. getuserconfig, init}                    // generic{p_end}
{p 8 12 2}{cmd:. getuserconfig, init profile}            // plus a startup
profile.do{p_end}
{p 8 12 2}{cmd:. datalib config, init profile}           // resolves the library
first{p_end}
{p 8 12 2}{cmd:. datalib config, init edit}              // open even if complete{p_end}

{title:Author}
{p 4 4 2}Joao Pedro Azevedo (jpazevedo@unicef.org){p_end}

{title:Also see}

{psee}
{helpb getuserconfig} {helpb datalib} {helpb datalib_api} {helpb datalib_root}
{helpb mapzdrive}
{p_end}
