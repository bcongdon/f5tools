module F5_Tools
  # Handles resolution of names (segments, targets, etc) naively using human-friendly names as keys.
  # Motivation was to have a way of having a pool of common resources (like endpoints) without
  # having a singleton object manage this.
  # This had mixed success, and may/should be refactored at some point.
  # Of particular note is whether or not to alarm on duplicate definitions. The correct answer is
  # 'yes', but due to the way data is loaded from the YAML, especially when multiple Facilities are
  # loaded, this was causing issues.
  module Resolution
    @@ports     = {}
    @@segments  = {}
    @@endpoints = {}
    @@nodes     = {}

    class << self
      attr_accessor :warn
    end
    self.warn = true

    include F5_Tools::YAMLUtils

    # @param [String] name Segment name
    # @param [F5_Object::Segment] seg Segment to be registered
    def register_segment(name, seg)
      # puts "Warning: Duplicate definition for target #{name}" if @@segments.has_key? name
      @@segments[name] = seg
    end

    def resolve_segment(name, warn = true)
      if @@segments.key? name
        return @@segments[name]
      # Try to infer segemnt from fac. i.e. ORD-WEB
      elsif name.include? '-'
        fac, seg_name = name.split('-')
        yaml = load_or_create_yaml('defs/facilities.yaml')
        STDERR.puts "No definition of #{fac.downcase} found.".colorize(:red) unless yaml.key? fac.downcase
        facility = F5_Object::Facility.new('cidr_addr' => yaml[fac.downcase]['internal'],
                                           'name' => fac.downcase,
                                           'should_setup' => false)
        segments = facility.allocate_segments(false)
        throw "No segment #{seg_name} found in #{fac}." unless segments.key? seg_name
        return segments[seg_name]
      else
        throw RuntimeError.new("No definition for segment: #{name}") if warn && Resolution.warn
        return nil
      end
    end

    def resolve_endpoint(name, fac_name)
      # Return saved address if known
      if @@endpoints.key? name
        return @@endpoints[name]
      # Return 'name' if 'name' is a valid IP
      elsif IPAddress.valid? name
        return name
      # Check Facility endpoint YAML for a definition
      else
        begin
          yaml_path = construct_yaml_path FACILITY_ENDPOINTS_YAML, fac_name
          yaml = load_or_create_yaml(yaml_path)
          yaml.each do |endpoint|
            if name == endpoint['name']
              @@endpoints[name] = endpoint['addr']
              return endpoint['addr']
            end
          end
        rescue RuntimeError => e
          raise e if Resolution.warn
        end
        # Throw an error if no definition found
        throw RuntimeError.new("No definition found for endpoint '#{name}'") if Resolution.warn
      end
    end

    def register_endpoint(name, addr)
      @@endpoints[name] = addr
    end

    # Wipes out known segment map
    def clear_segments
      @@segments = {}
    end

    # Tries to resolve a cidr block to a segment object.
    # @return Returns a F5_Object::Segment or nil.
    def resolve_cidr_to_segment(cidr)
      @@segments.each do |name, seg|
        return name if cidr == seg.to_s
      end
      nil
    end

    # Register a target port symbol
    # @param [String] name Port symbol name
    # @param [int] port Target port
    def register_port(name, port)
      @@ports[name.downcase] = port
    end

    # @param [String] name The port symbol to resolve
    # @return Returns port or nil
    # @raise Raises if warn is set to true and cannot find the given port
    def resolve_port(name, warn = true)
      if @@ports.key? name.downcase
        return @@ports[name.downcase]
      else
        STDERR.puts "No definition for target: #{name}".colorize(:red) if warn && Resolution.warn
        return nil
      end
    end

    # Wipes out known port symbols
    def clear_port_symbols
      @@ports = {}
    end

    # Load iRule data from file
    # @param [String] name iRule name
    # @return [String] Returns iRule text loaded from iRule file
    def get_rule(name)
      file_name = "defs/irules/#{name}"
      throw "No rule: #{name}" unless File.exist? file_name
      File.open(file_name).read
    end

    # Register a Node. (Used to assert nodes existence)
    # @param [String] name Friendly Node name
    # @param [F5_Object::Node] node Node to register under name
    def register_node(name, node)
      @@nodes[name] = node
    end

    def resolve_node(name, warn = true)
      if @@nodes.key? name
        return @@nodes[name]
      else
        STDERR.puts "No definition for node: #{name}" if warn && Resolution.warn
        return nil
      end
    end
  end
end
