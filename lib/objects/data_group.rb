require 'objects/f5_object'

module F5_Object
  # F5_Object for handling F5 iRule Datagroups
  class Datagroup < F5_Object
    include Assertion

    # 15 kb Hard limit for data group size
    DATAGROUP_FILESIZE_LIMIT = 15_000

    # Valid Datagroup types
    VALID_DATAGROUP_TYPES = %w(ip string integer).freeze

    YAML_LOC = YAMLUtils::NO_YAML

    @path = 'ltm/data-group/internal/'

    # @param [Hash] opts Option hash
    # @options opts [String] name
    # @option opts [Hash] members Datagroup hash. Contains the key-val pairs to be used as the data group
    # @option opts [String] type Datagroup type. See {VALID_DATAGROUP_TYPES}
    # @raise [RuntimeError] raises when invalid datagroup 'type' is included in hash
    # @raise [RuntimeError] raises when 'members' is not a hash
    def initialize(opts)
      @name = opts.fetch 'name'
      @type = opts.fetch 'type'
      members_data = opts.fetch 'members', {}

      # External data groups not currently supported
      throw RuntimeError.new("Invalid datagroup type: #{@type}") unless VALID_DATAGROUP_TYPES.include? @type.downcase
      throw RuntimeError.new('Data group members must be in form of a hash.') unless members_data.is_a? Hash
      @members = {}
      # Force @members keys and values to be strings (F5 doesn't like ints in JSON payloads)
      members_data.each { |k, v| @members[k.to_s] = v.to_s }

      @ext = "~Common~#{@name}"
    end

    def to_json
      payload = {
        'name' => @name,
        # F5 Doesn't like non-strings in JSON payloads
        'records' => @members.map { |name, record| { 'name' => name.to_s, 'data' => record.to_s } },
        'type' => @type
      }
      # F5 parses empty strings to 'none', which is annoying
      payload['records'].each { |h| h.delete('data') if h['data'] == '' }
      payload.to_json
    end

    # Asserts coverage on datagroup keys, and asserts that in-common keys have equal values between local config and server
    def diff
      has_dif = false
      curr = get_server_config
      return true if curr.nil?

      records = {}
      curr['records'].each do |rec|
        records[rec['name'].to_s] = rec['data'].to_s
      end

      # Coverage assertion on datagroup keys
      has_dif = !assert_coverage(records.keys, @members.keys.map(&:to_s), 'members') || has_dif

      # Assert that in-common keys have equal values
      common_keys = records.keys & @members.keys
      common_keys.each do |key|
        has_dif = !assert_same(records[key], @members[key], key) || has_dif
      end

      has_dif
    end

    # 'type' cannot be modified, so it is removed from the payload
    def modify_safe_json
      payload = JSON.parse(to_json)

      payload.delete('type')
      payload.to_json
    end

    def to_yaml
      {
        'name' => @name,
        'type' => @type,
        'members' => @members
      }.to_yaml
    end
  end
end
