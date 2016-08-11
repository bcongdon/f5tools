require 'objects/f5_object'

module F5_Object
  # Abstract F5_Object to create a set of {Forwarder}s that connect segments
  # inside of a facility within the facility and to analogous segments accross facilities
  class XSiteForwarder < F5_Object
    include Resolution

    # @param [Hash] opts Options hash
    # @option opts [String] name Xsite forwarder name. Inferred to <SRC_SEG>_<DST_SEG>_<TARGET_PORT>
    def initialize(opts)
      name = opts.fetch 'name'
      # @name will contain all it's child forwarder names
      @name = [name]

      # Same format as Forwarder
      @src, @dest, @target = name.split('_')

      @target_port = resolve_port(@target)

      load_facilities
      create_forwarders
    end

    # Load facilities and their segments
    def load_facilities
      @src_segments = {}
      @dest_segments = {}
      yaml = load_or_create_yaml('defs/facilities.yaml')
      yaml.each do |name, cidr|
        facility = Facility.new('cidr_addr' => cidr['internal'],
                                'name' => name,
                                'should_setup' => false)
        segments = facility.allocate_segments false
        @src_segments[name] = segments.fetch @src
        @dest_segments[name] = segments.fetch @dest
      end
    end

    # Create the n^2 forwarders between all facilities
    def create_forwarders
      @forwarders = []

      # Source segment in all facilities must be connected to Destination segment in all facilities
      # Result is (num facilities)^2 resulting forwarders
      @src_segments.each do |name1, seg1|
        @dest_segments.each do |name2, seg2|
          fwdr_name = "XSITE-FWDR_#{name1.upcase}-#{seg1.name}_#{name2.upcase}-#{seg2.name}_#{@target}"
          @name << fwdr_name
          opts = {
            'name' => fwdr_name,
            'src' => seg1,
            'dest' => seg2,
            'target_port' => @target_port,
            'xsite' => true
          }
          @forwarders << Forwarder.new(opts)
        end
      end
    end

    def diff
      has_dif = false

      # Diff child forwarders
      has_dif = @forwarders.any?(&:diff)
      has_dif
    end

    def apply
      # Apply child forwarders
      @forwarders.map(&:apply).all?
    end
  end
end
