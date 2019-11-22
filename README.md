
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

