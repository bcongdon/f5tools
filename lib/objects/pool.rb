require 'objects/f5_object'

module F5_Object
  class Pool < F5_Object
    include Resolution
    include Assertion

    YAML_LOC = YAMLUtils::NET_DEVICE_YAML

    CREATION_INFO = {
      'name' => { conversion: String },
      'members' => { conversion: :comma_separated, alias: 'member names' },
      'monitors' => { conversion: :comma_separated, optional: true },
      'failsafes' => { conversion: :comma_separated, optional: true },
      'service_port' => { conversion: String, optional: true }
    }.freeze

    LOAD_BALANCING_MODES = ['round-robin', 'ratio-member',
                            'least-connections-member', 'observed-member',
                            'predictive-member', 'ratio-node', 'least-connections-node',
                            'fastest-node', 'observed-node', 'predictive-node',
                            'dynamic-ratio-node', 'fastest-app-response', 'least-sessions',
                            'dynamic-ratio-member', 'weighted-least-connections-member',
                            'weighted-least-connections-node', 'ratio-session',
                            'ratio-least-connections-member', 'ratio-least-connections-node'].freeze

    @path = 'ltm/pool/'

    # @param [Hash] opts Options Hash
    # @option opts [String] name Pool name
    # @option opts [Array<String>] members Array of member node names
    # @option opts [Array<String>] monitors Array of monitor names (Optional)
    # @option opts [Array<String>] failsafes Array of member node names to be used as failsafes (Optional)
    # @option opts [String] service_port Port to use for members and failsafes. If no port provided, it is
    #   assumed that port is included in member/failsafe string.
    # @option opts [String] load_balancing_method See {LOAD_BALANCING_MODES}
    def initialize(opts)
      @name = opts.fetch 'name'

      @port = opts.fetch 'service_port', nil

      # Members and failsafes must be already loaded as nodes
      members = opts.fetch 'members', nil
      @members = members || []
      @members.map! { |m| "#{m}:#{@port}" } if @port
      # @members.each { |m| throw RuntimeError.new("Unknown node #{m}") if resolve_node(m.split(':').first).nil? }

      @failsafes = opts.fetch 'failsafes', []
      @failsafes.map! { |m| "#{m}:#{@port}" } if @port
      # @failsafes.each { |m| throw RuntimeError.new("Unknown node #{m}") if resolve_node(m.split(':')[0]).nil? }

      @monitors = opts.fetch 'monitors', nil
      @monitors ||= []

      @load_balancing_method = opts.fetch 'load_balancing_method', 'round-robin'
      raise "Invalid load balancing method: #{@load_balancing_method}" unless LOAD_BALANCING_MODES.include? @load_balancing_method

      @ext = "~Common~#{@name}"
    end

    def to_json
      members_payload = @members.map do |name|
        { 'name' => name }
      end

      # If the class has failsafes, add them to the payload
      if !@failsafes.nil? && !@failsafes.empty?
        members_payload.each { |m| m['priority-group'] = 10 }
        members_payload += @failsafes.map do |name|
          { 'name' => name, 'priority-group' => 1 }
        end
      end

      payload = {
        'name' => @name,
        'members' => members_payload
      }

      # Default is round-robin
      unless @load_balancing_method == 'round-robin'
        payload['load-balancing-mode'] = @load_balancing_method
      end

      payload['monitor'] = @monitors.join(' and ') unless @monitors.empty?

      payload.to_json
    end

    def diff
      has_dif = false
      curr = get_server_config
      return true if curr.nil?

      # Members
      # Have to do a get for the members - in a separate endpoint
      members = F5Wrapper.get(strip_localhost_path(curr['membersReference']['link']), false)
      members_dict = {}
      members['items'].each { |i| members_dict[i['name']] = i }

      # Assert coverage of server's pool members and local members + failsafes
      has_dif = !assert_coverage(members_dict.keys, @members + @failsafes, 'members') || has_dif

      # Skip priority group checks if already found diff
      unless has_dif
        # Do checks for members and failsafes priority groups
        @members.each { |m| has_dif = !assert_contains([10, 0], members_dict[m]['priorityGroup'], "#{m}:priorityGroup") || has_dif }
        @failsafes.each { |m| has_dif = !assert_same(members_dict[m]['priorityGroup'], 1, 'priorityGroup') || has_dif }
      end

      monitor_names = []
      unless curr['monitor'].nil?
        monitor_names = curr['monitor'].split(' and ').map(&:strip)
      end
      # Coverage assertion for monitors
      @monitors.each { |m| has_dif = !assert_contains(monitor_names, "/Common/#{m}", 'monitors') || has_dif }
      unless curr['loadBalancingMode'].nil? && @load_balancing_method == 'round-robin'
        has_dif = !assert_same(curr['loadBalancingMode'], @load_balancing_method, 'loadBalancingMode') || has_dif
      end

      has_dif
    end

    def to_yaml
      payload = {
        'name' => @name
      }
      payload['members'] = @members if @members && !@members.empty?
      payload['monitors'] = @monitors if @monitors && !@monitors.empty?
      payload['failsafes'] = @failsafes if @failsafes && !@failsafes.empty?
      yamlify(payload)
    end
  end
end
