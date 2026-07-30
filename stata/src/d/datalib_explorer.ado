*******************************************************
** datalib_explorer
* Joao Pedro Azevedo and Minh Cong Nguyen
*! v0.9.26
*******************************************************
* Navigate an ARBITRARY folder tree, and return everything about the current node
* so a caller can do something with it.
*
* WHY THIS EXISTS SEPARATELY FROM datalib_browse
*
* Every other navigation path in this package reads a folder's ancestry out of its own
* NAME. -_foldernav- counts underscores to rebuild CCC/CCC_YYYY_SURVEY/, and
* -datalib_browse- does the same after upper()-ing the path. That is correct for the
* grammar, where the name encodes the parents, and useless anywhere else:
* "raw datasets" says nothing about which survey it belongs to.
*
* <staging-tree> is the case in point -- tens of thousands of files, hundreds of gigabytes, more than half
* the archive by volume, under names like "afghanistan/2010 sdhs/raw datasets". Dropping
* a .datalib marker in it would satisfy -_dl_islib- and then navigate to the wrong
* places SILENTLY, which is worse than refusing to start.
*
* So three rules, each of which is the difference from -browse-:
*   1. every link carries the FULL relative path. Nothing is reconstructed.
*   2. casing is preserved. Stata's `: dir` macro extension LOWERCASES on Windows --
*      it returns "afghanistan" for "Afghanistan" -- so this reads the directory
*      through Mata's dir(), which does not. Verified on the staging tree.
*      It depends on nothing outside itself: an earlier version called -_uc_dirs-,
*      which is defined inside _uc_init.ado rather than as its own .ado, so Stata
*      could not autoload it and a clean install failed with r(199) on first use.
*   3. no upper(), no underscore parsing, no -_dl_islib- gate. The only precondition
*      is that the directory exists.
*
* RETURN SURFACE
*
* The point of the command is as much the r() surface as the display: enough to walk
* the tree programmatically, summarise it, or feed it to -_dlw-. Lists are returned
* COMPOUND-QUOTED element by element ("a" "b c" "d"), because 21% of the staging tree's
* top-level folders contain a space and an unquoted space-delimited macro would split
* them. Read them back with:  foreach d of local dirs { ... }
*
*   r(root)          tree root, as given
*   r(path)          relative path of this node ("" at the root)
*   r(fullpath)      root + path, forward-slashed
*   r(parent)        relative path of the parent ("" at the root; "." when at depth 1)
*   r(depth)         0 at the root
*   r(n_dirs)        child directory count
*   r(dirs)          child directories, quoted, original casing
*   r(n_files)       child file count
*   r(files)         child files, quoted, original casing (always populated; -nofiles-
*                    affects the DISPLAY only, because the names are fetched either way)
*   r(bytes)         total size of the files LISTED, or -1 when -sizes- was not
*                    given. Stata cannot read a size without opening the file and an
*                    open over SMB costs ~1.4s, so it is opt-in. -1 rather than 0,
*                    because 0 is a real answer for a node with no files.
*   r(n_exts)        distinct extensions among the files listed
*   r(exts)          those extensions, space-delimited, lowercased, no dot;
*                    "none" for a file without one
*   r(largest)       name of the largest file listed ("" if none)
*   r(largest_bytes) its size, or -1 when -sizes- was not given
*   r(is_empty)      1 when the node holds neither directories nor files
*   r(truncated)     1 when EITHER list was capped by maxitems()
*
* n_dirs and n_files are the TRUE totals; dirs and files are capped at maxitems(); and
* bytes/exts/largest describe the files actually listed. So when r(truncated) is 1 the
* two counts still describe the node while everything else describes the sample -- which
* is why the flag exists rather than a silently short answer.
*
*   r(looks_grammar) 1 when this node's own name parses as CCC_YYYY_SURVEY[_vNN...]
*
* r(looks_grammar) is the useful one for a migration: it says whether a node in an
* arbitrary tree has ALREADY been named to the convention, so a sweep can tell
* restructured branches from untouched ones without a second pass.
*******************************************************

