*==============================================================================*
*! Datalib
*! Project information at: https://github.com/unicef-drp/datalib-unicef

*! PROFILE: Required step before running any do-files in this project
*==============================================================================*

quietly {

  /*
  Steps in this do-file:
  1) General program setup
  2) Define user-dependant path for local clone repo
  3) Check if can access UNICEF network path and UNICEF datalibweb
  4) Download and install required user written ado's
  5) Flag that profile was successfully loaded
  */

  *-----------------------------------------------------------------------------
  * 1) General program setup
  * This section is standard in UNICEF-Analytics repos
  * It is not required for the replication of the main results, but it is 
  * recommended to keep it to ensure that the code runs smoothly
  *-----------------------------------------------------------------------------
  
  clear               all
  capture log         close _all
  set more            off
  set varabbrev       off, permanently
  set emptycells      drop
  set maxvar          2048
  set linesize        135
  version             15
  global master_seed  123456789

  *-----------------------------------------------------------------------------
  * 2) Define user-dependant path for local clone repo
  *-----------------------------------------------------------------------------
  * Change here only if this repo is renamed
  * This is the name of the repo as it appears in GitHub
  * It is also the name of the folder that contains the local clone
  * This is also the name of the master run do-file as it appears in GitHub 
  *-----------------------------------------------------------------------------

  local this_repo     "datalib-unicef"
  * Change here only if this master run do-file is renamed
  local this_run_do   "run_datalib.do"

  * The remaining of this section is standard in EduAnalytics repos

  * One of two options can be used to "know" the clone path for a given user
  * A. the user had previously saved their GitHub location with -whereis-,
  *    so the clone is a subfolder with this Project Name in that location
  * B. through a window dialog box where the user manually selects a file


 *-----------------------------------------------------------------------------
  * Define user-dependant path for local clone repo
  *-----------------------------------------------------------------------------

  /* WELCOME!!! ARE YOU NEW TO THIS CODE?
     Add yourself by copying the lines above, making sure to adapt your clone */

  * Joao Pedro Azevedo I
  if inlist("`c(username)'","azeve") {
    global inputdata_hlt   "C:\Users\\`c(username)'\UNICEF\Health-HIV Data & Analytics - Integrated Health Database\Data Harmonization\Harmonized Micro Data"
  }
  * Joao Pedro Azevedo II
  else if inlist("`c(username)'","jpazevedo") {
    global inputdata_hlt      "C:\Users\jpazevedo\UNICEF\Health-HIV Data & Analytics - Harmonized Micro Data"
  }
    * George
  else if inlist("`c(username)'","gmwinnyaa") {
    global inputdata_hlt   "C:\Users\gmwinnyaa\UNICEF\Health-HIV Data & Analytics - Harmonized Micro Data"
  }
    * Tashrik
  else if inlist("`c(username)'","tasahmed") {
    global inputdata_hlt   "C:\Users\tasahmed\UNICEF\Health-HIV Data & Analytics - Harmonized Micro Data"
  }
  else {
    noi disp as error _newline "{phang}Your username [`c(username)'] could not be matched with any specified clone location. Please update the initialization lines in the master run do-file accordingly and try again.{p_end}"
    error 2222
  }

  * Method A - Github location stored in -whereis-
  *---------------------------------------------
  capture whereis github
  if _rc == 0 {
    global clone  "`r(github)'/`this_repo'"
    global github "`r(github)'"
  }

  * Method B - clone selected manually
  *---------------------------------------------
  else {
    * Display an explanation plus warning to force the user to look at the dialog box
    noi disp as txt `"{phang}Your GitHub clone local could not be automatically identified by the command {it: whereis}, so you will be prompted to do it manually. To save time, you could install -whereis- with {it: ssc install whereis}, then store your GitHub location, for example {it: whereis github "C:/Users/AdaLovelace/GitHub"}.{p_end}"'
    noi disp as error _n `"{phang}Please use the dialog box to manually select the file `this_run_do' in your machine.{p_end}"'

    * Dialog box to select file manually
    capture window fopen path_and_run_do "Select the master do-file for this project (`this_run_do'), expected to be inside any path/`this_repo'/" "Do Files (*.do)|*.do|All Files (*.*)|*.*" do

    * If user clicked cancel without selecting a file or chose a file that is not a do, will run into error later
    if _rc == 0 {

      * Pretend user chose what was expected in terms of string lenght to parse
      local user_chosen_do   = substr("$path_and_run_do",   - strlen("`this_run_do'"),     strlen("`this_run_do'") )
      local user_chosen_path = substr("$path_and_run_do", 1 , strlen("$path_and_run_do") - strlen("`this_run_do'") - 1 )

      * Replace backward slash with forward slash to avoid possible troubles
      local user_chosen_path = subinstr("`user_chosen_path'", "\", "/", .)

      * Check if master do-file chosen by the user is master_run_do as expected
      * If yes, attributes the path chosen by user to the clone, if not, exit
      if "`user_chosen_do'" == "`this_run_do'"  global clone "`user_chosen_path'"
      else {
        noi disp as error _newline "{phang}You selected $path_and_run_do as the master do file. This does not match what was expected (any path/`this_repo'/`this_run_do'). Code aborted.{p_end}"
        error 2222
      }
    }
  }

  * Regardless of the method above, check clone
  *---------------------------------------------
  * Confirm that clone is indeed accessible by testing that master run is there
  * If not, abort
  *-----------------------------------------------------------------------------
  
  cap confirm file "${clone}/`this_run_do'"
  if _rc != 0 {
    noi disp as error _n `"{phang}Having issues accessing your local clone of the `this_repo' repo. Please double check the clone location specified in the run do-file and try again.{p_end}"'
    error 2222
  }

  *-----------------------------------------------------------------------------
  * 3) Download and install required user written ado's
  *-----------------------------------------------------------------------------
  * Fill this list will all user-written commands this project requires
  * that can be installed automatically from ssc
  * Note: this list is not exhaustive, it is only the ones that are not
  * already installed in the standard Stata installation
  *-----------------------------------------------------------------------------
  *hoishapely

  local user_commands hoi catenate stcmd wbopendata carryforward _gwtmean estout grqreg missings adecomp repest tablemat xsvmat alorenz filelist psmatch2 tknz schemepack filelist 

  * Loop over all the commands to test if they are already installed, if not, then install
  * Note: the command -which- is used to test if a command is already installed

  foreach command of local user_commands {
    cap which `command'
    if _rc == 111 ssc install `command'
  }

  * that can be installed automatically from ssc
  * Note: this list is not exhaustive, it is only the ones that are not
  * already installed in the standard Stata installation
  * Note: the command -which- is used to test if a command is already installed
  * Note: the command -cap- is used to avoid error messages if the command is not installed
  local sjpkg "  st0613 linewrap "

  cap which github
  if _rc == 111 net install github, from("https://haghish.github.io/github/")

  cap which markdoc
  if _rc == 111 github install haghish/markdoc, stable


  * Loop over all the commands to test if they are already installed, if not, then install
  foreach command of local sjpkg {
    if ("`command'"=="st0613") {
      cap which vc_bw
      net describe `command', from(http://www.stata-journal.com/software/sj20-3)
      if _rc == 111 net install `command'.pkg  
    }
     if ("`command'"=="linewrap") {
      cap which `command'
      net describe `command', from(http://digital.cgdev.org/doc/stata/MO/Misc)
      if _rc == 111 net install `command'.pkg  
    }
  }

  * Set up the default graph scheme and font  
  set scheme white_tableau
  graph set window fontface "arial narrow"

  * Check for EduAnalyticsToolkit package
  /* EDUKIT is the shortname of the public repo EduAnalyticsToolkit.
     For info on the repo: https://github.com/worldbank/EduAnalyticsToolkit
     Though it is not required for calculating SDG_report_2023,
     having the package installed and up-to-date allows to generate automatic
     documentation of all datasets in markdown. */
  cap edukit
  if _rc != 0 {
    noi disp as res _newline "{phang}You don't have the EduAnalytics Toolkit package installed. Please see this link for info on how to install it: https://github.com/worldbank/EduAnalyticsToolkit{p_end}"
    global use_edukit_save = 0
  }
  else if `r(version)' < 1.0 {
    noi disp as res _newline "{phang}You have an outdated version of the EduAnalytics Toolkit package installed. Please see this link for info on how to update it: https://github.com/worldbank/EduAnalyticsToolkit{p_end}"
    global use_edukit_save = 0
  }
  else {
    noi disp as res _newline "{phang}You have an up-to-date version of the EduAnalytics Toolkit package installed. Thus, automatically generated markdown files will be created to document the most relevant datasets.{p_end}"
    global use_edukit_save = 1
  }
  if $use_edukit_save == 0 noi disp as res "{phang}This will not prevent the replication of the main results, but will skip the creation of markdown documentation.{p_end}"

  *-----------------------------------------------------------------------------
  * 4) Paths
  *---------------------------------------------------------------------------

  global teams          "C:/Users/`c(username)'/UNICEF/Chief Statistician Office - Documents/050.Foundational Learning/Analytics"
  global teams_input    "${teams}/01_data/011_stata"
  global teams_output   "${teams}/03_output/"
  *global teams_figures  "${teams}/03.Report/02.plots/"
    
  global documentation  "${clone}/docs"
  global rawdata        "${clone}/data/"
  global programs       "${clone}/stata/workflows"
  global output         "${clone}/internal/reports"
  global hosted_in_repo "${rawdata}/hosted_in_repo"
  
  /* Collection folders */
  * Let the operator's own configuration speak first (the user_config datalib:
  * key, then DATALIB_ROOT), then resolve it against the disk: a configured path
  * may name the library or the place holding it, and with nothing configured a
  * library named "datalib" is discovered under the Z: mirror. ${datalib} ends up
  * holding the library itself, so the datalib_* wrappers -- which take an exact
  * root -- still work. Pass library(<path>) to -datalib- to override per call.
  * First run on a machine: no user_config.yml yet (rc 601). Bootstrap one
  * automatically -- this is the right place for it. The profile IS the setup
  * step, so a write here is expected, whereas -getuserconfig- itself must stay
  * a pure read (a read that writes on failure breaks the CFG conformance cases
  * and repeats the _mkdir side-effect defect; see tests/DIVERGENCES.md).
  * The generated block is prepopulated with everything Stata can detect, the
  * library included, and is opened for editing if anything is left over.
  * 601 = no config file at all; 459 = the file exists but has no block for this
  * operator, which is the usual first-run state on a machine that already syncs
  * the shared user_config.yml carrying colleagues' blocks. Both need a bootstrap.
  capture getuserconfig
  if (_rc == 601) | (_rc == 459) {
    noi disp as txt `"{phang}No user configuration for {bf:`c(username)'} — generating one.{p_end}"'
    capture noisily datalib config, init profile
    if _rc noi disp as error `"{phang}Could not write a configuration (rc=`=_rc'). Run {bf:datalib config, init profile} yourself to see why.{p_end}"'
    capture getuserconfig
  }
  capture datalib_root, find set
  if (_rc == 1) exit 1
  else if (_rc == 199) noi disp as error `"{phang}{bf:datalib_root} not found — is datalib-unicef installed and on the adopath? See {bf:stata/doc/INSTALLATION.md}.{p_end}"'
  else if (_rc)        noi disp as error `"{phang}No datalib library resolved. Pass {bf:library(}{it:path}{bf:)} to {bf:datalib}, or set the {bf:datalib:} key in your user_config.yml.{p_end}"'
  global datalib_hlt   "Z:/datalib-hlt"  // Replace with the correct datalib path
  global datalib_edu   "Z:/datalib-edu"  // Replace with the correct datalib path
  global datalib_nut   "Z:/datalib-nut"  // Replace with the correct datalib path

  *-----------------------------------------------------------------------------
  * 5) Load other auxiliary programs, that are found in this Repo
  *-----------------------------------------------------------------------------
  
  * not needed

  *-----------------------------------------------------------------------------
  * 6) Check if can access UNICEF teams folder
  *-----------------------------------------------------------------------------
  * UNICEF teams folder is always the same for everyone, but may not be available
  * if the user is not access to a UNICEF computer
  * If not available, then use the local clone repo as the teams folder
  *-----------------------------------------------------------------------------

  cap cd "${teams}"
  if _rc == 0     global teams_is_available 1
  else            global teams_is_available 0
  
  if (${teams_is_available}==0) {
    global teams_input    "${clone}/data/011_stata"
    global teams_output   "${clone}/internal/reports"
  }

  * Both the UNICEF teams folder are only used to update the repo (task 04),
  * it is not a problem for users external to UNICEF attempting to replicate main results
  *-----------------------------------------------------------------------------
  * 5) Flag that profile was successfully loaded
  *-----------------------------------------------------------------------------
  * This flag is used to avoid running this profile again if the user runs
  * the master run do-file again
  *-----------------------------------------------------------------------------
  noi disp as result _n `"{phang}`this_repo' clone sucessfully set up (${clone}).{p_end}"'
  global datalib_profile_is_loaded = 1

  *-----------------------------------------------------------------------------

}
