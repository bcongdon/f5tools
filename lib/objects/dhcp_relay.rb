require 'objects/f5_object'

module F5_Object
  # Abstract F5_Object to configure a simple DHCP relay
  class DHCPRelay < F5_Object
    include Resolution
    include Assertion

    YAML_LOC = YAMLUtils::NET_DEVICE_YAML
    YAML_KEY = YAMLUtils::ROOT
    YAML_ROOT_KEY = 'dhcp_node'.freeze

    @path = 'ltm/virtual/'
    @prefix = 'DHCP'

    CREATION_INFO = {
      'fqdn' => { conversion: String }
    }.freeze

    # @param [Hash] opts Option hash
    # @option opts [String] fqdn Node fqdn. Used as name, and resolved to be used as IP
    def initialize(opts)
      @node_fqdn = opts.fetch 'fqdn'
      @name = 'DHCP_RELAY'

      opts = {
        'name' => 'DHCP_RELAY',
        'members' => [@node_fqdn + ':67']
      }
      @pool = Pool.new opts
      @ext = "~Common~#{@name}"
    end

    attr_reader :pool

    def to_json
      payload = {
        'name' => @name,
        'destination' => '/Common/255.255.255.255:67',
        'mask' => '255.255.255.255',
        'pool' => "/Common/#{@pool.name}",
        'dhcpRelay' => true
      }
      payload.to_json
    end

    # Asserts similarity of destination, mask, pool, and dhcpRelay status.
    # Also does #diff on member pool
    def diff
      has_dif = false
      curr = get_server_config
      return true if curr.nil?

      has_dif = @pool.diff || has_dif

      local = JSON.parse(to_json)
      local.each do |key, val|
        has_dif = !assert_same(curr[key], val, key) || has_dif
      end

      has_dif
    end

    def apply
      @pool.apply
      super
    end

    def to_yaml
      yamlify(
        'dhcp_node' => @node_fqdn
      )
    end
  end
end
