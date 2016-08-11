require 'objects/f5_object'

module F5_Object
  class IPSec < F5_Object
    YAML_LOC = YAMLUtils::NET_DEVICE_YAML

    # @param [Hash] opts Options hash
    # @option opts [String] name Name of the IPSec tunnel
    # @option opts [String] src_ip Source endpoint
    # @option opts [String] dest_ip Destination endpoint
    # @option opts [String] seg1name Segment 1 name
    # @option opts [String] seg1cidr Segment 1 CIDR block
    # @option opts [String] seg2name Segment 2 name
    # @option opts [String] seg2cidr Segment 2 CIDR block
    # @option opts [String] preshared_key Preshared key for IPSec tunnel
    def initialize(opts)
      name          = opts.fetch 'name'
      src_ip        = opts.fetch 'src_ip'
      dest_ip       = opts.fetch 'dest_ip'
      seg1name      = opts.fetch 'seg1name'
      seg1cidr      = opts.fetch 'seg1cidr'
      seg2name      = opts.fetch 'seg2name'
      seg2cidr      = opts.fetch 'seg2cidr'
      preshared_key = opts.fetch 'preshared_key'
      @opts = opts

      ike_opts = {
        'name' => name,
        'float_ip' => src_ip,
        'remote_ip' => dest_ip,
        'preshared_key' => preshared_key
      }
      @ike_peer = IKEPeer.new ike_opts

      @ipsec_policy = IPSecPolicy.new('name' => name,
                                      'float_ip' => src_ip,
                                      'remote_ip' => dest_ip)

      @traffic_selector = TrafficSelector.new('policy' => name,
                                              'seg1name' => seg1name,
                                              'seg1cidr' => seg1cidr,
                                              'seg2name' => seg2name,
                                              'seg2cidr' => seg2cidr)
    end

    def diff
      [@ike_peer, @ipsec_policy, @traffic_selector].any?(&:diff)
    end

    def apply(force = false)
      [@ike_peer, @ipsec_policy, @traffic_selector].each { |x| x.apply force }
    end

    def to_yaml
      payload = { 'name' => name }
      keys = %w(src_ip dest_ip seg1name seg1cidr seg2name seg2cidr preshared_key)
      keys.each do |key|
        payload[key] = @opts[key] if @opts[key]
      end
      yamlify(payload)
    end
  end
end
