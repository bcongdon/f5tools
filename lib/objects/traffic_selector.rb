require 'objects/f5_object'

module F5_Object
  class TrafficSelector < F5_Object
    @path = 'net/ipsec/traffic-selector/'

    # @param [Hash] opts Options Hash
    # @option opts [String] policy IPSec policy name
    # @option opts [String] seg1name Source segment name
    # @option opts [String] seg1cidr Source segment cidr block
    # @option opts [String] seg2name Destination segment name
    # @option opts [String] seg2cidr Destination segment cidr block
    def initialize(opts)
      @policy = opts.fetch 'policy'
      @segment1 = opts.fetch 'seg1name'
      @segment2 = opts.fetch 'seg2name'
      @src = opts.fetch 'seg1cidr'
      @dest = opts.fetch 'seg2cidr'

      @name = "#{@segment1}_#{@segment2}"
      @ext = "~Common~#{@name}"
    end

    def to_json
      payload = { 'name' => "#{@segment1}_#{@segment2}",
                  'ipsecPolicy' => "/Common/#{@policy}",
                  'sourceAddress' => @src,
                  'destinationAddress' => @dest }
      payload.to_json
    end

    def diff
      has_dif = false
      curr = get_server_config
      return true if curr.nil?

      local = JSON.parse(to_json)
      local.each do |key, val|
        has_dif = !assert_same(curr[key], val, key) || has_dif
      end

      has_dif
    end
  end
end
