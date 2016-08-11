require 'thor'
require 'fileutils'
require 'highline'
require 'f5_tools'
require 'json'

require 'utils/cli_utils'

module F5_Tools::CLI
  # 'Delete' Subcommand CLI Class. See thor help for descriptions of methods
  class Delete < Thor
    include F5_Object
    include F5_Tools::Resolution
    include F5_Tools::YAMLUtils
    include CLI_Utils

    desc 'datagroup <name>', 'Deletes a datagroup'
    def datagroup(dg_name)
      File.delete DATA_GROUP_FOLDER + dg_name + '.yaml'
    end

    desc 'endpoint <facility> <name>', 'Delete an endpoint in a facility'
    def endpoint(fac_name, name)
      init_facility fac_name, nil
      yaml_path = construct_yaml_path(FACILITY_ENDPOINTS_YAML, options[:facility])

      modify_yaml yaml_path do |data|
        data.reject { |d| d['name'] == name }
      end
    end

    desc 'facility <facility>', 'Deletes a facility'
    def facility(fac_name)
      FileUtils.rm_rf 'defs/facilities/' + fac_name

      modify_yaml FACILITIES_YAML do |data|
        data.reject { |name, _info| name == fac_name }
      end
    end

    desc 'device <facility> <device>', 'Deletes a net_device inside a facility'
    def device(fac_name, device)
      File.delete construct_yaml_path(NET_DEVICE_YAML, fac_name, device)
    end

    desc 'port_symbol NAME', 'Deletes a named port symbol'
    def port_symbol(name)
      modify_yaml PORT_SYMBOL_YAML do |data|
        data.reject { |d| d['name'] == name }
      end
    end

    option :facility, aliases: '-f'
    desc 'segment <internal/external/global> <name>', 'Delete a segment'
    def segment(loc, name)
      case loc
      when 'global'
        modify_yaml GLOBAL_SEGMENTS_YAML do |data|
          data.reject { |d| d['name'] == name }
        end
      when 'internal', 'external'
        modify_yaml construct_yaml_path(FACILITY_SEGMENTS_YAML, options[:facility]) do |data|
          data[loc].reject! { |d| d['name'] == name }
          data
        end
      end
    end

    option :facility, aliases: '-f'
    option :device, aliases: '-d'
    desc 'object <type> [name]', 'Creates an F5 Object (see option flags)'
    def object(obj_type, obj_name = nil)
      cli = HighLine.new
      obj_type = obj_type.dup.capitalize
      cls = Object.const_get "F5_Object::#{obj_type}"
      fac_name = options[:facility]
      device = options[:device]
      if needs_facility?(cls::YAML_LOC) && fac_name.nil?
        fac_name = prompt_facility_choice
      end
      if needs_device?(cls::YAML_LOC) && device.nil?
        device = prompt_device_choice(fac_name)
      end

      delete_named_object cls, obj_name, fac_name, device
      puts "Deleted #{obj_name}".colorize(:green).on_black if obj_name
    end
  end
end
