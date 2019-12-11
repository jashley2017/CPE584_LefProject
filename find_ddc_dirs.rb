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
      "-name 'techlist.tf'"
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
      end
      if file_types_dict['tlef'].length > 0
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
      option_dict[count.to_s] = {"lef" => file_types_dict['lef'], "lib" => file_types_dict['lib'], 'tlef' => found_tlef}
      count += 1 
    end
  }
  puts output
  option_choice = gets.strip
  return option_dict[option_choice]
  # puts option_dict[option_choice]
end


if __FILE__ == $PROGRAM_NAME then 
  # ddc_scan_from_sysio("/proj/tlib/scs8lsa")
  res = ddc_scan_from_sysio("/home/jashley2017/school/cpe584/test")
  puts res
end
