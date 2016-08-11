require 'objects/f5_object'

module F5_Object
  class ESNAT < F5_Object
    include Resolution
    include Assertion

    YAML_LOC = YAMLUtils::NET_DEVICE_YAML

    @path = 'ltm/virtual/'
    @prefix = 'SNAT'

    CREATION_INFO = {
      'name' => { conversion: String }
    }.freeze

    # @param [Hash] opts Options hash
    # @option opts [String] name ESNAT name. Inferred to <SRC_SEG>_<DST_SEG>_<TARGET_PORT>
    def initialize(opts)
      @opts_name = opts.fetch 'name'
      # @src    => source segment
      # @dest   => dest   segment
      # @target => target port
      @name = "SNAT_#{@opts_name}"
      @src, @dest, @target = @opts_name.split('_')

      # Resolve names to actual addresses / ports
      @src_seg     = resolve_segment(@src)
      @dest_seg    = resolve_segment(@dest)
      @target_port = resolve_port(@target)

      @pool = @src

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
        'translatePort' => 'disabled',
        'sourceAddressTranslation' => { 'pool' => "/Common/SNAT_#{@pool}",
                                        'type' => 'snat' }
      }

      payload.to_json
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
      yamlify(
        'name' => @opts_name
      )
    end
  end
end
