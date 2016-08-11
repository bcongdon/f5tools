require 'objects/f5_object'
require 'utils/resolution'

module F5_Object
  # Abstract F5_Object that manages all facility-level objects in a data center
  class Facility < F5_Object
    include Resolution

    # Hacky way to have global access to current Facility name
    # Generally no collisions because there is always only 1 'dominant' Facility instantiated
    # => (The facility currently connected to)
    @name = nil
    class << self
      attr_reader :name
    end

    # @param [Hash] opts Options hash
    # @option opts [String] cidr_addr Starting addr for the Facility's internal CIDR block
    # @option opts [String] name Facility name
    # @option opts [String] device (Optional)
    # @option opts [bool] should_setup If true, allocates segments, loads endpoints/port symbols.
    #   Otherwise, does nothing. (Optional, defaults to True)
    def initialize(opts)
      @start_cidr = opts.fetch('cidr_addr') # x.x.x.x/14 subnet
      @name = opts.fetch('name') # Shortened facility name (ord, iad)
      device = opts.fetch('device', nil)
      should_setup = opts.fetch('should_setup', true)

      # Setup blocking used in XSite forwarder when we need to instantiate all the Facilities
      # => but don't want them to go and load all of their child objects
      setup(device) if should_setup
    end

    def setup(device = nil)
      # Hacky way to have global access to NetDevice name (same reasoning as above)
      NetDevice.instance_variable_set(:@name, device) if device

      self.class.instance_variable_set(:@name, @name)

      # Load everything
      allocate_segments
      load_endpoints
      load_port_symbols
      instantiate_net_devices
    end

    attr_reader :name
    attr_reader :net_devices

    # Allocates subnets based on YAML configuration
    def allocate_segments(register = true)
      # Load YAML
      yaml = load_or_create_yaml(construct_yaml_path(FACILITY_SEGMENTS_YAML, @name))
      curr_addr = @start_cidr.split('/').first
      raise "No CIDR defined for #{@name}" if curr_addr.nil?
      segment_map = {}
      # Allocate the 'internal' segments
      yaml['internal'].each do |segment|
        # Prevent duplicates - not really necessary
        # if !resolve_segment(segment['name'], false).nil?
        #   puts "Duplicate segment defn: #{segment['name']}"
        #   next
        # end

        # Instantiate new segment with correct size
        seg_opts = {
          'name' => segment['name'],
          'cidr' => "#{curr_addr}/#{segment['size']}"
        }
        new_seg = Segment.new(seg_opts)

        curr_addr = new_seg.next_addr

        # Tilde is a special character for un-saved segments (reserved, unallocated, etc)
        # Don't save these types, but still need to iterate over them to maintain correct spacing
        if segment['name'][0] != '~'
          register_segment(segment['name'], new_seg) if register
          segment_map[segment['name']] = new_seg
        end
      end unless !yaml || yaml['internal'].nil?

      # Register the global segments
      global = load_or_create_yaml GLOBAL_SEGMENTS_YAML
      global.each do |segment|
        new_seg = Segment.new(segment)
        register_segment(segment['name'], new_seg) if register
        segment_map[segment['name']] = new_seg
      end if global

      # Register the 'external' segments
      yaml['external'].each do |segment|
        new_seg = Segment.new(segment)
        register_segment(segment['name'], new_seg) if register
        segment_map[segment['name']] = new_seg
      end unless !yaml || yaml['external'].nil?

      segment_map
    end

    def load_endpoints
      yaml = load_or_create_yaml(construct_yaml_path(FACILITY_ENDPOINTS_YAML, @name))
      # Override default YAML document type
      yaml = [] if yaml == {}
      return unless yaml
      yaml.each do |endpoint|
        register_segment endpoint['name'], endpoint['addr'] unless endpoint['name'][0] == '~'
      end
    end

    # Loads port symbols (named ports)
    def load_port_symbols
      yaml = load_or_create_yaml PORT_SYMBOL_YAML
      yaml.each do |sym|
        register_port sym['name'], sym['port']
      end if yaml
    end

    def instantiate_net_devices
      @net_devices = {}
      # Load all net device YAMLs in facility's net_device subdirectory
      net_device_files = Dir.entries("defs/facilities/#{@name}/net_devices").select { |x| x.end_with? '.yaml' }
      net_device_files.each do |f|
        yaml = load_or_create_yaml("defs/facilities/#{@name}/net_devices/#{f}")
        # Remove '.yaml'
        name = f.slice(0..-6)
        # Initialize if yaml is empty
        yaml ||= {}
        @net_devices[f.slice(name)] = NetDevice.new('name' => name, 'data' => yaml, 'fac_name' => @name)
      end
    end

    def get_device(device)
      raise 'No device specified' unless device
      # Already have an instantiated version of device
      if @net_devices.key? device
        puts "Using facility specific device #{@name}/#{device}"
        return @net_devices[device]
      # Try to load device from template
      else
        puts "Using device template #{device} on facility #{@name}"
        rendered_template = DeviceTemplateRenderer.render_in_facility device, @name
        data = YAML.load(rendered_template)
        n = NetDevice.new('name' => device, 'data' => data, 'fac_name' => @name)
        @net_devices[device] = n
        return n
      end
    end

    # Only should diff one device at a time
    def diff(device, type = nil, name = nil)
      NetDevice.instance_variable_set(:@name, device)
      get_device(device).diff(type, name)
    end

    # Only should apply one device at a time
    def apply(device, type = nil, name = nil)
      NetDevice.instance_variable_set(:@name, device)
      get_device(device).apply(type, name)
    end
  end
end
