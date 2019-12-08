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
    find_pnr_cmd_str = find_pnr_cmd.join(" ")
    find_syn_cmd = [
      "find",
      "#{proj_dir}",
      "-type d",
      "-name 'syn'"
    ]
    find_syn_cmd_str = find_syn_cmd.join(" ")
    find_conf_cmd = [
      "find",
      "#{proj_dir}",
      "-type d",
      "-name 'config'"
    ]
    find_conf_cmd_str = find_conf_cmd.join(" ")
    # hash of arrays to tell us what resides under that directory
    # should look like:
    # { "fullpath" : ['syn', 'pnr'], "fullpath2": ['config'] }
    ddc_dirs = Hash.new
    syn_dirs = Array.new
    pnr_dirs = Array.new
    conf_dirs = Array.new

    # need to group each together under a their respective directories
    # so that the user can then pick which chips they want to operate on
    IO.popen(find_syn_cmd_str) {|syn_dir_io|
      syn_dir_io.readlines.each { |syn_dir|
        parent_syn = File.expand_path('..', syn_dir)
        if !ddc_dirs[parent_syn].is_a?(Array)
          ddc_dirs[parent_syn] = Array.new
        end
        ddc_dirs[parent_syn] << 'syn'
      }
    }
    IO.popen(find_pnr_cmd_str) {|pnr_dir_io|
      pnr_dir_io.readlines.each { |pnr_dir|
        parent_pnr = File.expand_path('..', pnr_dir)
        if !ddc_dirs[parent_pnr].is_a?(Array)
          ddc_dirs[parent_pnr] = Array.new
        end
        ddc_dirs[parent_pnr] << 'pnr'
      }
    }
    IO.popen(find_conf_cmd_str) {|conf_dir_io|
      conf_dir_io.readlines.each { |conf_dir|
        parent_conf = File.expand_path('..', conf_dir)
        if !ddc_dirs[parent_conf].is_a?(Array)
          ddc_dirs[parent_conf] = Array.new
        end
        ddc_dirs[parent_conf] << 'config'
      }
    }
    return ddc_dirs
    
  end # scan_for_dirs

  #
  # scans acquired chip dirs for lef files
  #
  def self.scan_for_lef_files(ddc_dir)
    lef_files = Array.new
    find_lef_cmd = [
      "find",
      "-L",
      "#{ddc_dir}/pnr",
      "-type f",
      "-name '*.lef'"
    ]
    find_lef_cmd_str = find_lef_cmd.join(" ")
    IO.popen(find_lef_cmd_str) {|lef_filepath_io|
      lef_filepath_io.readlines.each { |lef_filepath|
        lef_files << lef_filepath
      }
    }
    return lef_files
  end # scan_for_lef_files

  def self.scan_for_lib_files(ddc_dir)
    lib_files = Array.new
    find_lib_cmd = [
      "find",
      "-L",
      "#{ddc_dir}/syn",
      "-type f",
      "-name '*.lib'"
    ]
    find_lib_cmd_str = find_lib_cmd.join(" ")
    IO.popen(find_lib_cmd_str) {|lib_filepath_io|
      lib_filepath_io.readlines.each { |lib_filepath|
        lib_files << lib_filepath
      }
    }
    return lib_files
  end # scan_for_lib_files

  def self.scan_for_tlef_files(projdir)
    tlef_files = Array.new
    find_tlef_cmd = [
      "find",
      "-L",
      "#{projdir}/config/tech/info",
      "-type f",
      "-name '*.tlef'", 
      "-or",
      "-name '*.tf'"
    ]
    find_tlef_cmd_str = find_tlef_cmd.join(" ")
    IO.popen(find_tlef_cmd_str) {|tlef_filepath_io|
      tlef_filepath_io.readlines.each { |tlef_filepath|
        tlef_files << tlef_filepath
      }
    }
    return tlef_files
  end # scan_for_tlef_files
end # DdcScanner

if __FILE__ == $PROGRAM_NAME then 
  ddc_dict = DdcScanner.scan_for_files("/proj/tlib/scs8lsa")
  output = ""
  found_tlef = false
  ddc_dict.each_pair { |ddc_dir, file_types_dict|
    if file_types_dict.key?("tlef")
      if found_tlef || file_types_dict['tlef'].length > 1
        output << "WARNING: found multiple TLEFs, using the first one. Specify a TLEF in the args for specific one\n"
      end
      if file_types_dict['tlef'].length > 0
        output << "Using tlef config from #{ddc_dir} : #{file_types_dict['tlef'].first}\n"
        found_tlef = true
      end
      # TODO: comprehend no tlef
      # tlef dir should have no lef or libs
      next
    end
    if file_types_dict.key?("lef")
      if file_types_dict.key?("lib")
        output << "DDC: #{ddc_dir}, found #{file_types_dict['lef'].length} LEF files and #{file_types_dict['lib'].length} LIB files.\n"
      else
        output << "DDC: #{ddc_dir}, only found #{file_types_dict['lef'].length} LEF files, no lib found.\n"
      end
    end
  }
  puts output
end
