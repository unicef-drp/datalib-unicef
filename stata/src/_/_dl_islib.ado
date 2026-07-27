*******************************************************
** _dl_islib
* Joao Pedro Azevedo
*! v0.9.19
*******************************************************
* Normalise a path and decide whether it is a datalib LIBRARY (not merely an
* existing directory). Used by datalib_root's -find- mode so that a missing
* library fails loudly instead of resolving to whatever directory happens to
* exist at the candidate path.
*
* Returns:
*   r(path)   normalised path (forward slashes, no trailing separator except
*             on a drive root such as Z:/)
*   r(exists) 1 if the directory exists
*   r(islib)  1 if it exists AND looks like a library, by any of three tests:
*             it is named "datalib", or it carries a .datalib marker file, or it
*             holds a <CCC>/<CCC>_* GRANDCHILD PAIR -- a 3-character child that
*             itself contains a "<child>_*" folder. The name and marker tests
*             let a freshly created, still-empty library qualify.
*
*             The third test deliberately checks the grandchild, not just "a
*             3-character child": the weaker test passes on ordinary
*             directories (C:/ has c:/ado), which is exactly how a missing
*             library could resolve to its parent and have that parent's
*             subfolders read as country codes. See the comment at the test.
*******************************************************

capture program drop _dl_islib
program define _dl_islib, rclass

    version 15

    args p

    quietly {
        * ---- normalise -----------------------------------------------------
        local p = subinstr(`"`p'"', "\", "/", .)
        while (substr(`"`p'"', -1, 1)=="/" & strlen(`"`p'"')>1 & substr(`"`p'"', -2, 1)!=":") {
            local p = substr(`"`p'"', 1, strlen(`"`p'"')-1)
        }
        return local path `"`p'"'

        * ---- exists? -------------------------------------------------------
        mata: st_local("ok", strofreal(direxists(st_local("p"))))
        if ("`ok'"!="1") {
            return scalar exists = 0
            return scalar islib  = 0
            exit
        }
        return scalar exists = 1

        * ---- does it look like a library? ----------------------------------
        local base = word(subinstr(`"`p'"', "/", " ", .), -1)
        if (lower(`"`base'"')=="datalib") {
            return scalar islib = 1
            exit
        }
        capture confirm file `"`p'/.datalib"'
        if (_rc==0) {
            return scalar islib = 1
            exit
        }
        * Structural test: a library holds <CCC>/<CCC>_<YYYY>_<SURVEY>/... So
        * require a 3-character child that itself holds a "<child>_*" folder.
        * Testing the grandchild matters -- a bare "3-character folder" test
        * passes on ordinary directories (C:/ has c:/ado), which would let a
        * missing library resolve to whatever exists at the candidate path.
        * Case is not usable here: Stata's -dir- lowercases names on Windows.
        local ccs ""
        capture local ccs : dir `"`p'"' dirs "???"
        local hits 0
        foreach d of local ccs {
            local subs ""
            capture local subs : dir `"`p'/`d'"' dirs `"`d'_*"'
            local ns : word count `subs'
            if (`ns' > 0) {
                local hits 1
                continue, break
            }
        }
        return scalar islib = (`hits' > 0)
    }

end
