#parse tlef file, generate list of layers
require 'pp'
class TF_File
    #parses tf file given by file_path. Stores a hash of valid layers with information.
    def initialize(file_path)
        @layers = Array.new
        @file_path = file_path
        
    end

    def layers()
        return @layers
    end
    def tf_parse()
        techLayers_found = false
        techLayers_end = false 
        File.foreach(@file_path).with_index { |line, line_num|
            if line.match(/\(techLayers/) #first find techLayers section
                techLayers_found = true
            elsif line.match(/\) ; techLayers/) #found end of techlayers
                techLayers_end = true
            elsif techLayers_found && !line.match(/^ ;/) #searching techLayers, havent reached end yet, isn't ;(layerName layerNumber Abbr.) line.
                split_line = line.split(" ")
                @layers << split_line[1]
            end
            break if techLayers_end == true
        }
    end
    
end

    filename = "./techfile.tf"
    my_tf_file = TF_File.new(filename)
    my_tf_file.tf_parse()
    puts my_tf_file.layers()