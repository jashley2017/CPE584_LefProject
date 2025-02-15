#! /usr/bin/ruby -W0
# Copyright (c) 2005 Cypress Semiconductor, Intl.
# =FILE:   sortLEFdata.rb
#
# Fall 2019 revision control lives here: 
# https://github.com/jashley2017/CPE584_LefProject
#
# =AUTHOR: JFE
#
# =DESCRIPTION: Reads a LEF file and sorts the data numerically
#   INPUTS
#   OUTPUTS
#   SIDEFFECTS
#
# =Revision History:
#   1.0   01/11/2018  JFE   First Check-in. starting from lef_area
#   2.0   05/08/2019  JFE   From Spring 2019 VLSI class, major re-write 
#

require 'optparse'
require 'logger'
$log = Logger.new(STDOUT)
$log.level = Logger::INFO


class PBR_Int
  # TODO: we are always passing file and index together, wrap both in 
  # PBR_Int and then name it better
  attr_accessor :value
  def initialize()
    @value = 0
  end
end

#
# parses tf file given by file_path. Stores a hash of valid layers with information.
#
class TF_File
  attr_reader :layers
  def initialize(file_path)
      @layers = Array.new
      @file_path = file_path
  end
  def tf_parse()
      techLayers_found = false
      techLayers_end = false 
      File.foreach(@file_path).with_index { |line, line_num|
          if line.match(/\(techLayers/) #first find techLayers section
              techLayers_found = true
          elsif line.match(/^\s*\)/) && techLayers_found == true #found end of techlayers
              techLayers_end = true
          elsif techLayers_found && !line.match(/^ ;/) #search techLayers that aren't comments.
              split_line = line.split(" ")
              @layers << split_line[1]
          end
          break if techLayers_end == true
      }
  end
end

