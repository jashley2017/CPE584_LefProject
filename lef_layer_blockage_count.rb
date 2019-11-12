#! /usr/local/bin/ruby -W0

# Copyright (c) 2018 Cypress Semiconductor, Intl.
# =FILE:   lef_layer_blockage_count.rb
#
# =AUTHOR: Clifford Clark (CIX)
#
# =DESCRIPTION: Gets the count of layer OBS objects in a LEF file for each cell and reports the results as a csv.
#   INPUTS
#   OUTPUTS
#   SIDEFFECTS
#
# =Revision History:
#  1.01 11/09/2018 CIX First Check-in
#
#

# Add path to standard cell classes
$LOAD_PATH.push( "/proj/module_automation/golden/module_automation/ruby/CLASSES" )

# Turn off Ruby buffering of writes and Ruby calls OS fflsuh() on each write
# Ruby should flush the buffers on close but have seen cases where it does 
# not happen correctly.  
# may slow down performance of applications writing lots of data. 
# Another option is to use the IO.flush command if the file being
# written needs to be read immediately.
# IO.sync = true

# Provides some additional file and dir manipulation 
# require 'fileutils'

def main(args)
  expectedArgs = 1
  helpMessage = "Usage\nlef_layer_blockage_count.rb input_lef [layer_name]\n"
  helpMessage << "Default [layer_name] is VI1\n" 
  if (args.size<expectedArgs)
    puts helpMessage
    abort
  end

  layer_name = "VI1"
  lef_file = args.shift
  if args.length>0
    layer_name = args.shift
  end


  # Header
  puts "cell_name,#{layer_name}_blockage_count"
  # Open a file and parse some stuff
  infile = File.open(lef_file,"r")
  lines = infile.readlines
  infile.close
  cntr=0
  layer_count=0
  in_obs = false
  in_obs_layer = false
  cell_layer_count = Hash.new()
  while cntr<(lines.length-1)
    line=lines[cntr]
    # Get cell name
    if line=~/^\s*MACRO\s+(\w+)\s*$/
      cell = $1
      layer_count=0
    # Look for obstruction
    elsif line=~/^\s*OBS\s*$/
      in_obs = true
    # Look for layers and get a count
    elsif in_obs && line=~/^\s*LAYER\s+#{layer_name}\s*;/
      in_obs_layer = true
      #keep processinga all the layers and look for the end of the layers
      while in_obs_layer
        cntr+=1
        line=lines[cntr]
        if (line=~/^\s*LAYER\s+/) 
          in_obs_layer = false
        elsif (line=~/^\s*END\s*$/)
          in_obs = false
          in_obs_layer = false
        else
          layer_count+=1
        end
      end
      cell_layer_count[cell]=layer_count
      puts "#{cell},#{layer_count}"
    # Look for end of obs
    elsif in_obs && (line=~/^\s*END\s*$/)
      in_obs = false
    end
    cntr+=1
  end
end #main

# this runs the program if it is called from 
# command line.  
if __FILE__ == $PROGRAM_NAME then 
  x = main(ARGV)
end
