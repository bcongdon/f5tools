require 'f5_tools'
require 'f5_tools/cli_list'
require 'f5_tools/cli_delete'
require 'f5_tools/cli_define'
require 'f5_tools/cli_apply'
require 'f5_tools/cli_diff'
require 'f5_tools/cli_generate'

require 'utils/cli_utils'

require 'highline/import'
require 'thor'
require 'pp'

module F5_Tools::CLI
  include F5_Object
  # Base CLI Class. See thor help for descriptions of methods
  class CLI < Thor
    include F5_Tools::Resolution
    include F5_Tools::Assertion
    include F5_Tools::YAMLUtils
    include CLI_Utils

    option :facility, aliases: '-f'
    option :device, aliases: '-d'
    desc 'create <object_type>', 'Creates an F5 Object (Node, Pool, Vip, etc.)'
    def create(obj_type = nil, *args)
      # Essentially overriding Thor's built in error handling, but provide all F5_Object types
      unless obj_type
        puts 'ERROR: "f5tools create" was called with no arguments'
        puts 'Usage: "f5tools create <device>'
        puts
        classes = F5_Object::ObjectUtils.defined_objects
        puts 'Valid types: '.colorize(:green) + classes.join(', ')
        return 0
      end
      splat_to_hash(args) unless args.empty? # Raise error if odd number of args right away
      F5_Tools::Resolution.warn = false
      cli = HighLine.new
      obj_type = obj_type.dup.capitalize
      begin
        cls = Object.const_get "F5_Object::#{obj_type}"
      rescue
        puts 'Invalid object type: '.colorize(:red) + obj_type
        classes = F5_Object::ObjectUtils.defined_objects
        puts 'Valid types: '.colorize(:green) + classes.join(', ')
        raise
      end
      fac_name = options[:facility]
      device = options[:device]
      if needs_facility?(cls::YAML_LOC) && fac_name.nil?
        fac_name = prompt_facility_choice
      end
      if needs_device?(cls::YAML_LOC) && device.nil?
        device = prompt_device_choice(fac_name)
      end

      # init_facility(fac_name, device) if fac_name

      # Payload passed in command
      if !args.empty?
        parsed_hash = splat_to_hash args
        new_obj = cls.new parsed_hash

      # Object creation wizard
      else
        obj_dict = {}
        puts "Creating a #{cls}".colorize(:green).on_black

        raise "#{cls} doesn't have a creation wizard." unless cls.const_defined? 'CREATION_INFO'

        # Iterate on keys defined in Class
        cls::CREATION_INFO.each do |key_name, type_dict|
          print_key = type_dict[:alias] || key_name

          print_key += ' [Comma separated]' if type_dict[:conversion] == :comma_separated
          print_key += ' (Optional)' if type_dict[:optional]

          case type_dict[:conversion]
          when :comma_separated
            type_dict[:conversion] = ->(str) { str.include?(',') ? str.split(/,\s*/) : [str] }
          when :bool
            type_dict[:conversion] = ->(str) { return str.downcase.strip == 'y' }
            print_key += ' (y/n)'
          end

          res = cli.ask(print_key + ':', type_dict[:conversion]) { |q| q.validate = /^(?!\s*$).+/ unless type_dict[:optional] }
          # Otherwise, makes an annoying tag in the resulting YAML
          res = String.new(res) if res.class == HighLine::String
          obj_dict[key_name] = res unless res == [''] || res == ''
        end

        # Print equivalend command
        cmd_args = "#{obj_type} #{hash_to_splat(obj_dict)}"
        cmd_args << " -f #{fac_name}" if defined?(fac_name) && fac_name
        cmd_args << " -d #{device}" if defined?(device) && device
        puts "Equivalent command: 'f5tools create #{cmd_args}'"

        # Instantiate
        new_obj = cls.new obj_dict
      end

      # Actually save to YAML
      insert_object new_obj, fac_name, device
    end

    # option :facility, aliases: '-f'
    # desc 'config <facility> <key> <value>', 'Set a template variable for a facility'
    # def config(fac_name, key, val)
    #   path = construct_yaml_path FACILITY_VARS_YAML, fac_name
    #   modify_yaml(path) do |data|
    #     data[key] = val
    #     data
    #   end
    # end

    desc 'delete [SUBCOMMAND]', 'Delete F5 Objects from local configuration'
    subcommand 'delete', Delete

    desc 'list [SUBCOMMAND]', 'Lists F5 Objects from local configuration'
    subcommand 'list', List

    desc 'define [SUBCOMMAND]', 'Define F5_Tools constructs (Facilities, Devices, etc.) in local configuration'
    subcommand 'define', Define

    desc 'apply [SUBCOMMAND]', 'Applies local configuration to the server'
    subcommand 'apply', Apply

    desc 'diff [SUBCOMMAND]', 'Diff local configuration against server config'
    subcommand 'diff', Diff

    desc 'generate [SUBCOMMAND]', 'Generation commands for vlans, json, device templates'
    subcommand 'generate', Generate
  end
end
