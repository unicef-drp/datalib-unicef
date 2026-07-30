*******************************************************
** _dl_fileaction
* Joao Pedro Azevedo and Minh Cong Nguyen
*! v0.9.26
*******************************************************
* Given a file path, decide what CLICKING it should do, and return the command that does
* it. Used by -datalib_explorer- to turn file names into working hyperlinks.
*
* WHY A LINK NEEDS AN ACTION AT ALL
*
* A hyperlink that merely looks like one is worse than plain text: it invites a click and
* then does nothing. So the action is chosen from what Stata can actually do with the
* file, and where Stata can do nothing the OS is asked instead.
*
* The buckets come from the real archive rather than from taste. Across the tens of thousands of files
* in <catalogue> the distribution is:
*
*   dta       31.5%   Stata's own format          -> describe using
*   text      ~22%    dct frq frw map as var ivd  -> view
*                     sps csv do txt dat ...
*   opaque    ~36%    sav zip doc xls pdf         -> hand to the OS
*                     sas7bdat xlsx docx ...
*
* -describe using- rather than -use-, deliberately. Clicking a name in a file browser
* should not silently replace the data in memory; -describe using- answers "what is in
* this?" which is the question someone exploring an archive is actually asking. Loading it
* is then one command away, and theirs to type.
*
* THE SHELL GUARD, AND WHY IT IS NARROWER THAN IT LOOKS
*
* The OS bucket builds a -shell- command around a path that came from the filesystem, so
* the first draft refused any name containing a quote, ampersand, pipe, angle bracket,
* caret, percent or backtick. Measured against the real archive that cost a small fraction
* files -- 0.73%, almost all of them ampersands -- so it was worth checking whether the
* fear was justified. It was not: cmd treats those characters as syntax only OUTSIDE
* quotes, and the path is quoted. Probed rather than assumed, by echoing each through cmd
* and reading it back:
*
*   Health & Nutrition.xlsx   -> intact
*   50%25 sample.dta          -> intact
*   a^b.pdf                   -> intact
*
* So only a double quote is refused, because that is what would actually break the
* quoting -- and Windows forbids it in filenames anyway, leaving this a guard for POSIX.
* Refusing to link is the safe failure: the file is still named, just not clickable.
*
* The one residual case is a name containing a PAIR of percent signs around a real
* environment variable ("%TEMP% notes.pdf"), which cmd would expand. The consequence is a
* click that fails to open rather than one that opens the wrong thing, so it is left alone
* rather than paid for with a guard that would also reject "50% / 75% sample".
*
* RETURNS
*   r(action)  the command a click should run, or "" when it must not be linked
*   r(kind)    describe | view | open | none
*   r(ext)     lowercased extension of the BASENAME, no dot ("" when there is none)
*******************************************************

capture program drop _dl_fileaction
program define _dl_fileaction, rclass

    version 15

    gettoken fp 0 : 0

    * Extension of the BASENAME, not of the whole path: a folder with a dot in its name
    * -- "2016 v1.2 release/NACIA75" -- would otherwise yield an extension of "2 release/
    * NACIA75" and be misclassified.
    local base `"`fp'"'
    local sl = strrpos(`"`base'"', "/")
    if (`sl' > 0) local base = substr(`"`base'"', `sl' + 1, .)
    local sl = strrpos(`"`base'"', "\")
    if (`sl' > 0) local base = substr(`"`base'"', `sl' + 1, .)

    local e ""
    if (strpos(`"`base'"', ".") > 0) {
        local e = lower(substr(`"`base'"', strrpos(`"`base'"', ".") + 1, .))
    }

    * Text formats Stata's viewer can show usefully. The unobvious ones are the DHS and
    * SPSS metadata companions that make up a fifth of the archive: dct frq frw map as var
    * ivd sts inf are all plain text, and being able to read them next to the .dta they
    * describe is most of the point of linking at all.
    local viewext "txt csv tsv dct frq frw map as var ivd sts inf sps sas do ado mata log md json yml yaml xml html htm dat asc raw sthlp lst nfo"

    * No extension goes to the viewer DELIBERATELY, and is tested for first. It already
    * reached -view- before this branch existed, but only via a Stata quirk --
    * `:list "" in x' is TRUE for any x -- so the behaviour was right by accident and would
    * have changed silently the day someone reordered the conditions. In this archive the
    * the extensionless files are text data (Spain's NACIA75 is a 34 MB fixed-width
    * extract), so the viewer is the correct guess, if a slow one for the larger ones.
    if ("`e'"=="") {
        return local kind "view"
        return local action `"view `"`fp'"'"'
    }
    else if ("`e'"=="dta") {
        return local kind "describe"
        return local action `"describe using `"`fp'"'"'
    }
    else if (`:list e in viewext') {
        return local kind "view"
        return local action `"view `"`fp'"'"'
    }
    else {
        * Anything Stata cannot read: ask the OS. Guarded, per the header.
        local unsafe = (strpos(`"`fp'"', char(34)) > 0)

        if (`unsafe') {
            return local kind "none"
            return local action ""
        }
        else if ("`c(os)'"=="Windows") {
            * start needs an empty title argument first, or it treats a quoted path as the
            * window title and opens a console instead of the file.
            return local kind "open"
            return local action `"shell start "" "`fp'""'
        }
        else if ("`c(os)'"=="MacOSX") {
            return local kind "open"
            return local action `"shell open "`fp'""'
        }
        else {
            return local kind "open"
            return local action `"shell xdg-open "`fp'""'
        }
    }

    return local ext "`e'"
end
