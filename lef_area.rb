#! /usr/local/bin/ruby -W0

# Copyright (c) 2005 Cypress Semiconductor, Intl.
# =FILE:   lef_area.rb
#
# =AUTHOR: Clifford Clark (CIX)
#
# =DESCRIPTION: Reads a LEF file and reports cell length, height, and area to std out.
#   INPUTS
#   OUTPUTS
#   SIDEFFECTS
#
# =Revision History:
#  1.01 10/06/2015 CIX First Check-in
#
#

#main 
def main(args)
  if (args.length!=1) then
    puts "Reads a LEF file and reports cell length, height, and area to std out."
    puts "usage: lef_area.rb [lef]\n\n"
    abort
  end

  # Read in the entire LEF file
  lefFilePath = args.shift
  lefFile = File.open(lefFilePath,"r")
  lefLines = lefFile.readlines
  lefFile.close()

  # Iterate over each line of the LEF file
  puts "cellName,length,height,area"
  cellN=nil; l=nil; h=nil; area=nil
  lefLines.each { |line|
    line.chomp!

    # Find cellname line
    if (line=~/^\s*MACRO\s+([\w\d_]+)/)
      cellN = $1
    end

    # Find the cell size line and calc area
    if (line=~/^\s*SIZE\s+([\d\.]+)\s+BY\s+([\d\.]+)/)
      l=$1; h=$2 
      l=l.to_f; h=h.to_f
      area = l*h
      puts [cellN,l,h,area].join(",")
    end
  }
end 


# this runs the program if it is called from 
# command line.  
if __FILE__ == $PROGRAM_NAME then 
  main(ARGV)
end