#
# parses tlef file given by file_path. Stores a hash of valid layers with information.
#
class TLEF_File
  def initialize(file_path)
      @tlef_layers = Hash.new
      @file_path = file_path
  end

  def layers()
      return @tlef_layers.keys
  end

  def _match_begin_layer(line)
      layer_name = ''
      if line.match(/^\s*LAYER\s+\w+\s*$/) #line has a layer definition
          layer_name = line.split(" ")[1]# extracted layer name
          layer_name.rstrip!
      end
      return layer_name
  end

  def _match_end_layer(line)
      layer_name = ''
      if line.match(/^\s*END\s+\w+\s*$/) #match end of line
          layer_name = line.split(" ")[1]
          layer_name.rstrip!
      end
      return layer_name
  end

  def tlef_parse()
      File.foreach(@file_path).with_index { |line, line_num|
          if !(line.match(/^\s*\#/) or line.match(/^\s*$/))#only look at lines that aren't comments
              comment_split_line = line.split("#")
              line = comment_split_line[0] #line is now everything before inline comment
              
              #line represents beginning of layer def
              begin_layer = self._match_begin_layer(line)
              if begin_layer != '' #begin layer exists
                  @tlef_layers[begin_layer] = {'begin_line'=> line_num}
              end 

              #line represents end of layer def
              end_layer = self._match_end_layer(line)
              if end_layer != '' #end layer found 
                  if @tlef_layers.key?(end_layer)
                      @tlef_layers[end_layer]['end_line'] = line_num
                  end
              end
          end
      }
  end
end

class LEF_File
  attr_reader :cells
  def initialize(file, errors)
    index = PBR_Int.new
    @errors = errors
    @header = Array.new
    @property_definitions = nil
    @cells = Hash.new
    index.value = 0
    line = get_current_line(file, index)
    until line.match(/PROPERTYDEFINITIONS/) or Cell::start_line?(line)
      # looks for a propert definition or MACRO to start parsing the LEF, everything else is a header.
      if line.match(/\S;\s*$/)
        # check that lines end in semicolons, they should not so add it to errors
        error_msg = (index.value + 1).to_s + "\n"
        @errors[:line_ending_semicolons].push(error_msg)
        line = line.gsub(/;\s*$/, " ;\n")
      end
      @header.push(line)
      line = get_next_line(file, index)
    end
    if line.match(/PROPERTYDEFINITIONS/)
      # if it was property definitions before macros, parse properties in that block
      @property_definitions = Array.new
      @property_definitions_start = line
      line = get_next_line(file, index)
      until line.match(/END PROPERTYDEFINITIONS/)
        if line.match(/\S;\s*$/)
          error_msg = (index.value + 1).to_s + "\n"
          @errors[:line_ending_semicolons].push(error_msg)
          line = line.gsub(/;\s*$/, " ;\n")
        end
        @property_definitions.push(line)
        line = get_next_line(file, index)
      end
      @property_definitions_end = line
      line = get_next_line(file, index)
    else
      # if we got cell/macro first, we are missing our properties, so error
      errors[:missing_property_definitions].push("")
    end
    end_of_file = false
    until end_of_file or line.match(/END LIBRARY/)
      # until the LEF file tells us that there is no more file, keep parsing
      # the goal here is that the Cell will go looking/checking its properties 
      # in the lib to ensure those are correct. It will increment the index until 
      # it is out of the macro and then. This cell and its properties will be added 
      # to the total cells.
      if Cell::start_line?(line)
        new_cell = Cell.new(file, index, errors)
        @cells[new_cell.name] = new_cell
      else
        # at this level of parsing we should only see things that match cells.
        raise "Error: Unexpected line at #{index.value}: #{line}"
        get_next_line(file, index)
      end
      line = get_current_line(file, index)
      if line.nil?
        end_of_file = true
        errors[:missing_end_library_token].push("")
      end
    end
    @end_line = line
    check_for_uncommon_properties(@errors[:strange_class], Cell::classes_found)
    check_for_uncommon_properties(@errors[:strange_symmetry], Cell::symmetries_found)
    check_for_uncommon_properties(@errors[:strange_site], Cell::sites_found)
    check_for_uncommon_properties(@errors[:strange_direction], Pin::directions_found)
    check_for_uncommon_properties(@errors[:strange_use], Pin::uses_found)
  end
  def sort!()
    @cells.each_value{|cell| cell.sort!()}
  end
  def print(outFile)
    @header.each do |line|
      outFile.print line
    end
    if !(@property_definitions.nil?)
      outFile.print @property_definitions_start
      @property_definitions.each do |line|
        outFile.print line
      end
      outFile.print @property_definitions_end
    end
    sortedCellKeys = @cells.keys.sort()
    sortedCellKeys.each do |key|
      @cells[key].print(outFile)
    end
    outFile.print @end_line
  end
  def [](ind)
    @cells[ind]
  end
end

class Cell
  attr_reader :pins, :properties, :keywordProperties, :name
  @@PropertyOrder = ["CLASS", "FOREIGN", "ORIGIN", "EEQ", "SIZE", "SYMMETRY", "SITE", "DENSITY", "PROPERTY"]
  @@classes_found = Hash.new
  @@symmetries_found = Hash.new
  @@sites_found = Hash.new
  def self.start_line?(line)
    return line.match(/^MACRO\s+([\w\d_]+)/)
  end
  def self.register_property(target_hash, property_key, message)
    if target_hash[property_key].nil?
      target_hash[property_key] = Array.new
    end
    target_hash[property_key].push(message)
  end
  def self.classes_found
    return @@classes_found
  end
  def self.symmetries_found
    return @@symmetries_found
  end
  def self.sites_found
    return @@sites_found
  end
  def initialize(file, index, errors)
    class_found = false
    origin_found = false
    size_found = false
    symmetry_found = false
    site_found = false
    line = get_current_line(file, index)
    if !Cell::start_line?(line)
      raise "Error: Attempted to initialize Cell, but file location provided did not start at a Cell."
    end
    @start_line = line
    @start_line_num = index.value + 1
    @name = line.split()[1]
    #line.match(/^MACRO\s+([\w\d_]+)/) {|m| @name = m[1]}
    @errors = errors

    $log.debug("Cell: " + @name)

    @properties = Array.new
    @keywordProperties = Array.new
    @pins = Hash.new
    @obstructions = nil
    
    line = get_next_line(file, index)
    while !line.match(/^END/) && !Cell::start_line?(line)
      # until we get to the end of the MACRO, look for things we know
      if Pin::start_line?(line)
        # look for things that should be under the pins and add it to the pins of the Cell
        new_pin = Pin.new(file, index, errors, @name)
        @pins[new_pin.name] = new_pin
      elsif LayerCollection::start_line?(line)
        # look for things under a layer collection and add it ot the obstructiosn of the Cell
        new_obstruction = LayerCollection.new(file, index, errors)
        @obstructions = new_obstruction
      else
        if line.match(/\S;\s*$/)
          error_msg = (index.value + 1).to_s + "\n"
          @errors[:line_ending_semicolons].push(error_msg)
          line = line.gsub(/;\s*$/, " ;\n")
        end
				split_line = line.split()
				split_line[0] = split_line[0].upcase()
        if split_line[0] == "PROPERTY"
          @keywordProperties.push(line)
        else
          # TODO: should be case split_line[0]
          if split_line[0] == "ORIGIN"
            origin_found = true
            if split_line[1] != "0" || split_line[2] != "0" then
              @errors[:strange_origin].push("Line " + (index.value + 1).to_s + ": " + @name + "\n")
            end
          end
          if split_line[0] == "FOREIGN"
            if split_line[2] != "0" || split_line[3] != "0" then
              @errors[:strange_foreign].push("Line " + (index.value + 1).to_s + ": " + @name + "\n")
            end
          end
          if split_line[0] == "CLASS"
            class_found = true
            Cell::register_property(@@classes_found, split_line[1], "Line " + (index.value + 1).to_s() + ": " + @name + " - " + split_line[1] + "\n")
          end
          if split_line[0] == "SIZE"
            size_found = true
          end
          if split_line[0] == "SYMMETRY"
            symmetry_found = true
            Cell::register_property(@@symmetries_found, split_line[1], "Line " + (index.value + 1).to_s() + ": " + @name + " - " + split_line[1] + "\n")
          end
          if split_line[0] == "SITE"
            site_found = true
            Cell::register_property(@@sites_found, split_line[1], "Line " + (index.value + 1).to_s() + ": " + @name + " - " + split_line[1] + "\n")
          end
          @properties.push(line)
          if !(@@PropertyOrder.include? line.split[0].upcase)
            error_msg = "Line " + (index.value + 1).to_s + ": " + line.strip + "\n"
            @errors[:unknown_cell_property].push error_msg
          end
        end
        get_next_line(file, index)
      end
      line = get_current_line(file, index)
    end
    
      $log.debug((index.value + 1).to_s + ": END cell line " + line)

    # check to see if you have found all of the neccesary components of the Cell
    if !origin_found
      @errors[:missing_origin].push("Line " + @start_line_num.to_s() + ": " + @name + "\n")
    end
    if !class_found
      @errors[:missing_class].push("Line " + @start_line_num.to_s() + ": " + @name + "\n")
    end
    if !symmetry_found
      @errors[:missing_symmetry].push("Line " + @start_line_num.to_s() + ": " + @name + "\n")
    end
    if !site_found
      @errors[:missing_site].push("Line " + @start_line_num.to_s() + ": " + @name + "\n")
    end
    if !size_found
      @errors[:missing_size].push("Line " + @start_line_num.to_s() + ": " + @name + "\n")
    end
    # make sure you have end line
    if line.match(/^END/)
      @end_line = line
      if !line.match(/^END #{Regexp.quote(@name)}/)
        @errors[:mangled_cell_end].push("Line " + (index.value + 1).to_s() + ": " + @name + "\n")
      end
      get_next_line(file, index)
    else
      @errors[:missing_cell_end].push("Line " + (index.value + 1).to_s() + ": " + @name + "\n")
    end
  end
  def sort!()
    # sort all of your cell attributes once they are loaded.
    @pins.each_value{|pin| pin.sort!()}
    if(!@obstructions.nil?)
      @obstructions.sort!()
    end
    @properties.sort!{ |a, b|
      a_key = ""
      b_key = ""
      a.match(/\A\s*([\w\d_]+)/){ |m| a_key = m[1]}
      b.match(/\A\s*([\w\d_]+)/){ |m| b_key = m[1]}
      sort_by_property_list(@@PropertyOrder, a_key, b_key, a<=>b)
    }
    @keywordProperties.sort!()
  end
  def print(outFile)
    # print sorted cell properties to a file
    # TODO: probably should have to do a sort before this, so sort! should be private and called here
    # TODO: writing to a file all over the place is inadvisable, it would be better to ouput a string 
    # that we the output all at once somewhere else.
    outFile.print @start_line
    @properties.each do |line|
      outFile.print line
    end
    sortedPinKeys = @pins.keys.sort()
    sortedPinKeys.each do |key|
      @pins[key].print(outFile)
    end
    if(!@obstructions.nil?)
      @obstructions.print(outFile)
    end
    @keywordProperties.each do |line|
      outFile.print line
    end

    outFile.print @end_line
    outFile.print "\n"
  end
  def [](ind)
    # associate pins to the index of the cells
    @pins[ind]
  end
end

class Pin
  attr_reader :properties, :keywordProperties, :name
  @@PropertyOrder = [
    "TAPERRULE", "DIRECTION", "USE", "NETEXPR", "SUPPLYSENSITIVITY", 
    "GROUNDSENSITIVITY", "SHAPE", "MUSTJOIN", "PROPERTY", 
    "ANTENNAPARTIALMETALAREA", "ANTENNAPARTIALMETALSIDEAREA", 
    "ANTENNAPARTIALCUTAREA", "ANTENNADIFFAREA", "ANTENNAMODEL", 
    "ANTENNAGATEAREA", "ANTENNAMAXAREACAR", "ANTENNAMAXSIDEAREACAR", 
    "ANTENNAMAXCUTCAR"
  ]
  @@directions_found = Hash.new
  @@uses_found = Hash.new
  def self.directions_found
    return @@directions_found
  end
  def self.uses_found
    return @@uses_found
  end
  def self.start_line?(line)
    return line.match(/^\s*PIN\s+/)
  end
  def self.register_property(target_hash, property_key, message)
    if target_hash[property_key].nil?
      target_hash[property_key] = Array.new
    end
    target_hash[property_key].push(message)
  end
  # TODO: initialize should not do any work, seperate into a function that gets called by user
  def initialize(file, index, errors, parent_cell_name)
    line = get_current_line(file, index)
    if !Pin::start_line?(line)
      raise "Error: Attempted to initialize Pin, but file location provided did not start at a Pin."
    end
    found_direction = false
    found_use = false
    @errors = errors
    @start_line = line
    @start_line_num = index.value + 1
    @name = line.split(/PIN /)[1].chomp()
    
    $log.debug("Pin: " + @name)
      
    @properties = Array.new
    @keywordProperties = Array.new
    @ports = Array.new
    line = get_next_line(file, index)
    while !line.match(/^\s*END #{Regexp.quote(@name)}/)
      if LayerCollection::start_line?(line)
        new_port = LayerCollection.new(file, index, errors)
        @ports.push(new_port)
      else
        
        $log.debug((index.value + 1).to_s + ": found pin property " + line)
        
        if line.match(/\S;\s*$/)
          error_msg = (index.value + 1).to_s + "\n"
          @errors[:line_ending_semicolons].push(error_msg)
          line = line.gsub(/;\s*$/, " ;\n")
        end

        if line.match(/^\s*PROPERTY/)
          @keywordProperties.push(line)
        else
          @properties.push(line)
          if !(@@PropertyOrder.include? line.split[0].upcase)
            error_msg = "Line " + (index.value + 1).to_s + ": " + line.strip + "\n"
            @errors[:unknown_pin_property].push error_msg
          end
					m = line.split()
					m[0] = m[0].upcase
          if m[0] == "DIRECTION"
            found_direction = true
            Pin::register_property(@@directions_found, m[1], "Line " + (index.value + 1).to_s() + ": Cell " + parent_cell_name + ", pin " + @name + " - " + m[1] + "\n")
          end
          if m[0] == "USE"
            found_use = true
            Pin::register_property(@@uses_found, m[1], "Line " + (index.value + 1).to_s() + ": Cell " + parent_cell_name + ", pin " + @name + " - " + m[1] + "\n")
          end
        end
        get_next_line(file, index)
      end
      line = get_current_line(file, index)
    end
    if !found_direction
#      puts @start_line_num
#      puts @name
#      puts parent_cell_name
      @errors[:missing_direction].push("Line " + @start_line_num.to_s() + ": Cell " + parent_cell_name + ", pin " + @name + "\n")
    end
    if !found_use
      @errors[:missing_use].push("Line " + @start_line_num.to_s() + ": Cell " + parent_cell_name + ", pin " + @name + "\n")
    end
    @end_line = line
    get_next_line(file, index)
  end
  def sort!()
    @ports = @ports.sort{
      |a, b|
      a.compare_to(b)
    }
    @properties = @properties.sort{ |a, b|
      a_key = a.split()[0].upcase
      b_key = b.split()[0].upcase
      sort_by_property_list(@@PropertyOrder, a_key, b_key, a<=>b)
      #if @@PropertyOrder.include? words[0].upcase
      #  @@PropertyOrder.index(words[0].upcase)
      #else
      #  @@PropertyOrder.length  #put unrecognized properties at end
      #end
    }
    @keywordProperties.sort!()
  end
  def print(outFile)
    outFile.print @start_line
    
    @properties.each do |line|
      outFile.print line
    end
    @ports.each do |port|
      port.print(outFile)
    end
    # @keywordProperties = @keywordProperties.sort
    @keywordProperties.each do |line|
      outFile.print line
    end
    outFile.print @end_line
  end
  def [](ind)
    return @layers[ind]
  end
end

class Layer
  attr_reader :name, :coordinates
  @@coordinate_pad_precision = 3
  def self.start_line?(line)
    return line.match(/^\s*LAYER/)
  end
  def initialize(file, index, errors)
    line = get_current_line(file, index)
    if !Layer::start_line?(line)
      raise "Error: Attempted to initialize Layer, but file location provided did not start at a Layer."
    end
    @errors = errors
    @start_line = line
    @name = line.split(/LAYER /)[1]
    if !LayerCollection::recognized_layer?(@name)
      @errors[:unknown_layer].push("Line " + (index.value + 1).to_s() + ": " + line)
    end
    
    $log.debug((index.value + 1).to_s + ": found layer " + line)
    
    if line.match(/\S;\s*$/)
      error_msg = (index.value + 1).to_s + "\n"
      @errors[:line_ending_semicolons].push(error_msg)
      line = line.gsub(/;\s*$/, " ;\n")
    end

    @coordinates = Array.new
    line = get_next_line(file, index)
    
    $log.debug((index.value + 1).to_s + ":" + line)
    
    until line.match(/(LAYER)|(END)/)
      if line.match(/\S;\s*$/)
        error_msg = (index.value + 1).to_s + "\n"
        @errors[:line_ending_semicolons].push(error_msg)
        line = line.gsub(/;\s*$/, " ;\n")
      end
      # Force coordinate numbers to be written with three decimal places of precision.
      coordinate_pieces = line.split()
			line  = line.split(/\w/)[0]
#      line.match(/^(\s*)/){ |m| line = 1 }
      line += coordinate_pieces[0]
      for i in 1..4
        if !coordinate_pieces[i].match(/\.\d{#{@@coordinate_pad_precision + 1}}/)
          current_num = coordinate_pieces[i].to_f()
          line += " " + "%.#{@@coordinate_pad_precision}f" % current_num
        else
          line += " " + coordinate_pieces[i]
        end
      end
      line += " ;\n"
      # Add coordinate to list.
      @coordinates.push(line)
      line = get_next_line(file, index)
      
      $log.debug((index.value + 1).to_s + ":" + line)
      
    end
  end
  def sort!()
    @coordinates = @coordinates.sort {
      |a, b|
      Layer::coordSort(a, b)
    }
  end
  def self.coordSort(a, b) 
    aspl = a.split()
    bspl = b.split()
    result = 0
    #compare word part
    if aspl[0] != bspl[0]
      result = aspl[0] <=> bspl[0]
    else
      #compare each coordinate as a float
      aspl.zip(bspl).each do |aword, bword|
        af = aword.to_f()
        bf = bword.to_f()
        if af != bf
          result = af <=> bf
          break
        end
      end
    end
    return result
  end
  def print(outFile)
    outFile.print @start_line
    
    @coordinates.each do |line|
      outFile.print line
    end
  end
  def compare_to(other_layer)
    if @coordinates.length() != other_layer.coordinates().length()
      return @coordinates.length() <=> other_layer.coordinates().length()
    else
      index = 0
      @coordinates.each do |coordinate|
        comparison = Layer::coordSort(coordinate, other_layer.coordinates()[index]) 
        if comparison != 0
          return comparison
        end
        index += 1
      end
    end
    return 0
  end
end

class LayerCollection

  @@layer_order_selected = "s40"
  @@layer_orders = Hash.new
  # TODO: make techfile or TLEF required for Layer checks, these lists
  @@layer_orders["s40"] = Array["LP_HVTP","LP_HVTN","CONT", "ME1", "VI1", "ME2","VI2","ME3"]
  @@layer_orders["abc"] = Array["met2", "via", "met1", "mcon", "li1", "nwell", "pwell"]

  attr_reader :layers
  # Either an Obstruction or a Port.
  def self.start_line?(line)
    return line.match(/^\s*(OBS)|(PORT)/)
  end
  def self.layer_order=(new_order)
    if @@layer_orders[new_order].nil?
      puts "Warning: Layer order '#{new_order}' is not defined.\n"
      puts "Using order '#{@@layer_order_selected}' instead.\n"
    else
      @@layer_order_selected = new_order
    end
  end
  def self.layer_order()
    return @@layer_order_selected
  end
  #
  # changes layer orders in the event that a tlef/tf file is found, otherwise
  # uses the default.
  #
  def self.use_tlef_layers(new_layers)
    new_layer_order = "from_tlef"
    @@layer_orders[new_layer_order] = new_layers
    @@layer_order_selected = new_layer_order
  end

  def self.recognized_layer?(name)
    return @@layer_orders[@@layer_order_selected].include?(name.split()[0])
  end
  def initialize(file, index, errors)
    line = get_current_line(file, index)
    if !LayerCollection::start_line?(line)
      raise "Error: Attempted to initialize Obstruction or Port, but file location provided did not start at an Obstruction or Port."
    end
    @start_line = line
    @layers = Hash.new
    @errors = errors
    line = get_next_line(file, index)
    while(Layer::start_line?(line))
      new_layer = Layer.new(file, index, errors)
      @layers[new_layer.name] = new_layer
      line = get_current_line(file, index)
    end
    @end_line = line
    get_next_line(file, index)
  end
  def sort!()
    @layers.each_value{|layer| layer.sort!()}
  end
  def print(outFile)
    outFile.print @start_line
    sorted_layer_names = @layers.keys().sort{ |a, b| layer_name_sort(a, b) }
    sorted_layer_names.each do |key|
      @layers[key].print(outFile)
    end
    outFile.print @end_line
  end
  def [](ind)
    return @layers[ind]
  end
  def layer_name_sort(a, b)
    layer_order = @@layer_orders[@@layer_order_selected]
    a_key = a.split()[0]
    b_key = b.split()[0]
    return sort_by_property_list(layer_order, a_key, b_key, a<=>b)
  end
  def compare_to(other_collection)
    these_keys = @layers.keys().sort()
    those_keys = other_collection.layers().keys().sort()
    index = 0
    these_keys.each do |key|
      if those_keys[index].nil?
        return -1
      end
      if key != those_keys[index]
        return key <=> those_keys[index]
      end
      index += 1
    end
    if !those_keys[index].nil?
      return 1
    end
    # Ports contain identical lists of keys.
    # Sort by comparing the layers they contain.
    these_keys.each do |key|
      comparison = @layers[key].compare_to(other_collection.layers()[key])
      if comparison != 0
        return comparison
      end
    end
    return 0
  end
end

def sort_by_property_list(list, a, b, tiebreaker)
  if list.include?(a) && list.include?(b)
    if list.index(a) != list.index(b)
      return list.index(a) <=> list.index(b)
    else
      return tiebreaker
    end
  elsif list.include?(a)
    return -1
  elsif list.include?(b)
    return 1
  else
    return tiebreaker
  end
  return 0
end

#
# find properties that are strange, (TODO: should be deprecated)
#
def check_for_uncommon_properties(error_array, property_hash)
  rarity_factor_cutoff = 5
  property_type_count = property_hash.keys().length()
  total_property_count = 0
  property_hash.keys().each do |key|
    total_property_count += property_hash[key].length()
  end
  property_hash.keys().each do |key|
    if property_hash[key].length() < (total_property_count / property_type_count) / rarity_factor_cutoff 
      property_hash[key].each do |line|
        error_array.push(line)
      end
    end
  end
end

# TODO: collect all of the "get_current_line" and file related methods 
# and store them under one function class or File wrapper object

#
# takes the next nonempty line past index, while incrementing index for tracking 
# where you are in the file
#
def get_current_line(file, index)
  current_line = file[index.value]
  if !current_line.nil?
    current_line.chomp()
  end
  while (!current_line.nil?) && current_line.match(/\A\s*\Z/)
    index.value += 1
    current_line = file[index.value]
    if !current_line.nil?
      current_line.chomp()
    end
  end
  return current_line
end

#
# does the same as get_current_line, but just does it on the next line.
#
def get_next_line(file, index)
  index.value += 1
  return get_current_line(file, index)
end

#
# class for housing the different syntax rules and comparison checks against the liberty file
# TODO: collect preexisting rules and move them here, do the same for lef and tlef
#
class LibRuleChecker
  #
  # acquire the pin prop that matches the key and value from the lib cell
  # does not check syntax of either side. expected that it would already be checked by other things.
  #
  def self.check_pin_value_in_lef(lib_path, lef_path, lef_pin, lib_pin, lib_pin_prop_key, cell)
    errors = []
    # localize lib components
    lib_pin_name = lib_pin.name
    lib_pin_prop = lib_pin.property(lib_pin_prop_key)
    if lib_pin_prop.nil?
      errors << "#{cell}\n\tFiles: #{lib_path}, #{lef_path}, \n\tPin: #{lib_pin_name}, \n\tProperty: #{lib_pin_prop_key}, Property in LIB is NIL\n"
      return errors
    else 
      lib_pin_prop = lib_pin_prop.upcase
    end
    # localize lef components
    lef_prop_key = lib_pin_prop_key.upcase()
    lef_prop_name_re = /^\s*#{lef_prop_key}(.*)/
    lef_prop_val_re = /.*#{lib_pin_prop.gsub(/[\"\n;]/, '')}.*/

    # check to see if property key is in this lef pin
    lef_pin_prop_str = lef_pin.properties.select { |prop_str| !(prop_str =~ lef_prop_name_re).nil? }
    unless lef_pin_prop_str.empty?
      # if the property exists in the lef check its value
      lef_pin_val_str = lef_pin_prop_str.select{|prop_str| !(prop_str =~ lef_prop_val_re).nil?}
      if lef_pin_val_str.empty?
        errors << "#{cell}\n\tFiles: #{lib_path}, #{lef_path}, \n\tPin: #{lib_pin_name}, \n\tProperty: #{lef_prop_key}\n"
      end 
    end # unless
    return errors
  end
end

# 
# return layers array from either tlef or tf file
#
def get_layers_from_tlef(tlef_fn)
  if tlef_fn.match(/\.tf/)
    new_tf_object = TF_File.new(tlef_fn)
    new_tf_object.tf_parse()
    return new_tf_object.layers()
  else
    #must be tlef file
    new_tlef_object = TLEF_File.new(tlef_fn)
    new_tlef_object.tlef_parse()
    return new_tf_object.layers()
  end

end

def main(opts)
  $log.debug("main")
  
  ################################## WS DIR Parsing (TODO: needs to be method)
  proj_dir = opts.wsdir
  liberty_dirpath = opts.libdir
  files_to_use_dict = nil
  liberty_files = nil
  lef_files = nil
  tlef_files = nil
  unless proj_dir.nil?
    files_to_use_dict = ddc_scan_from_sysio(proj_dir) 
    lef_files = files_to_use_dict['lef']
    liberty_files = files_to_use_dict['lib']
    tlef_files = files_to_use_dict['tlef']
  end

  ################################## LEF Parsing (TODO: needs to be method)
  # Set layer ordering
  layer_order = LayerCollection::layer_order
  LayerCollection::layer_order = layer_order

  # If tlef_file exists use its layers
  if tlef_files
    new_layers = get_layers_from_tlef(tlef_files)
    puts new_layers
    LayerCollection::use_tlef_layers(new_layers)
  end
  
  # Initialize array for the LEF parsing Errors
  errors = Hash.new
  errors[:line_ending_semicolons]       = Array.new 
  errors[:missing_property_definitions] = Array.new
  errors[:missing_end_library_token]    = Array.new
  errors[:mangled_cell_end]             = Array.new
  errors[:missing_cell_end]             = Array.new
  errors[:unknown_pin_property]         = Array.new
  errors[:unknown_cell_property]        = Array.new
  errors[:unknown_layer]                = Array.new
  errors[:missing_origin]               = Array.new
  errors[:strange_origin]               = Array.new
  errors[:strange_foreign]              = Array.new
  errors[:missing_class]                = Array.new
  errors[:strange_class]                = Array.new
  errors[:missing_symmetry]             = Array.new
  errors[:strange_symmetry]             = Array.new
  errors[:missing_size]                 = Array.new
  errors[:missing_site]                 = Array.new
  errors[:strange_site]                 = Array.new
  errors[:missing_direction]            = Array.new
  errors[:strange_direction]            = Array.new
  errors[:missing_use]                  = Array.new
  errors[:strange_use]                  = Array.new


  # if we just have one lef specified by the options, use that
  if lef_files.nil? || lef_files.empty?
    lef_files = [lef_opt_filename]
  end
  parsed_lef_files = Hash.new
  lef_files.each { |lef_file_path|
    # Read in the entire LEF file
    lefFile = File.open(lef_file_path,"r")
    lefLines = lefFile.readlines
    lefFile.close()

    # Strip comments from LEF file
    comment_lines = Array.new
    index = 0
    lefLines.each do |line|
      if line.match(/\#/)
        comment_lines.push("Line " + (index + 1).to_s() + ": " + line.chomp() + "\n")
        lefLines[index] = line.gsub(/\s*\#.*/, "")
      end
      index += 1
    end
    if !comment_lines.empty?
      comments_filename = lef_file_path + "_comments"
      comments_file = File.open(comments_filename, "w")
      comment_lines.each do |line|
        comments_file.write(line)
      end
      comments_file.close()
    end

    
    # Parse the file
    parsed_lef_file = LEF_File.new(lefLines, errors)
    parsed_lef_file.sort!()
    parsed_lef_files[lef_file_path] = parsed_lef_file
  }
  
  ################################## Lib Parsing (TODO: needs to be method)
  unless liberty_dirpath.nil? && liberty_files.nil?
    errors[:lef_missing_cell] = Array.new
    errors[:lef_missing_pin] = Array.new
    errors[:liberty_missing_cell] = Array.new
    errors[:liberty_incorrect_pin_property] = Array.new
    errors[:liberty_missing_pin] = Array.new
    errors[:area_mismatch] = Array.new

    # If the path given doesn't have the folder-name-ending /, add one.
    unless liberty_dirpath.nil?
      if liberty_dirpath.match(/[^\/]$/)
        liberty_dirpath += "/"
      end
      # Get the list of Liberty files in the given folder.
      $log.debug("ls")
      liberty_files.concat(`ls -1 #{liberty_dirpath}*.lib`.split("\n")) #.split("\n")
    end
    # Make a spot for Liberty data to be stored.
    liberty_data = Hash.new

    # Declare all interesting properties to be scraped.
    cell_properties_of_interest = Array.new
    cell_properties_of_interest.push("area")
    pin_properties_of_interest = Array.new
    pin_properties_of_interest.push("direction")

    # For every file in the list:
    liberty_files.each do |filename|
      # TODO: area, pins, and directions (case sensitive)
      # Find all lines that declare the start of a cell.
      $log.debug("grep1")
      cell_lines_list = `grep -n "^\\s*cell\\s*(.*)\\s*{" #{filename}`
      cell_lines_list = cell_lines_list.split("\n")
			#puts cell_lines_list
      cell_properties_lists = Hash.new
      # For every interesting cell property:
      cell_properties_of_interest.each do |cell_property|
        # Find all lines that define that property.
        $log.debug("grep1.1")
#				puts cell_properties_of_interest
#				puts filename.split("\n")[0]
        cell_properties_lists[cell_property] = `grep -n "^\\s*#{cell_property}\\s:" #{filename}`
        cell_properties_lists[cell_property] = cell_properties_lists[cell_property].split("\n")
      end
      # Find all lines that declare the start of a pin.
      $log.debug("grep2")      
      pin_lines_list = `egrep -n "^\\s*(pg_)?pin\\s*(\\(\\S+\\))\\s*{" #{filename}`
      pin_lines_list = pin_lines_list.split("\n")
#      puts pin_lines_list[0]
      pin_properties_lists = Hash.new
      # For every interesting pin property:
      pin_properties_of_interest.each do |pin_property|
        # Find all lines that define that property.
        $log.debug("grep3")
        pin_properties_lists[pin_property] = `grep -n "^\\s*#{pin_property} :" #{filename}`
        pin_properties_lists[pin_property] = pin_properties_lists[pin_property].split("\n")
      end

      liberty_data[filename] = Hash.new
      
      # Using line number information, determine which properties belong to which cells and pins.
      while !(cell_lines_list.empty?)
#        puts "cell_lines_list"
#        puts cell_lines_list
#        puts "cell properties list"
#        puts cell_properties_lists["area"]
#        puts "pin lines list"
#        puts pin_lines_list
#        puts "pin properties list"
#        pin_properties_lists.keys.each { |line|
#          puts pin_properties_list[line]
#        }
        next_liberty_cell = Liberty_Cell.new(cell_lines_list, cell_properties_lists, pin_lines_list, pin_properties_lists)
#        puts next_liberty_cell.name()
        liberty_data[filename][next_liberty_cell.name()] = next_liberty_cell
      end
    end

    ################################## LEF-LIB Compare (TODO: needs to be method)
    # Compare data; run checks.
    missing_cells = Hash.new
    area_mismatch = Hash.new
    missing_pins = Hash.new
    parsed_lef_files.each_pair { |lef_filename, parsed_lef_file|
      parsed_lef_file.cells().keys().each do |cell|      
        liberty_data.keys().each do |filename|
          if liberty_data[filename][cell].nil?
            # cell not found; mark as missing
            if missing_cells[cell].nil?
              missing_cells[cell] = Array.new
            end
            missing_cells[cell].push(filename)
          else
            # cell exists; check properties and pins
            Liberty_Cell::properties().each do |liberty_cell_property|
              if liberty_cell_property == "area"
                # Find SIZE property in LEF file; compare against Liberty files' area properties
                lef_cell_area = nil
                liberty_cell_area = nil
                parsed_lef_file[cell].properties().each do |lef_cell_property|
  #								puts lef_cell_property
  #                lef_cell_property.match(/\s*SIZE\s+\d+\.\d*\s+BY\s+\d+\.\d*\s*;\s*/){ |m|
                  if lef_cell_property.split()[0].upcase() == "SIZE"
                    lef_cell_dim = lef_cell_property.split()
  #									puts "found"
  #									puts lef_cell_dim
                    lef_cell_area = lef_cell_dim[1].to_f() * lef_cell_dim[3].to_f()
                  end
                end
  #              puts liberty_data[filename][cell].searchedProperties()
  #              puts liberty_data[filename][cell].property("area")
                liberty_cell_area = liberty_data[filename][cell].property("area")
                liberty_cell_area = liberty_cell_area.to_f()
                if lef_cell_area.nil?
                  puts "Error: SIZE property not found in LEF file for cell " + cell + "\n"
                end
                if liberty_cell_area.nil?
                  puts "Error: AREA property not found in Liberty file "+ filename + " for cell " + cell + "\n"
                end
  #              puts lef_cell_area
  #              puts liberty_cell_area
                if lef_cell_area != liberty_cell_area
                  if area_mismatch[cell].nil?
                    area_mismatch[cell] = Array.new
                  end
                  area_mismatch[cell].push(filename)
                end
              end
            end
            
            parsed_lef_file.cells()[cell].pins.each do |pin, pin_obj|
  #            puts pin
  #            puts "liberty pins"
              matching_pin = nil
              liberty_data[filename][cell].pins.each do |p|
  #              puts p.name
                if pin.upcase() == p.name.upcase()
                  matching_pin = p
                end
              end

              if matching_pin.nil?
                if missing_pins[cell].nil?
                  missing_pins[cell] = Hash.new
                end
                if missing_pins[cell][pin].nil?
                  missing_pins[cell][pin] = Array.new
                end
                missing_pins[cell][pin].push(filename)
              else
                # pin exists; check properties
                Liberty_Pin::properties().each do |lib_pin_prop_key|
                  errs = LibRuleChecker.check_pin_value_in_lef(lef_filename, filename, pin_obj, matching_pin, lib_pin_prop_key, cell)
                  errs.each { |err|
                    errors[:liberty_incorrect_pin_property].push(err)
                  }
                end
              end
            end
          end
        end
      end
    }
    if !(missing_cells.empty?)
      missing_cells.keys().each do |cell|
        liberty_missing_cell_msg = cell + ":\n"
        missing_cells[cell].each do |filename|
          liberty_missing_cell_msg += "\t" + filename + "\n"
        end
        errors[:liberty_missing_cell].push(liberty_missing_cell_msg)
      end
    end
    if !(area_mismatch.empty?)
      area_mismatch_msg = ""
      area_mismatch.keys().each do |cell|
        area_mismatch_msg = cell + ":\n"
        area_mismatch[cell].each do |filename|
          area_mismatch_msg += "\t" + filename + "\n"
        end
      end
      errors[:area_mismatch].push(area_mismatch_msg)
    end
    if !(missing_pins.empty?)
      liberty_missing_pin_msg = ""
      missing_pins.keys().each do |cell|
        liberty_missing_pin_msg = cell + ":\n"
        missing_pins[cell].keys().each do |pin|
          liberty_missing_pin_msg += "\t" + pin + ":\n"
          missing_pins[cell][pin].each do |filename|
            liberty_missing_pin_msg += "\t\t" + filename + "\n" 
          end
        end
      end
      errors[:liberty_missing_pin].push(liberty_missing_pin_msg)
    end

    lef_missing_cells = Hash.new
    lef_missing_pins = Hash.new
    liberty_data.keys().each do |filename|
      liberty_data[filename].keys().each do |cell|
#        puts cell
        parsed_lef_files.each_value { |parsed_lef_file|
          if parsed_lef_file.cells()[cell].nil?
            # Cell not found in LEF file.
            if lef_missing_cells[cell].nil?
              lef_missing_cells[cell] = Array.new
            end
            lef_missing_cells[cell].push(filename)
  #          puts cell
  #          puts lef_missing_cells[cell]
          else
            # Cell found; check pins.
  #          puts cell
            liberty_data[filename][cell].pins()
            liberty_data[filename][cell].pins().each do |pin|
  #            puts pin
              if parsed_lef_file[cell].pins()[pin.name().upcase()].nil?
                if lef_missing_pins[cell].nil?
                  lef_missing_pins[cell] = Hash.new
                end
                if lef_missing_pins[cell][pin.name()].nil?
                  lef_missing_pins[cell][pin.name()] = Array.new
                end
                lef_missing_pins[cell][pin.name()].push(filename)
              end
            end
          end
        }
      end
    end
    # puts lef_missing_pins.keys()
    lef_missing_cells.keys().each do |cell|
#			puts cell
      lef_missing_cells_msg = cell + ":\n"
      lef_missing_cells[cell].each do |filename|
        lef_missing_cells_msg += "\t" + filename + "\n"
      end
      errors[:lef_missing_cell].push(lef_missing_cells_msg)
    end
    lef_missing_pins.keys().each do |cell|
      lef_missing_pins_msg = cell + ":\n"
      lef_missing_pins[cell].keys().each do |pin|
        lef_missing_pins_msg += "\t" + pin + ":\n"
        lef_missing_pins[cell][pin].each do |filename|
          lef_missing_pins_msg += "\t\t" + filename + "\n"
        end
      end
      errors[:lef_missing_pin].push(lef_missing_pins_msg)
    end
  end

  ################################## Print file and errors (TODO: needs to be method)
  # Print the file
  # TODO: the errors are currently printed on error-to-error basis, they should be 
  # collected and printed file-to-file. ie. Lib1.lib had these errors, Lib2.lib had 
  # other errors
  parsed_lef_files.each_pair { |lef_filename, parsed_lef_file|
    output_filename = lef_filename + "_sorted"
    # TODO: use block format for File.open
    outFile = File.open(output_filename, "w")
    parsed_lef_file.print(outFile)
    outFile.close()
    # If there are errors, print errors to file
    error_file_opened = false
    error_types = errors.keys()
    error_file = nil
    error_description = nil
    error_header_end = "--------------------------------------------------------------\n"
    error_footer =     "--------------------------------------------------------------\n"
    error_types.each do |error_type|
      unless errors[error_type].empty?
        if !error_file_opened then
          error_filename = lef_filename + "_errors"
          error_file = File.open(error_filename, "w")
          error_file_opened = true
        end
        error_description = "\nTest \'" + error_type.to_s() + "\' failed.\n"
        # TODO: should be case error_type
        if error_type == :line_ending_semicolons
          error_description += "Warning: The following lines have improper lack of space before the ending semicolon.\n"
          error_description += "These issues are fixed in " + output_filename + ".\n"
        elsif error_type == :strange_origin
          # error_description += "Warning: The following cells have an unusual ORIGIN specified.\n"
          # ^ strange counts number of occurances, under a certain amount is strange. That is not descriptive nor helpful for testing
          next
        elsif error_type == :strange_foreign
          # error_description += "Warning: The following cells have an unusual FOREIGN specified.\n"
          next
        elsif error_type == :missing_property_definitions
          error_description += "Warning: The LEF file does not have any PROPERTYDEFINITIONS listed at the start of the file.\n"
        elsif error_type == :missing_end_library_token
          error_description += "Error: The LEF file does not contain an 'END LIBRARY' delimiter.\n"
        elsif error_type == :mangled_cell_end
          error_description += "Error: The following cells have non-matching end delimiters.\n"
        elsif error_type == :missing_cell_end
          error_description += "Error: The following cells are missing end delimiters.\n"
        elsif error_type == :unknown_pin_property
          error_description += "Warning: The following lines specify an unrecognized pin property.\n"
        elsif error_type == :unknown_cell_property
          error_description += "Warning: The following lines specify an unrecognized cell property.\n"
        elsif error_type == :unknown_layer
          error_description += "Warning: The following lines defined unrecognized layers.\n"
        elsif error_type == :missing_origin
          error_description += "Error: The following cells do not have an ORIGIN defined.\n"
        elsif error_type == :missing_class
          error_description += "Error: The following cells do not have a CLASS defined.\n"
        elsif error_type == :strange_class
          # error_description += "Warning: The following cells have an unusual CLASS defined.\n"
          next
        elsif error_type == :missing_site
          error_description += "Error: The following cells do not have a SITE defined.\n"
        elsif error_type == :strange_site
          # error_description += "Warning: The following cells have an unusual SITE defined.\n"
          next
        elsif error_type == :missing_size
          error_description += "Error: The following cells do not have a SIZE defined.\n"
        elsif error_type == :missing_symmetry
          error_description += "Error: The following cells do not have a SYMMETRY defined.\n"
        elsif error_type == :strange_symmetry
          # error_description += "Warning: The following cells have an unusual SYMMETRY defined.\n"
          next
        elsif error_type == :missing_direction
          error_description += "Error: The following pins do not have a DIRECTION defined.\n"
        elsif error_type == :strange_direction
          # error_description += "Warning: The following pins have an unusual DIRECTION defined.\n"
          next
        elsif error_type == :missing_use
          error_description += "Error: The following pins do not have a USE defined.\n"
        elsif error_type == :strange_use
          # error_description += "Warning: The following pins have an unusual USE defined.\n"
          next
        elsif error_type == :lef_missing_cell
          error_description += "Error: The following cells were found in Liberty files, but not in the LEF file.\n"
        elsif error_type == :lef_missing_pin
          error_description += "Error: The following cells had the following pins defined in Liberty files, but not in the LEF file.\n"
        elsif error_type == :liberty_missing_cell
          error_description += "Error: The following cells were found in the LEF file, but not in the following Liberty files.\n"
        elsif error_type == :liberty_missing_pin
          error_description += "Error: The following cells had the following pins defined in the LEF file, but not in the following Liberty files.\n"
        elsif error_type == :area_mismatch
          error_description += "Error: The following cells had a SIZE property that was inconsistent with the AREA stated in the following Liberty files.\n"
        elsif error_type == :liberty_incorrect_pin_property
          error_description += "Error: The following cells have mismtached values between LIB and LEF.\n" 
        end
        
        error_description += error_header_end
        errors[error_type].each do |line|
          error_description += line
        end
        error_description += error_footer

        puts error_description
        error_file.print error_description
      else
        puts "\nTest \'" + error_type.to_s() + "\' passed.\n"
      end
    end
    if error_file_opened then
      error_file.close()
    end
  }
end

class Liberty_Cell
  attr_reader :name, :pins
  def self.properties()
    return Array["area"]
  end
  def initialize(cell_start_lines, cell_properties, pin_start_lines, pin_properties)
    @properties = Hash.new
    @pins = Array.new
    start_line = cell_start_lines.shift()
    start_line_num = start_line.split(' ')[0].to_i()
    if (cell_start_lines.empty?)
      next_cell_start_line_num = 9E999
    else
      next_cell_start_line_num = cell_start_lines[0].split(' ')[0].to_i()
    end
#    start_line.match(/cell \(\"(.*)\"\) \{/){ |m|
#      @name = m[0]
#    }
    @name = start_line.split("\"")[1]
		if @name.nil?
			@name = start_line.split(/\(|\)/)[1]
		end
    Liberty_Cell::properties().each do |property|
      advance_to_line(cell_properties[property], start_line_num)
#      puts property
      if !(cell_properties[property].empty?)
#        puts cell_properties[property][0].split(' ')[0]
#        puts cell_properties[property][0].split(' ')[0].to_i()
#        puts next_cell_start_line_num
        if cell_properties[property][0].split(' ')[0].to_i() < next_cell_start_line_num
          @properties[property] = cell_properties[property].shift().split(': ')[1]
        end
      end
    end
      if !(pin_start_lines.empty?)
      while (pin_start_lines[0].split(' ')[0].to_i() < next_cell_start_line_num)
#        puts pin_start_lines
        next_pin = Liberty_Pin.new(pin_start_lines, pin_properties)
#        puts "next pin"
#        puts next_pin.name
        @pins.push(next_pin)
        if pin_start_lines.empty?
          break
        end
      end
    end
  end
  def property(prop)
    return @properties[prop]
  end
  def searchedProperties()
    return @properties.keys
  end
  def [](ind)
    @pins[ind]
  end
end

class Liberty_Pin
  attr_reader :name
  def self.properties()
    # TODO: if pg_pin, should also check that use in LEF is PWR or GND
    return Array["direction"]
  end
  def initialize(pin_start_lines, pin_properties)
    @properties = Hash.new
    start_line = pin_start_lines.shift()
    if pin_start_lines.empty? 
      # pin_start_lines is now shifted into emptiness meaning you are in the last pin
      end_of_pins = true
    else 
      end_of_pins = false
    end
    start_line_num = start_line.split(' ')[0].to_i()
    unless pin_properties.empty? || end_of_pins
      next_pin_start_line_num = pin_start_lines[0].split(' ')[0].to_i()
    end
#    puts "line"
#    puts start_line[0]
#    start_line.match(/pin \((.*)\) \{/){ |m|
#      puts m[:pin_name]
#      @name = m[1].upcase
#    }
    @name = start_line.split(/\(|\)/)[1]
    Liberty_Pin::properties().each do |property|
      advance_to_line(pin_properties[property], start_line_num)
      if end_of_pins || pin_properties[property][0].split(' ')[0].to_i() < next_pin_start_line_num
        @properties[property] = pin_properties[property].shift().split(': ').last
      end
    end
  end
  def property(prop)
    return @properties[prop]
  end
  def searchedProperties()
    return @properties.keys
  end
end

def advance_to_line(arr, line_num)
  if arr.empty?
    return
  end
  while arr[0].split(' ')[0].to_i() < line_num
    arr.shift()
    if arr.empty?
      return
    end
  end
end

#
# Scanner for lefs, libs, and tlefs
#
class DdcScanner
  #
  # top level scan for the filetypes we are looking for
  #
  def self.scan_for_files(proj_dir)
    ddc_dirs = scan_for_dirs(proj_dir)
    dirs_with_files = Hash.new
    ddc_dirs.each_pair{|dir, filetypes|
      dirs_with_files[dir] = Hash.new
      if filetypes.include?('pnr')
        lef_files = scan_for_lef_files(dir)
        dirs_with_files[dir]['lef'] = lef_files
      end
      if filetypes.include?('syn')
        lib_files = scan_for_lib_files(dir)
        dirs_with_files[dir]['lib'] = lib_files
      end
      if filetypes.include?('config')
        conf_files = scan_for_tlef_files(dir)
        dirs_with_files[dir]['tlef'] = conf_files
      end
    }
    return dirs_with_files
  end

  #
  # scans for directories expected to have lefs, libs and tlefs in it.
  #
  def self.scan_for_dirs(proj_dir)
    find_pnr_cmd = [
      "find",
      "#{proj_dir}",
      "-type d",
      "-name 'pnr'"
    ]
    find_syn_cmd = [
      "find",
      "#{proj_dir}",
      "-type d",
      "-name 'syn'"
    ]
    find_conf_cmd = [
      "find",
      "#{proj_dir}",
      "-type d",
      "-name 'config'"
    ]
    # hash of arrays to tell us what resides under that directory
    # should look like:
    # { "fullpath" : ['syn', 'pnr'], "fullpath2": ['config'] }
    ddc_dirs = Hash.new

    find_dirs_with_cmd(find_pnr_cmd, ddc_dirs, "pnr")
    find_dirs_with_cmd(find_syn_cmd, ddc_dirs, "syn")
    find_dirs_with_cmd(find_conf_cmd, ddc_dirs, "config")

    return ddc_dirs
    
  end # scan_for_dirs

  #
  # finds dirs with a find cmd and associates the parent dir with the given key
  #
  def self.find_dirs_with_cmd(find_cmd, ddc_dirs, key)
    find_res = collect_io_results(find_cmd)
    find_res.each { |dir|
        parent = File.expand_path('..', dir)
        if !ddc_dirs[parent].is_a?(Array)
          ddc_dirs[parent] = Array.new
        end
        ddc_dirs[parent] << key
    }
  end # find_dirs_with_cmd

  #
  # scans acquired ddc dirs for lef files
  #
  def self.scan_for_lef_files(ddc_dir)
    find_lef_cmd = [
      "find",
      "-L",
      "#{ddc_dir}/pnr",
      "-type f",
      "-name '*.lef'"
    ]
    return collect_io_results(find_lef_cmd)
  end # scan_for_lef_files

  #
  # scans acquired ddc dirs for lib files
  #
  def self.scan_for_lib_files(ddc_dir)
    find_lib_cmd = [
      "find",
      "-L",
      "#{ddc_dir}/syn",
      "-type f",
      "-name '*.lib'"
    ]
    return collect_io_results(find_lib_cmd)
  end # scan_for_lib_files

  #
  # scans acquired ddc dirs for tlef files
  #
  def self.scan_for_tlef_files(projdir)
    find_tlef_cmd = [
      "find",
      "-L",
      "#{projdir}/config/tech/info",
      "-type f",
      "-name '*.tlef'", 
      "-or",
      "-name 'techfile.tf'"
    ]
    return collect_io_results(find_tlef_cmd)
  end # scan_for_tlef_files

  #
  # execute a system command via IO and format it into array of output lines
  #
  def self.collect_io_results(cmd_opt_list)
    cmd_str = cmd_opt_list.join(" ")
    res_collection = Array.new
    IO.popen(cmd_str) {|res_io|
      res_io.readlines.each { |res_line|
        res_collection << res_line.gsub("\n","")
      }
    }
    return res_collection
  end
end # DdcScanner

#
# sysio wrapper for DdcScanner, takes in project directory for DdcScanner to work on
#
def ddc_scan_from_sysio(proj_dir)
  ddc_dict = DdcScanner.scan_for_files(proj_dir)
  output = ""
  found_tlef = nil
  count = 1
  option_dict = Hash.new
  ddc_dict.each_pair { |ddc_dir, file_types_dict|
    if file_types_dict.key?("tlef")
      if !found_tlef.nil? || file_types_dict['tlef'].length > 1
        output << "WARNING: found multiple TLEFs, using the first one. Specify a TLEF in the args for specific one\n"
      elsif file_types_dict['tlef'].length > 0
        output << "Using tlef config from #{ddc_dir} : #{file_types_dict['tlef'].first}\n"
        found_tlef = file_types_dict['tlef'].first
      else
        output << "WARNING: no TLEF found. Using default layer collections"
      end
      next
    end
    if file_types_dict.key?("lef")
      if file_types_dict.key?("lib")
        output << "#{count}. DDC: #{ddc_dir}, found #{file_types_dict['lef'].length} LEF files and #{file_types_dict['lib'].length} LIB files.\n"
      else
        output << "#{count}. DDC: #{ddc_dir}, only found #{file_types_dict['lef'].length} LEF files, no lib found.\n"
      end
      option_dict[count.to_s] = {"lef" => file_types_dict['lef'], "lib" => file_types_dict['lib']}
      count += 1 
    end
  }
  option_dict.keys.each {|ddc_dir|
    option_dict[ddc_dir]["tlef"] = found_tlef
  }
  puts output
  option_choice = gets.strip
  return option_dict[option_choice]
end

#
# get layers array from tlef/tf file.
#
def get_layers_from_tlef(tlef_fn)
  if tlef_fn.match(/\.tf/)
    new_tf_object = TF_File.new(tlef_fn)
    new_tf_object.tf_parse()
    return new_tf_object.layers()
  else
    #must be tlef file
    new_tlef_object = TLEF_File.new(tlef_fn)
    new_tlef_object.tlef_parse()
    return new_tlef_object.layers()
  end
end

#
# runs if this file was called, this will not run if you simply import the module
#
if __FILE__ == $0
  # parse args and run main
  begin
    RuntimeOptions = Struct.new(:debug, :wsdir, :tlef, :libdir)
    opts = RuntimeOptions.new(false, Dir.pwd, nil, nil)
    parser = OptionParser.new do |o|
      o.separator "Options:"
      o.on("-w","--wsdir=WSDIR", "Specify working directory") do |wsdir|  
        if File.directory? File.expand_path(wsdir) then
          opts.wsdir = wsdir
        else
          raise "#{wsdir}: Directory not accessible"
        end
      end
      o.on("-d","--debug", "Print debugging information") do
        opts.debug = true
        $log.level = Logger::DEBUG
      end
      o.on("-l", "--liberty=LIBERTY", "Specify liberty file directory.") do |libdir|
        opts.libdir = libdir
      end
      o.on("-t TLEF", "Specify path to technology LEF") do |tlef|
        if File.exist? File.expand_path(tlef) then
          opts.tlef = tlef
        else
          raise "#{tlef}: File not accessible"
        end
      end
      o.on_tail("-h", "--help", "Print help") do
        puts parser
        exit! 0
      end
    end
    begin parser.parse!
    rescue => e
      puts e.message
      puts parser
      exit! 1
    end

  main(opts)

  rescue Exception => e
    # $log.fatal e.message
    raise
    exit! 1
  end
end
