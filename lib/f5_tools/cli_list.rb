require 'utils/cli_utils'
require 'thor'
require 'table_print'

module F5_Tools::CLI
  # 'List' Subcommand CLI Class. See thor help for descriptions of methods
  class List < Thor
    include F5_Object
    include F5_Tools::Resolution
    include F5_Tools::YAMLUtils
    include CLI_Utils

    class_option :objtype, aliases: '-t'
    desc 'objects <facility> <device>', 'List local F5_Object names from config'
    def objects(fac_name, device)
      f = init_facility fac_name, device
      n = f.net_devices[device]

      n.get_local_names(options[:objtype]).each do |cls_name, arr|
        puts "#{cls_name}(s)".colorize(:white).on_black
        puts arr
      end
    end

    desc 'facilities', 'List known facilities'
    def facilities
      puts 'Facilities:'.colorize(:white).on_black
      puts listify(facilities_list)
    end

    desc 'devices <facility>', 'List registered devices in facility'
    def devices(fac_name)
      puts 'Net Devices:'.colorize(:white).on_black + " (#{fac_name})"
      raise "No known facility #{fac_name}" unless facilities_list.include? fac_name
      puts listify(devices_list(fac_name))
    end

    desc 'endpoints <facility>', 'List registered endpoint addresses'
    def endpoints(fac_name)
      init_facility fac_name
      yaml_path = construct_yaml_path(F5_Tools::YAMLUtils::FACILITY_ENDPOINTS_YAML, fac_name)

      puts 'Endpoints:'.colorize(:white).on_black
      data = load_or_create_yaml yaml_path
      tp data
    end

    desc 'segments [facility]', 'List globally (and optionally facility-level) registered segments'
    def segments(fac_name = nil)
      global_data = load_or_create_yaml(F5_Tools::YAMLUtils::GLOBAL_SEGMENTS_YAML)
      puts 'Global Segments:'.colorize(:white).on_black
      tp global_data

      if fac_name
        f = init_facility fac_name
        fac_data = load_or_create_yaml construct_yaml_path(F5_Tools::YAMLUtils::FACILITY_SEGMENTS_YAML, fac_name)
        puts "Segments for #{fac_name}:".colorize(:white).on_black
        puts 'Internal:'.colorize(:white).on_black
        tp fac_data['internal']

        puts 'External:'.colorize(:white).on_black
        tp fac_data['external']

        puts 'Rendered global + external + internal segments:'.colorize(:white).on_black
        tp f.allocate_segments(false).map { |k, v| { 'NAME' => k, 'CIDR' => v.cidr } }
      end
    end

    desc 'port_symbols', 'List registered port symbols'
    def port_symbols
      data = load_or_create_yaml(F5_Tools::YAMLUtils::PORT_SYMBOL_YAML)

      puts 'Port Symbols:'.colorize(:white).on_black
      tp data
    end
  end
end
