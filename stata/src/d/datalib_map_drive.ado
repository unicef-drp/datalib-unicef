*******************************************************
* datalib_map_drive: contract v1 alias of mapzdrive
* Author: Joao Pedro Azevedo
*! Version: 0.9.3       Date: <2026-07-25>
* Maps the configured network drive (default Z:) from user_config.yml;
* the canonical cross-language name for mapzdrive. Windows-only.
*******************************************************

capture program drop datalib_map_drive
program define datalib_map_drive, rclass

    version 15

    syntax [, LETTER(string) UNC(string) USER(string) CONFIG(string) ///
              PERSISTENT(string) FORCE DRYrun DISCover]

    mapzdrive, letter(`letter') unc(`"`unc'"') user(`user') config(`"`config'"') ///
        persistent(`persistent') `force' `dryrun' `discover'
    return add

end
