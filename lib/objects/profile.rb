require 'json'
require 'objects/f5_object'

module F5_Object
  class Profile < F5_Object
    include Assertion

    @path = 'ltm/profile/'

    ACCEPTABLE_TYPES = ['fastl4', 'client-ssl', 'http'].freeze

    YAML_LOC = 'defs/profiles.yaml'.freeze

    CREATION_INFO = {
      'name' => { conversion: String },
      'type' => { conversion: String },
      'defaultsFrom' => { conversion: String, optional: true },
      'cert' => { conversion: String, optional: true },
      'key' => { conversion: String, optional: true }
    }.freeze

    @spec_types = ['client-ssl', 'http', 'fastl4']

    # @param [Hash] opts Options hash
    # @option opts [String] name Profile name
    # @option opts [String] type See {ACCEPTABLE_TYPES}
    # @option opts [String] defaultsFrom Parent profile (Optional, default inferred from type)
    def initialize(opts)
      @data = opts
      @type = @data['type']

      raise "Unknown type: #{@type}. Acceptable types: #{ACCEPTABLE_TYPES}" unless ACCEPTABLE_TYPES.include? @type

      # Because for some reason, they're sometimes different
      type_to_default = {
        'fastl4' => 'fastL4',
        'client-ssl' => 'clientssl',
        'http' => 'http'
      }

      @default = @data['defaultsFrom'] || type_to_default[@type]
      @name = "PROF_#{type_to_default[@type].upcase}_#{@data['name']}"

      @spec_ext = "#{@type}/"
      @ext = "~Common~#{@name}"
    end

    def to_json
      json_hash = {}
      @data.each do |key, val|
        # Type needs to be handled carefully
        json_hash[key] = val if key != 'type'
      end

      # Format name
      json_hash['name'] = @name

      json_hash['defaultsFrom'] = @default

      # Insert type into the F5 node description
      json_hash['kind'] = "tm:ltm:profile:#{@type}:#{@type}state"

      # Add ciphers if necessary
      if @type == 'client-ssl'
        json_hash['ciphers'] = 'ECDHE-RSA-AES128-CBC-SHA:AES128-SHA256:ECDHE-RSA-AES256-CBC-SHA:AES256-SHA256:ECDHE-RSA-DES-CBC3-SHA:DES-CBC3-SHA:RC4-SHA'
      end
      json_hash.to_json
    end

    def diff
      has_dif = false
      curr = get_server_config
      return true if curr.nil?

      @data.each do |key, val|
        unless %w(type name).include? key
          has_dif = !assert_contains([val.to_s, "/Common/#{val}"], curr[key].to_s, key) || has_dif
        end
      end
      has_dif
    end

    def to_yaml
      yamlify(@data)
    end
  end
end
