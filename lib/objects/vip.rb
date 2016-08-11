require 'json'
require 'objects/f5_object'

module F5_Object
  class Vip < F5_Object
    include Resolution
    include Assertion

    YAML_LOC = YAMLUtils::NET_DEVICE_YAML

    @path = 'ltm/virtual/'

    CREATION_INFO = {
      'name' => { conversion: String },
      'pool' => { conversion: String, optional: true },
      'dest' => { conversion: String, optional: true },
      'port' => { conversion: String, optional: true },
      'rules' => { conversion: :comma_separated, optional: true },
      'profiles' => { conversion: :comma_separated, optional: true }
    }.freeze

    # Internal vips are "VIP", extrernal vips are labeled "EVIP"
    @prefix = %w(VIP EVIP)

    # @param [Hash] opts Option hash
    # @option opts [String] name VIP Name. Unless overrided, infers to <SERVICE-POOL>_<RESOURCE>_<TARGET_PORT>
    # @option opts [String] pool Pool name to be used as the pool behind the VIP (Optional)
    # @option opts [String] dest Endpoint (Optional)
    # @option opts [String] port Service port (Optional)
    # @option opts [Array<String>] rules List of iRules to be applied (Optional)
    # @option opts [Array<String>] profiles List of profiles to be applied (Optional)
    def initialize(opts)
      @data = opts

      @name = opts.fetch 'name'

      # Name format: E/VIP_<SERVICE-POOL>_<RESOUCE>_<TARGET>
      @type, @serv_pool, @resource, @target = @name.split('_')

      @pool = opts.fetch 'pool', nil

      @dest_addr = opts.fetch('dest', nil) || resolve_endpoint("#{@serv_pool}_#{@resource}", Facility.name)
      @target_port = opts.fetch('port', nil) || resolve_port(@target)

      @ext = "~Common~#{@name}"
    end

    def to_json
      payload = {
        'kind' => 'tm:ltm:virtual:virtualstate',
        'name' => @name,
        'destination' => "/Common/#{@dest_addr}:#{@target_port}",
        'ipProtocol' => 'tcp',
        'mask' => '255.255.255.255'
      }

      # Add optional parameters to payload
      # Add pool to payload
      payload['pool'] = "/Common/#{@pool}" if @data.key? 'pool'
      # Add rules to payload
      payload['rules'] = @data['rules'].map { |x| "/Common/#{x}" } if @data.key? 'rules'
      # Add snatpool to payload
      payload['sourceAddressTranslation'] = { 'pool' => "/Common/#{@data['snatpool']}", 'type' => 'snat' } if @data.key? 'snatpool'
      # Add profiles to payload
      payload['profiles'] = @data['profiles'] if @data.key? 'profiles'

      payload.to_json
    end

    def diff
      has_dif = false
      curr = get_server_config
      return true if curr.nil?

      payload = JSON.parse(to_json)

      # Compare local payload with loaded payload
      payload.each do |key, val|
        # Profiles needs more detailed checks
        unless key == 'profiles'
          has_dif = !assert_same(curr[key], val, key) || has_dif
        end
      end

      # Profiles
      profiles = F5Wrapper.get(strip_localhost_path(curr['profilesReference']['link']), false)
      profile_names = []
      profiles['items'].each { |i| profile_names << i['name'] }

      unless payload['profiles'].nil?
        payload['profiles'].each do |prof_name|
          has_dif = !assert_contains(profile_names, prof_name, 'profiles') || has_dif
        end
      end

      has_dif
    end

    def to_yaml
      payload = { 'name' => @name }
      keys = %w(name pool dest port rules profiles)
      keys.each do |key|
        payload[key] = @data[key] unless @data[key].nil?
      end
      yamlify(payload)
    end

    attr_reader :data
  end
end
