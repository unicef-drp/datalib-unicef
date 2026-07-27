*******************************************************
* datalib_config: contract v1 alias of getuserconfig
* Author: Joao Pedro Azevedo
*! Version: 0.9.3      Date: <2026-07-25>
* Reads ~/.config/user_config.yml for the current (or named) user and
* publishes the per-operator globals; the canonical cross-language name
* for what Stata has always called getuserconfig.
*******************************************************

capture program drop datalib_config
program define datalib_config, rclass

    version 15

    syntax [, USER(string) CONFIG(string) CONFIGDIR(string) ///
              INIT LIBrary(string) PROFILE replace EDIT]

    * -init- is where the datalib-specific knowledge lives: resolve the library
    * the same way -datalib- does, then hand a plain value to the generic
    * writer. getuserconfig itself stays project-agnostic.
    if ("`init'"!="") & (`"`library'"'=="") {
        capture datalib_root, find
        if (_rc==0) local library `"`r(root)'"'
    }

    getuserconfig, user(`user') config(`"`config'"') configdir(`"`configdir'"') ///
                   `init' library(`"`library'"') `profile' `replace' `edit'
    return add

end
