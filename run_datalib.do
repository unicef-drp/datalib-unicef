*==============================================================================*
*! Datalib
*! Project information at: https://github.com/unicef-drp/datalib-unicef

*! MASTER RUN: Executes all tasks sequentially
*==============================================================================*

* Check that project profile was loaded, otherwise stops code
cap assert ${datalib_profile_is_loaded} == 1
if _rc {
  noi disp as error "Please execute profile_datalib.do in the root of this project and try again."
  exit 601
}

*-------------------------------------------------------------------------------
* Run all tasks in this project
*-------------------------------------------------------------------------------
* No ingestion pipelines are bundled in this repo. Add project task do-files
* here, e.g.  do "${clone}/stata/workflows/0NN_<task>.do"
*-------------------------------------------------------------------------------
