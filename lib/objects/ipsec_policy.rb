require 'objects/f5_object'

module F5_Object
  class IPSecPolicy < F5_Object
    @path = 'net/ipsec/ipsec-policy/'

    # @param [Hash] opts Options hash
    # @option opts [String] name
    # @option opts [String] float_ip Source endpoint IP
    # @option opts [String] remote_ip Destination endpoint Ip
    def initialize(opts)
      @name = opts.fetch 'name'
      @float_ip = opts.fetch 'float_ip'
      @remote_ip = opts.fetch 'remote_ip'
      @ext = "~Common~#{@name}"
    end

    def to_json
      {
        'name' => @name,
        'ikePhase2AuthAlgorithm' => 'sha1',
        'ikePhase2EncryptAlgorithm' => 'aes256',
        'ikePhase2Lifetime' => 480,
        'ikePhase2PerfectForwardSecrecy' => 'modp4096',
        'mode' => 'tunnel',
        'tunnelLocalAddress' => @float_ip,
        'tunnelRemoteAddress' => @remote_ip
      }.to_json
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
