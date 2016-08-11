require 'f5_tools'
require 'objects/f5_object'

module F5_Object
  # Abstract F5_Object that manages configuration of a single net_device (F5 instance)
  class NetDevice < F5_Object
    include Resolution
    include Assertion
    include YAMLUtils

    @name = nil
    class << self
      attr_reader :name
    end

    @active_instance = nil
    class << self
      attr_reader :active_instance
    end

    # @param [Hash] opts Options Hash
    # @option opts [String] name Net Device name
    # @option opts [String] data YAML defns of a net_device
    # @option opts [String] fac_name Name of the facility the net_device resides in. Defaults to {Facility.name}
    def initialize(opts)
      @fac_name = opts.fetch 'fac_name', Facility.name
      @name = opts.fetch 'name'
      @data = opts.fetch 'data'

      # Hacky way of having a global reference to the NetDevice name
      # => Works because only one NetDevice is active in the script at any given time
      self.class.instance_variable_set(:@name, @name) if NetDevice.name.nil?
      self.class.instance_variable_set(:@active_instance, self) if NetDevice.active_instance.nil?

      # Load all F5_Objects
      load_nodes
      load_pools
      load_forwarders
      load_profiles
      load_vips
      load_snatpools
      load_monitors
      load_rules
      load_data_groups
      load_dhcp
      load_vlans
      load_esnats
    end

    attr_reader :forwarders
    attr_reader :profiles
    attr_reader :vlans
    attr_reader :vips

    # TODO: Refactor the following

    def load_forwarders
      @forwarders = []
      return unless !@data.nil? && @data.key?('forwarders')
      @data['forwarders'].each do |fwdr|
        @forwarders << if fwdr['xsite']
                         XSiteForwarder.new(fwdr)
                       else
                         Forwarder.new(fwdr)
                       end
      end if @data['forwarders']
    end

    def load_profiles
      @profiles = []
      yaml = load_or_create_yaml('defs/profiles.yaml')
      return unless yaml
      yaml['profiles'].each do |profile_dict|
        @profiles << Profile.new(profile_dict)
      end
    end

    def load_nodes
      @nodes = []
      yaml = load_or_create_yaml("defs/facilities/#{@fac_name}/nodes.yaml")
      return unless yaml
      yaml['nodes'].each do |node|
        n = Node.new(node)
        @nodes << n
        register_node n.name, n
      end
    end

    def load_pools
      @pools = []
      return unless !@data.nil? && @data.key?('pools')
      @data['pools'].each do |pool|
        n = Pool.new pool
        @pools << n
      end
    end

    def load_vips
      @vips = []
      return unless !@data.nil? && @data.key?('vips')
      @data['vips'].each do |vip|
        n = Vip.new vip
        @vips << n
      end
    end

    def load_snatpools
      @snatpools = []
      @snat_translations = []
      return unless !@data.nil? && @data.key?('snatpools')
      @data['snatpools'].each do |snatpool|
        n = Snatpool.new snatpool
        @snatpools << n
        n.members.each { |addr| @snat_translations << SnatTranslation.new('name' => addr) }
      end
    end

    def load_monitors
      @monitors = []
      yaml = load_or_create_yaml('defs/monitors.yaml')
      return unless yaml
      yaml['monitors'].each do |monitor|
        n = HTTPMonitor.new monitor
        @monitors << n
      end
    end

    def load_rules
      @rules = []
      Dir.mkdir('defs/irules') unless Dir.exist? 'defs/irules'
      Dir.entries('defs/irules/').each do |rule_name|
        next if rule_name[0] == '.'
        opts = {
          'name' => rule_name,
          'rule' => get_rule(rule_name)
        }
        @rules << Rule.new(opts)
      end
    end

    def load_data_groups
      @data_groups = []
      Dir.mkdir('defs/data_groups') unless Dir.exist? 'defs/data_groups'
      Dir.entries('defs/data_groups/').each do |file_name|
        next if file_name[0] == '.'

        # Enforce the Datagroup size limit
        if File.new("defs/data_groups/#{file_name}").size > Datagroup::DATAGROUP_FILESIZE_LIMIT
          throw RuntimeError.new("Datagroup '#{file_name}' exceedes internal datagroup size limit of #{Datagroup.DATAGROUP_FILESIZE_LIMIT}")
        end
        yaml = load_or_create_yaml("defs/data_groups/#{file_name}")
        yaml['name'] = file_name.slice(0..-6)
        @data_groups << Datagroup.new(yaml)
      end
    end

    def load_dhcp
      @dhcp_relay = []
      if @data.key?('dhcp_node')
        d = DHCPRelay.new('fqdn' => @data['dhcp_node'])
        @pools << d.pool
        @dhcp_relay << d
      end
    end

    def load_vlans
      @vlans = []
      if @data.key? 'vlans'
        @data['vlans'].each do |entry|
          @vlans << VLAN.new(entry)
        end
      end
    end

    def load_esnats
      @esnats = []
      if @data.key? 'esnats'
        @data['esnats'].each { |n| @esnats << ESNAT.new(n) }
      end
    end

    # Invoked separately because needs user input for pre-shared keys
    def load_ipsecs
      @ipsecs = []
      if @data.key? 'ipsecs'
        @data['ipsecs'].each do |dest_name|
          key = yield dest_name
          facilities = load_or_create_yaml('defs/facilities.yaml')
          src_fac = facilities[Facility.name]
          dest_fac = facilities[dest_name]
          raise "No definition for facility #{ipsecs['name']}" if dest_fac.nil?
          opts = {
            'name' => dest_name.upcase,
            'src_ip' => src_fac['external'],
            'dest_ip' => dest_fac['external'],
            'seg1name' => Facility.name.upcase,
            'seg1cidr' => src_fac['internal'],
            'seg2name' => dest_name.upcase,
            'seg2cidr' => dest_fac['internal'],
            'preshared_key' => key
          }

          @ipsecs << IPSec.new(opts)
        end
      end
    end
    attr_reader :ipsecs

    def get_class_map(type = nil, name = nil)
      # Map F5 Object classes to net_device object buckets
      class_map_orig = { Profile => @profiles,
                         Forwarder => @forwarders,
                         Datagroup => @data_groups,
                         Rule => @rules,
                         HTTPMonitor => @monitors,
                         Node => @nodes,
                         Pool => @pools,
                         Snatpool => @snatpools,
                         Vip => @vips,
                         DHCPRelay => @dhcp_relay,
                         VLAN => @vlans,
                         ESNAT => @esnats,
                         SnatTranslation => @snat_translations,
                         # Shell objects:
                         PacketFilter => [],
                         ManagementRoute => [],
                         NAT => [] }

      # If a type is defined, clear out all arrays that don't match the given type
      class_map = class_map_orig.select { |k, _v| k.to_s.split('::').last.casecmp(type.downcase).zero? } unless type.nil?
      class_map ||= class_map_orig

      if class_map.empty?
        puts "Error: No class matches #{type}".red
        puts 'Valid choices: ' + class_map_orig.keys.map { |cls| cls.to_s.split('::').last }.join(', ')
        throw RuntimeError.new
      end

      # Furthermore, if a name is defined, clear out all objects that don't match the name
      class_map.each do |_k, v|
        v.select! do |g|
          # Special case for abstract objects that have many names
          if g.name.is_a? Array
            g.name.map(&:downcase).include? name.downcase
          else
            g.name.casecmp(name.downcase).zero?
          end
        end
      end unless name.nil?

      unless class_map.any? { |_k, v| !v.empty? }
        puts '* Query too specific, no objects are selected.'.colorize(:red).on_black
        puts '* Run \'f5tools list\' to get a list of available types and object names'
      end

      class_map
    end

    def get_local_names(type = nil)
      loc_names = {}
      class_map = get_class_map type
      class_map.each do |cls, arr|
        loc_names[cls.to_s.split('::').last] = arr.map(&:name)
      end
      loc_names.select { |_k, v| !v.empty? }
    end

    def get_object_jsons(type = nil, name = nil)
      loc_names = {}
      class_map = get_class_map type
      class_map.each do |cls, arr|
        loc_names[cls.to_s.split('::').last] = name.nil? ? arr : arr.select { |x| x.name == name }
      end
      loc_names.select { |_k, v| !v.empty? }
    end

    def diff(type = nil, name = nil)
      has_diff = false

      class_map = get_class_map type, name
      # Diff everything
      class_map.each do |cls, ary|
        puts "Diffing: #{cls.to_s.split('::').last}(s)".colorize(:white).on_black unless ary.nil? || ary.empty?
        res = ary.map(&:diff) unless ary.nil?
        unless ary.empty?
          puts res.none? ? 'No changes'.colorize(:green) : 'Diffs exist'.colorize(:red).on_black
        end

        has_diff ||= res.any?
      end
      # Global name checking (only when no name specified)
      puts 'Diffing: Global names'.colorize(:white).on_black
      class_map.each do |cls, list|
        # Compile list of object names
        loc_names = list.map(&:name)
        # First element in array based F5_Object is the abstract name
        loc_names.map! { |x| x.is_a?(Array) ? x.slice(1..-1) : x }
        loc_names.flatten!
        # Load whitelist
        whitelist = load_or_create_yaml('defs/whitelist.yaml')[cls.to_s.split('::').last]
        # Take off names that match the whitelist from possible 'bad' objects
        global_names = cls.get_global_names.reject do |name|
          next(false) if whitelist.nil?
          found = false
          whitelist.each do |reg|
            found = true unless (Regexp.new(reg) =~ name).nil?
          end
          found
        end
        # Ignore names that don't match the class prefix (i.e. VIP_ shouldn't match a FWDR_ even though they're both in ltm/virtual)
        global_names = global_names.select do |x|
          # Keep all if no prefix
          if cls.prefix.nil?
            true
          # Class has an array of prefixes (i.e. VIP == EVIP)
          elsif cls.prefix.is_a?(Array)
            cls.prefix.any? { |pfx| x.start_with?(pfx) }
          # Class with only one prefix (i.e. FWDR)
          else
            x.start_with?(cls.prefix)
          end
        end
        # Do diff with coverage assertion
        has_diff = !assert_coverage(global_names, loc_names, cls.to_s.split('::').last, true) || has_diff
      end if name.nil?
      has_diff
    end

    def apply(type = nil, name = nil)
      # Filter based on type / name
      class_map = get_class_map type, name

      # Do apply
      class_map.map do |cls, ary|
        next true if ary.nil? || ary.empty?
        puts "Applying: #{cls.to_s.split('::').last}(s)".colorize(:white).on_black
        res = ary.map(&:apply).all?
        puts (res ? 'Successful'.colorize(:green) : 'Failed'.colorize(:red))
        res
      end.all?
    end
  end
end
