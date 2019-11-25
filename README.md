
1. Comprehend what the Ruby code is doing, noting potential bugs and excessive printing. and fails.

2. Construct all possible test variants and see if it succeeds and fails.

3. LEF/TLEF check needs to check that all LEF layers are in the TLEF

4. Check to make sure everything is case sensitively matching.


Projects TODOs: 
  * add JSON support (trivial)                                                (Josh)
  * tlef from Layer object, set class var of layers by a tlef file.           (Matt)
  * optionalize all functionality better.                                     (James)
     - add  wsdir and appropriate function call
     - ensure every action the program is taking is specified by an argument.
  * allow passing a ws_dir and intelligently search for tlef, lib, and lef    (Josh)
      ideal: 'sortLefdata.rb -wsdir my_proj'
  * general: cleanup as you go                                                (All)
     - functionalize the code (&lt;100 lines per function)
     - cleanup sysout
     - dont be stupid


## November 25, 2019 Meeting Notes: 
* Program method flow
  - Read TLEF under CONFIG and store LAYER for LEF to compare against.
  - Parse projdirs for DDCs, LEFs and LIBs
  - Present user the found DDCs and allow them to pick which to run.
    * Good to add option DDC_dir as well.
  - Parse and Check LEFs and LIBs within selected DDCs
      * Optionally disable errors/warnings based on what you are checking.
* -projdir option
  * Project Directory Structure 
      * Project
          - DDC (name could be anything, DDC to check if has PNR, SYN subdir)
              * PNR
              * SYN
          - CONFIG
              * *.TLEF,TF 
  - There should be one LEF many LIB, LEF cells should appear in ALL libs.
  - You want to be able to specify a project directory and search for DDC/syn and DDC/pnt
  - DDCs can have multiple subdirs with syn and pnr. Do not follow symbolic links and only go to a certain depth.
* general/cleanup
   - PBRInt should instead be LineTrackedFile and contain a file an line number. 
   - strange should be replaces with "missing", "orphan", etc. 
   - Make flowchart usable in powerpoint
* option parsing 
    - standard ruby module for option gathering
    - add projdir, not wsdir
