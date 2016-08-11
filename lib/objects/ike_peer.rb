require 'objects/f5_object'

module F5_Object
  class IKEPeer < F5_Object
    @path = 'net/ipsec/ike-peer/'

    # @param [Hash] opts Options hash
    # @option opts [String] name IKE Peer name
    # @option opts [String] float_ip Source IP (floating IP of source F5)
    # @option opts [String] remote_ip Destination IP
    # @option opts [String] preshared_key Preshared key to be used in IKE
    def initialize(opts)
      @name          = opts.fetch 'name'
      @float_ip      = opts.fetch 'float_ip'
      @remote_ip     = opts.fetch 'remote_ip'
      @preshared_key = opts.fetch 'preshared_key'
      @ext = "~Common~#{@name}"
    end

    def to_json
      {
        'name' => @name,
        'myIdValue' => @float_ip,
        'remoteAddress' => @remote_ip,
        'phase1AuthMethod' => 'pre-shared-key',
        'phase1EncryptAlgorithm' => 'aes256',
        'phase1HashAlgorithm' => 'sha256',
        'phase1PerfectForwardSecrecy' => 'modp1024',
        'presharedKey' => @preshared_key
      }.to_json
    end

    def diff
      has_dif = false
      curr = get_server_config
      return true if curr.nil?

      local = JSON.parse(to_json)
      local.each do |key, val|
        next if key == 'presharedKey'
        has_dif = !assert_same(curr[key], val, key) || has_dif
      end

      has_dif
    end
  end
end