capture program drop datalib_explorer
program define datalib_explorer, rclass

    version 15

    * NOFILES MUST be declared before FILES. Probed, because the failure is silent:
    * with -syntax [, FILES NOFILES ]- typing `nofiles' binds NEITHER local and raises NO
    * error -- Stata reads it as the negation of FILES, which for a plain flag means
    * "absent". Declared in this order it binds correctly. Pinned by case x14.
    syntax [, PATH(string) ROOT(string) NOFILES FILES SIZES MAXitems(integer 400) PERpage(integer 0) PAGE(integer 1) ]

    * `files' is accepted and does nothing: listing is the default now. It stays in the
    * syntax because it is declared in surface.yml, documented in two help pages and
    * exercised by conformance case x06, and removing it would break callers to save
    * nothing. `nofiles' is the option that now has an effect.
    local _unused_files "`files'"

    quietly {
        *------------------------------------------------------------------
        * 1. resolve the root. Deliberately NOT via datalib_root: that applies
        *    _dl_islib, which is the gate this command exists to bypass. An
        *    arbitrary tree is not a library and should not have to pretend.
        *------------------------------------------------------------------
        local r `"`root'"'
        if (`"`r'"'=="") local r `"${datalib}"'
        if (`"`r'"'=="") {
            noi di as err `"{p}explorer needs a tree to walk: pass {bf:root()}, or set {bf:${datalib}}.{p_end}"'
            noi di as err `"{p}Unlike the other navigation commands this one does not require a datalib library -- any directory will do.{p_end}"'
            exit 198
        }
        local r = subinstr(`"`r'"', "\", "/", .)
        while (substr(`"`r'"', -1, 1)=="/" & strlen(`"`r'"')>1 & substr(`"`r'"', -2, 1)!=":") {
            local r = substr(`"`r'"', 1, strlen(`"`r'"')-1)
        }

        * The relative path is used VERBATIM. No case folding, no token parsing.
        local rel = subinstr(`"`path'"', "\", "/", .)
        * Braces are not optional: Stata's -while- has no single-line
        * form, unlike -if-. Omitting them raises "{ required" at run time,
        * not at load time, so the program parses and then dies in use.
        while (substr(`"`rel'"', 1, 1)=="/") {
            local rel = substr(`"`rel'"', 2, .)
        }
        while (substr(`"`rel'"', -1, 1)=="/") {
            local rel = substr(`"`rel'"', 1, strlen(`"`rel'"')-1)
        }

        local full `"`r'"'
        if (`"`rel'"'!="") local full `"`r'/`rel'"'

        if (`perpage' < 0) {
            noi di as err "perpage() cannot be negative; 0 means show them all."
            exit 198
        }
        if (`page' < 1) {
            noi di as err "page() starts at 1."
            exit 198
        }

        mata: st_local("ok", strofreal(direxists(st_local("full"))))
        if ("`ok'"!="1") {
            noi di as err `"{p}Not a directory: `full'{p_end}"'
            if (`"`rel'"'!="") {
                noi di as err `"{p}The {bf:path()} is taken relative to {bf:root()} and is used exactly as given -- explorer does not fold case or guess at separators.{p_end}"'
            }
            exit 601
        }

        *------------------------------------------------------------------
        * 2. list the node, both halves through Mata's dir().
        *
        *    Not `: dir': that macro extension LOWERCASES on Windows, returning
        *    "afghanistan" for "Afghanistan", and preserving casing is the whole
        *    point. Not -_uc_dirs- either, though it does the same job: it is
        *    defined INSIDE _uc_init.ado rather than as its own .ado, so Stata's
        *    autoloader cannot resolve it and calling it cold raises r(199) on a
        *    clean install. Every test passed anyway, because the conformance
        *    harness -run-s every source file up front and so had it in memory --
        *    the one condition a real user does not have.
        *
        *    dir() returns BARE names (verified on the staging tree: one entry per country,
        *    the first "Afghanistan" with its capital A), which is what the display
        *    and the drill-down links need.
        *
        *    Deliberately NOT -capture-d. A directory that exists but cannot be read
        *    would then report "0 folders, 0 files" instead of failing, and a silent
        *    wrong answer is the failure mode this command has already been corrected
        *    for twice.
        *------------------------------------------------------------------
        local dirs ""
        local files_l ""
        mata: st_local("dirs", invtokens((char(34) :+ dir(st_local("full"), "dirs", "*") :+ char(34))'))
        mata: st_local("files_l", invtokens((char(34) :+ dir(st_local("full"), "files", "*") :+ char(34))'))
        local ndirs  : word count `dirs'
        local nfiles : word count `files_l'

        * Cap BOTH lists, and say so. Capping only the directories left r(files)
        * unbounded and r(truncated) at 0 while the help promised the opposite -- and,
        * worse, left r(bytes) a silent partial sum (see below). n_dirs and n_files are
        * captured above and keep reporting the TRUE totals.
        local truncated 0
        if (`ndirs' > `maxitems') {
            local keep ""
            forvalues i = 1/`maxitems' {
                local d : word `i' of `dirs'
                local keep `"`keep' "`d'""'
            }
            local dirs `"`keep'"'
            local truncated 1
        }
        if (`nfiles' > `maxitems') {
            local keepf ""
            forvalues i = 1/`maxitems' {
                local f : word `i' of `files_l'
                local keepf `"`keepf' "`f'""'
            }
            local files_l `"`keepf'"'
            local truncated 1
        }

        *------------------------------------------------------------------
        * 3. facts about the files here: bytes, extensions, largest
        *------------------------------------------------------------------
        * Extensions are free: they come out of the name. Sizes are NOT. Stata has no
        * way to read a file size without OPENING the file, and an open over SMB
        * measured ~1.4s regardless of how many bytes are read -- so a node with 200
        * files would take five minutes. Hence -sizes- is opt-in.
        *
        * r(bytes) is -1 when it was not asked for, not 0. Zero is a real answer for a
        * node with no files, and a caller has to be able to tell "no bytes" from "not
        * measured" -- the same distinction that makes a null row count dangerous.
        *
        * These describe the files LISTED, which after the cap above is exactly what
        * r(files) holds. They used to describe a silent prefix of a longer list: the
        * loop broke at maxitems while r(n_files) still reported the true total, so a
        * caller summing r(bytes) over a tree got a quietly wrong number. Now the two
        * are consistent and r(truncated) says when the node holds more.
        local exts ""
        foreach f of local files_l {
            local e = lower(substr(`"`f'"', strrpos(`"`f'"', ".") + 1, .))
            if (strpos(`"`f'"', ".") == 0) local e "none"
            local e = subinstr(`"`e'"', " ", "", .)
            if (`"`e'"' != "") {
                if (!`:list e in exts') local exts `"`exts' `e'"'
            }
        }
        local exts  = trim(`"`exts'"')
        local nexts : word count `exts'

        local bytes         -1
        local largest       ""
        local largest_bytes -1
        if ("`sizes'" != "") {
            local bytes         0
            local largest_bytes 0
            foreach f of local files_l {
                * -file seek eof- then -file seek query- puts the size in r(loc); there
                * is no cheaper route in Stata, which is why this is behind an option.
                local fsz 0
                tempname fh
                capture file open `fh' using `"`full'/`f'"', read binary
                if (_rc == 0) {
                    capture file seek `fh' eof
                    capture file seek `fh' query
                    local fsz = r(loc)
                    capture file close `fh'
                }
                if ("`fsz'" == "" | "`fsz'" == ".") local fsz 0
                local bytes = `bytes' + `fsz'
                if (`fsz' > `largest_bytes') {
                    local largest_bytes = `fsz'
                    local largest `"`f'"'
                }
            }
        }

        * Does THIS node's own name already follow the grammar? Useful in a mixed
        * tree: it distinguishes a branch someone has restructured from one nobody
        * has touched, without a second sweep.
        local leaf = word(subinstr(`"`rel'"', "/", " ", .), -1)
        if (`"`rel'"'=="") local leaf = word(subinstr(`"`r'"', "/", " ", .), -1)
        local looks 0
        if (ustrregexm(`"`leaf'"', "^[A-Za-z]{3}_[0-9]{4}_[A-Za-z0-9-]+")) local looks 1

        local parent ""
        local depth 0
        if (`"`rel'"'!="") {
            * Count SEPARATORS, not words. wordcount() splits on spaces, so a
            * folder name containing one -- "Afghanistan/2010 SDHS/Raw Datasets" --
            * would report depth 5 instead of 3. Caught by the conformance fixture,
            * which carries a space for exactly this reason.
            local depth = strlen(`"`rel'"') - strlen(subinstr(`"`rel'"', "/", "", .)) + 1
            if (`depth' > 1) {
                local parent = substr(`"`rel'"', 1, strrpos(`"`rel'"', "/")-1)
            }
            else local parent "."
        }

        *------------------------------------------------------------------
        * 4. display. Links carry the whole relative path, compound-quoted so a
        *    space in a folder name cannot split the option.
        *------------------------------------------------------------------
        noi di as txt _n "{hline 78}"
        noi di as txt "explorer: " as res cond(`"`rel'"'=="", `"`r'"', `"`rel'"')
        noi di as txt "  in " as res `"`r'"' as txt "   depth `depth'   " ///
            as res "`ndirs'" as txt " folders, " as res "`nfiles'" as txt " files" ///
            cond(`bytes'>=0, "   " + string(`bytes'/1048576, "%9.1f") + " MB", "")
        if (`looks') {
            noi di as txt "  this node's name already matches the datalib grammar"
        }
        noi di as txt "{hline 78}"

        * Carry EVERY option through the links, not just `files'. Dropping `sizes' and
        * maxitems() meant one click silently reset a deliberate maxitems(2000) to the
        * 400 default and discarded an opted-in measurement.
        * Carry every option through the links. `nofiles' has to propagate too, or one
        * click would silently re-enable a listing the caller had turned off.
        * perpage() rides along as a preference; page() deliberately does NOT, because
        * descending into a folder should start at its beginning rather than at page 7 of
        * a listing that had nothing to do with it.
        local opts `"`nofiles' `sizes' maxitems(`maxitems')"'
        if (`perpage' > 0) local opts `"`opts' perpage(`perpage')"'
        if (`"`parent'"'!="") {
            local up = cond(`"`parent'"'==".", "", `"`parent'"')
            noi di as txt `"  {stata `"datalib_explorer, root(`"`r'"') path(`"`up'"') `opts'"':.. up}"'
        }

        foreach d of local dirs {
            local child `"`d'"'
            if (`"`rel'"'!="") local child `"`rel'/`d'"'
            noi di as txt `"  {stata `"datalib_explorer, root(`"`r'"') path(`"`child'"') `opts'"':{bf:`d'}/}"'
        }
        if (`truncated') {
            noi di as txt "  ... listing capped at `maxitems' folders; raise {bf:maxitems()} to see more"
        }

        local shown : word count `files_l'
        local first  1
        local last   `shown'
        local npages 1
        if ("`nofiles'"=="") {
            if (`nfiles'==0) noi di as txt "  (no files at this node)"
            * File names are links now. What a click DOES depends on the type, because a
            * link that looks like one and does nothing is worse than plain text:
            * .dta describes, text views, anything else is handed to the OS. A path with a
            * shell metacharacter gets no link at all -- see _dl_fileaction.
            * Which slice of the listing to show. `shown' is what is in files_l after
            * maxitems() capped it -- paging slices THAT, so the two are composable and
            * neither lies about the other: maxitems() decides how much was fetched,
            * perpage() decides how much is on screen.
            if (`perpage' > 0 & `shown' > 0) {
                local npages = ceil(`shown' / `perpage')
                if (`page' > `npages') local page = `npages'
                local first = (`page' - 1) * `perpage' + 1
                local last  = min(`page' * `perpage', `shown')
            }

            local nlinked 0
            local i 0
            foreach f of local files_l {
                local ++i
                if (`i' < `first') continue
                if (`i' > `last')  continue, break
                _dl_fileaction `"`full'/`f'"'
                local act `"`r(action)'"'
                if (`"`act'"'!="") {
                    local ++nlinked
                    noi di as txt `"    {stata `"`act'"':`f'}"'
                }
                else noi di as txt `"    `f'"'
            }

            * Pager. Only when there is more than one page -- a "page 1 of 1" line is
            * noise, and noise is what makes people stop reading these listings.
            if (`npages' > 1) {
                local pgline `"  files `first'-`last' of `shown'   page `page' of `npages'"'
                if (`page' > 1) {
                    local pgline `"`pgline'   {stata `"datalib_explorer, root(`"`r'"') path(`"`rel'"') `opts' page(`=`page'-1')"':<- prev}"'
                }
                if (`page' < `npages') {
                    local pgline `"`pgline'   {stata `"datalib_explorer, root(`"`r'"') path(`"`rel'"') `opts' page(`=`page'+1')"':next ->}"'
                }
                noi di as txt `"`pgline'"'
            }
            if (`nfiles' > `maxitems') {
                noi di as txt "  ... `=`nfiles'-`maxitems'' more files not listed;" ///
                    " raise {bf:maxitems()} to include them"
            }
            * A CLICKABLE offer, not advice. -sizes- is genuinely expensive (~1.4 s per
            * file over SMB) so it stays opt-in, but telling someone to retype the command
            * is what made the old files hint useless. The link is sticky: -opts- above
            * carries `sizes' into every link from here down.
            * A node with a wall of files should say that it can be read in pieces --
            * and say it as a LINK, because the whole lesson of the `files' hint was that
            * advice you cannot click is not advice.
            if (`perpage'==0 & `shown' > 30) {
                noi di as txt `"  {stata `"datalib_explorer, root(`"`r'"') path(`"`rel'"') `nofiles' `sizes' maxitems(`maxitems') perpage(20)"':show 20 at a time}"' ///
                    as txt " instead of all `shown'"
            }
            if (`nfiles' > 0 & `nlinked' > 0) {
                noi di as txt "  click a file: {bf:.dta} describes it, text opens in the" ///
                    " viewer, anything else opens in its own app"
            }
            if ("`sizes'"=="" & `nfiles' > 0) {
                noi di as txt `"  {stata `"datalib_explorer, root(`"`r'"') path(`"`rel'"') `nofiles' sizes maxitems(`maxitems')"':measure these `nfiles' file(s)}"' ///
                    as txt " (about " as res `=round(`nfiles'*1.4)' as txt " s over SMB)"
            }
        }
        else if (`nfiles' > 0) {
            noi di as txt `"  {stata `"datalib_explorer, root(`"`r'"') path(`"`rel'"') `sizes' maxitems(`maxitems')"':list the `nfiles' file(s) here}"'
        }
        noi di as txt "{hline 78}"

        *------------------------------------------------------------------
        * 5. return everything
        *------------------------------------------------------------------
        return local root           `"`r'"'
        return local path           `"`rel'"'
        return local fullpath       `"`full'"'
        return local parent         `"`parent'"'
        return scalar depth         = `depth'
        return scalar n_dirs        = `ndirs'
        return local dirs           `"`dirs'"'
        return scalar n_files       = `nfiles'
        return local files          `"`files_l'"'
        return scalar bytes         = `bytes'
        return scalar n_exts        = `nexts'
        return local exts           `"`exts'"'
        return local largest        `"`largest'"'
        return scalar largest_bytes = `largest_bytes'
        return scalar is_empty      = (`ndirs'==0 & `nfiles'==0)
        return scalar truncated     = `truncated'
        * Observable, so the nofiles switch is testable at all. Without this the only
        * difference nofiles makes is on screen, and cases x14/x15 both passed with the
        * declaration order broken -- two tests providing false confidence, which is worse
        * than none.
        return scalar listed        = ("`nofiles'"=="")
        * The pager describes the DISPLAY. Every count and list above still describes the
        * whole node, so a caller is never handed a page and told it is the answer.
        return scalar page          = `page'
        return scalar n_pages       = `npages'
        return scalar perpage       = `perpage'
        return scalar shown_first   = cond("`nofiles'"=="", `first', 0)
        return scalar shown_last    = cond("`nofiles'"=="", `last', 0)
        return scalar looks_grammar = `looks'
    }
end
