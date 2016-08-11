require 'json'
require 'objects/f5_object'

module F5_Object
  class Forwarder < F5_Object
    include Resolution
    include Assertion

    YAML_LOC = YAMLUtils::NET_DEVICE_YAML

    @path = 'ltm/virtual/'
    @prefix = ['FWDR', 'EFWDR', 'XSITE-FWDR']

    CREATION_INFO = {
      'name' => { conversion: String },
      'src' => { conversion: String },
      'dest' => { conversion: String },
      'target_port' => { conversion: String },
      'xsite' => { conversion: :bool },
      'efwdr' => { conversion: :bool }
    }.freeze

    # @param [Hash] opts Options hash
    # @option opts [String] name Forwarder name. If no other data passed, parsed as <SRC_SEG>_<DST_SEG>_<TARGET_PORT>
    # @option opts [Segment] src Source segment (optional)
    # @option opts [Segment] dest Destination segment (optional)
    # @option opts [Segment] target_port Target port name (optional)
    # @option opts [bool] xsite Forwarder is an XSite fwdr? (optional)
    # @option opts [bool] efwdr Forwarder is an External Forwarder? (optional)
    def initialize(opts)
      @opts = opts
      name = opts.fetch 'name'
      src_seg = opts.fetch 'src', nil
      dest_seg = opts.fetch 'dest', nil
      target_port = opts.fetch 'target_port', nil
      xsite = opts.fetch 'xsite', false
      efwdr = opts.fetch 'efwdr', false
      # @src    => source segment
      # @dest   => dest   segment
      # @target => target port
      @name = xsite ? name : "FWDR_#{name}"
      @name = "E#{@name}" if efwdr

      @src, @dest, @target = name.split('_')

      # Resolve names to actual addresses / ports
      @src_seg     = src_seg     || resolve_segment(@src)
      @dest_seg    = dest_seg    || resolve_segment(@dest)
      @target_port = target_port || resolve_port(@target)

      @ext = "~Common~#{@name}"
    end

    def to_json
      payload = {
        'kind' => 'tm:ltm:virtual:virtualstate',
        'name' => @name,
        'destination' => "/Common/#{@dest_seg.first}:#{@target_port}",
        'source' => @src_seg.to_s,
        'mask' => @dest_seg.mask,
        'profiles' => [{ 'kind' => 'ltm:virtual:profile',
                         'name' => 'PROF_FASTL4_FORWARDING' }],
        'translateAddress' => 'disabled',
        'translatePort' => 'disabled'
      }.to_json
      payload
    end

    def diff
      has_dif = false
      curr = get_server_config
      return true if curr.nil?

      # Simple properties
      has_dif = !assert_same(curr['destination'], "/Common/#{@dest_seg.first}:#{@target_port}", 'destination') || has_dif
      has_dif = !assert_same(curr['source'], @src_seg.to_s, 'source') || has_dif

      # Explicit exception b/c 0.0.0.0 == any
      unless curr['mask'] == 'any' && @dest_seg.mask == '0.0.0.0'
        has_dif = !assert_same(curr['mask'], @dest_seg.mask, 'mask') || has_dif
      end

      has_dif = !assert_same(curr['translateAddress'], 'disabled', 'translateAddress') || has_dif
      has_dif = !assert_same(curr['translatePort'], 'disabled', 'translatePort') || has_dif

      # Profiles
      profiles = F5Wrapper.get(strip_localhost_path(curr['profilesReference']['link']), false)
      profile_names = []
      profiles['items'].each { |i| profile_names << i['name'] }
      has_dif = !assert_coverage(profile_names, ['PROF_FASTL4_FORWARDING'], 'profiles') || has_dif

      has_dif
    end

    def to_yaml
      payload = {
        'name' => name
      }
      %w(src dest target_port xsite efwdr).each do |key|
        payload[key] = @opts[key] if @opts[key]
      end
      yamlify(payload)
    end
  end
end
