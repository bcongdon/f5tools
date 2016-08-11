require 'objects/f5_object'

module F5_Object
  class Snatpool < F5_Object
    include Assertion

    YAML_LOC = YAMLUtils::NET_DEVICE_YAML

    CREATION_INFO = {
      'name' => { conversion: String },
      'members' => { conversion: :comma_separated }
    }.freeze

    @path = 'ltm/snatpool/'

    # @param [Hash] opts Options hash
    # @option opts [String] name Snatpool name
    # @option opts [Array<String>] members List of member node names
    def initialize(opts)
      @name = opts.fetch 'name'
      member_names = opts.fetch 'members'
      @members = member_names.map { |m| resolve_endpoint(m, Facility.name) }

      @ext = "~Common~#{@name}"
    end

    def to_json
      payload = {
        'name' => @name,
        'members' => @members
      }

      payload.to_json
    end

    def diff
      has_dif = false
      curr = get_server_config
      return true if curr.nil?

      member_names = @members.map { |m| "/Common/#{m}" }

      # Assert coverage of member names
      has_dif = !assert_coverage(curr['members'], member_names, 'members') || has_dif

      has_dif
    end

    def to_yaml
      yamlify(
        'name' => @name,
        'members' => @members
      )
    end

    attr_reader :members
  end
end
