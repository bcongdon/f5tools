require 'f5_tools'
require 'highline/import'
require 'highline'

module F5_Tools::CLI
  # Useful utility methods for CLI commands
  module CLI_Utils
    include F5_Object
    include F5_Tools::Resolution

    # Gets key from ENV variables or prompts user.
    # @param [String] key Key to get
    def get_cli_input(key, echo: true, env: true)
      echo = false if key == 'Password'
      return ENV["F5_#{key.upcase}"] if env && !ENV["F5_#{key.upcase}"].nil?
      res = ask("Input #{key}: ", echo: echo)
      puts '' unless echo
      res
    end

    # Initialized given facility and device
    # @param [String] fac_name Facility name
    # @param [String] device Net_Device name
    # @return [Facility] Returns created facility
    def init_facility(fac_name, device = nil)
      # Initialize facility from YAML
      facilities = load_or_create_yaml('defs/facilities.yaml')
      unless facilities.key? fac_name
        raise "No CIDR definition for #{fac_name} in facilities.yaml."
      end
      cidr = facilities[fac_name]['internal']
      Facility.new('cidr_addr' => cidr, 'name' => fac_name, 'device' => device)
    end

    # Tries to load hostname from net_device yaml
    # @param [String] fac_name Facility name
    # @param [String] device Net_Device name
    # @return [String] Returns loaded host name or nil if couldn't load
    def get_device_hostname(fac_name, device)
      if File.exist? "defs/facilities/#{fac_name}/net_devices/#{device}.yaml"
        yaml = load_or_create_yaml("defs/facilities/#{fac_name}/net_devices/#{device}.yaml")
        return yaml['hostname'] if yaml['hostname']
      elsif File.exist? "defs/device_templates/#{device}.yaml"
        yaml = load_or_create_yaml("defs/device_templates/#{device}.yaml")
        return yaml['hostname'] if yaml['hostname']
      end
      puts "Couldn't load device hostname from config"
      nil
    end

    # Authenticates F5Wrapper
    # @param [Hash] options Thor options
    def authenticate_with(options, facility: nil, device: nil)
      opts = {}
      opts[:username] = options[:username] || get_cli_input('Username')
      opts[:password] = options[:password] || get_cli_input('Password')
      opts[:host] = options[:host]
      opts[:host] ||= get_device_hostname(facility, device) if facility && device
      opts[:host] ||= get_cli_input('Hostname', env: false)

      F5_Tools::F5Wrapper.authenticate opts[:username], opts[:password], opts[:host]
    end

    # Convert cli kwargs to an object hash
    def splat_to_hash(args)
      args_hash = {}
      raise 'Invalid number of arguments (must be even)' unless args.length.even?
      until args.empty?
        args_hash[args.first] = args[1].split(',').length > 1 ? args[1].split(',') : args[1]
        args = args.drop(2)
      end
      args_hash
    end

    # Convert an object hash to something resembling cli kwargs
    def hash_to_splat(hash)
      str = ''
      hash.each do |key, val|
        val = val.join(',') if val.is_a? Array
        str << "#{key} #{val} "
      end
      str.slice(0..-2)
    end

    # List of facilities using facility folder existence as check
    def facilities_list
      Dir.glob('defs/facilities/*/').map { |x| x.split('/').last }
    end

    # List of devices in a facility using device yaml file existence as check
    def devices_list(facility)
      glob = if facility
               Dir.glob("defs/facilities/#{facility}/*/*.yaml")
             else
               Dir.glob('defs/device_templates/*.yaml')
             end
      glob.map { |x| x.split('/').last[0..-6] }
    end

    # HighLine CLI prompt for facility using an options menu
    def prompt_facility_choice
      puts
      cli = HighLine.new
      puts 'Choices:'
      cli.choose do |menu|
        menu.prompt = 'Facility?'
        menu.choices(*facilities_list)
      end
    end

    # HighLine CLI prompt for device using an options menu
    def prompt_device_choice(facility)
      puts
      cli = HighLine.new
      puts 'Choices:'
      cli.choose do |menu|
        menu.prompt = 'Device?'
        menu.choices(*devices_list(facility))
      end
    end

    # Prepend '* ' to all elements in a list
    def listify(arr)
      arr.map { |x| "* #{x}" }
    end

    def print_lined(str)
      puts ('-' * str.length)
      puts str
      puts ('-' * str.length)
    end
  end
end
