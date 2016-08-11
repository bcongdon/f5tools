require 'thor'
require 'fileutils'
require 'highline'
require 'f5_tools'
require 'json'

require 'utils/cli_utils'

module F5_Tools::CLI
  # 'Define' Subcommand CLI Class. See thor help for descriptions of methods
  class Define < Thor
    include F5_Object
    include F5_Tools::Resolution
    include F5_Tools::YAMLUtils
    include CLI_Utils

    desc 'facility <facility>', 'Define a facility in local configuration'
    def facility(fac_name)
      puts 'Creating facility:'.colorize(:white).on_black + ' ' + fac_name
      FileUtils.mkdir_p "defs/facilities/#{fac_name}/net_devices"
      ['endpoints.yaml', 'segments.yaml', 'nodes.yaml', '_vars.yaml'].each do |fName|
        FileUtils.touch "defs/facilities/#{fac_name}/#{fName}"
      end
      cli = HighLine.new
      internal = cli.ask 'Facility internal CIDR block?'
      external = cli.ask 'Facility external endpoint? (For ipsec)'
      modify_yaml FACILITIES_YAML do |data|
        data[fac_name] = {}
        data[fac_name]['internal'] = internal
        data[fac_name]['external'] = external
        data
      end
      created_str = 'Defined facility: '.colorize(:green).on_black + fac_name
      print_lined created_str
      puts 'Facilities:'
      puts listify(facilities_list)
    end

    desc 'device <device>', 'Defines a device in local configuration'
    def device(device)
      puts 'Creating net_device:'.colorize(:white).on_black + ' ' + device
      yaml_path = construct_device_path device
      FileUtils.mkdir_p 'defs/device_templates'
      FileUtils.touch yaml_path
      cli = HighLine.new
      hostname = cli.ask 'F5 hostname?'
      modify_yaml yaml_path do |_data|
        { 'hostname' => hostname }
      end
      created_str = 'Defined device: '.colorize(:green).on_black + device.colorize(:blue)
      print_lined created_str
      # puts "Devices in #{fac_name.colorize(:blue)}:"
      # puts listify(devices_list(fac_name))
    end

    option :facility, aliases: '-f'
    desc 'segment <internal/external/global> <name> <cidr_block>', 'Defines a segment in a facility'
    def segment(loc, name, cidr)
      case loc.downcase
      when 'internal', 'external'
        fac_name = options.fetch :facility, HighLine.new.ask('Facility?')
        init_facility fac_name, nil
        yaml_path = construct_yaml_path(F5_Tools::YAMLUtils::FACILITY_PATH.dup + 'segments.yaml', options[:facility])
        loc = loc.downcase

        data = load_or_create_yaml(yaml_path)
        data[loc] = [] unless data[loc]
        data[loc].push('name' => name, loc == 'internal' ? 'size' : 'cidr' => cidr)
      when 'global'
        yaml_path = 'defs/segments.yaml'

        data = load_or_create_yaml(yaml_path)
        data = [] unless data
        data.push('name' => name, 'cidr' => cidr)
      else
        raise 'Invalid location. Choices: internal, external, global'
      end
      File.open(yaml_path, 'w') { |f| f.write data.to_yaml }
    end

    desc 'endpoint <facility> <name> <addr>', 'Defines an endpoint in a facility'
    def endpoint(fac_name, name, addr)
      # init_facility fac_name, nil
      yaml_path = construct_yaml_path(FACILITY_ENDPOINTS_YAML, fac_name)

      data = load_or_create_yaml yaml_path

      data = [] if !data || data == {}
      data.push('name' => name, 'addr' => addr)

      File.open(yaml_path, 'w') { |f| f.write data.to_yaml }

      puts "Defined endpoint '#{name} => #{addr}' in #{fac_name}".colorize(:green)
    end

    desc 'port_symbol <name> <port>', 'Defines a named port symbol'
    def port_symbol(name, port)
      modify_yaml(F5_Tools::YAMLUtils::PORT_SYMBOL_YAML) do |data|
        # Overwrite default datatype (if port_symbols.yaml is empty)
        data = [] if data == {}
        data.push('name' => name, 'port' => port.to_i)
      end
      puts "Defined port symbol '#{name} => #{port}'".colorize(:green)
    end
  end
end
