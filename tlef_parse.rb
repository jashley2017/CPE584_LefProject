#parse tlef file, generate list of layers
require 'pp'
class TLEF_File
    #parses tlef file given by file_path. Stores a hash of valid layers with information.
    def initialize(file_path)
        @tlef_layers = Hash.new
        @file_path = file_path
        
    end

    def get_layers_list()
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

filename = "./s40ulp-s-rh-6ml-25odr.tlef"
my_file = TLEF_File.new(filename)
my_file.tlef_parse()
puts  my_file.get_layers_list
