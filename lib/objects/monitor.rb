require 'objects/f5_object'

module F5_Object
  class HTTPMonitor < F5_Object
    include Assertion

    @path = 'ltm/monitor/'

    VALID_TYPES = %w(http https).freeze

    YAML_LOC = 'defs/monitors.yaml'.freeze
    YAML_KEY = 'monitors'.freeze

    CREATION_INFO = {
      'name' => { conversion: String },
      'send' => { conversion: String },
      'recv' => { conversion: String },
      'type' => { conversion: String }
    }.freeze

    @spec_types = VALID_TYPES

    # @param [Hash] opts Options hash
    # @option opts [String] name Monitor name
    # @option opts [String] send
    # @option opts [String] recv
    # @option opts [String] type Monitor type. See {VALID_TYPES}
    def initialize(opts)
      @name = opts.fetch 'name'

      # Send / receive commands
      @send = opts.fetch 'send'
      @recv = opts.fetch 'recv'

      type = opts.fetch 'type', 'http'
      raise "Unsupported type: #{type}" unless %w(http https).include? type
      @type = "/Common/#{type}" unless type.start_with? '/Common/'

      @spec_ext = type + '/'
      @ext = "~Common~#{@name}"
    end

    def to_json
      payload = {
        'name' => @name,
        'defaultsFrom' => @type,
        'destination' => '*:*',
        'send' => @send.to_s,
        'recv' => @recv.to_s,

        # Hard coded defaults
        'timeUntilUp' => 0,
        'interval' => 5,
        'timeout' => 16
      }.to_json
    end

    def modify_safe_json
      payload = JSON.parse(to_json)

      # "defaultsFrom" cannot be passed in a PUT payload, so delete that k/v pair
      payload.delete 'defaultsFrom'
      puts "#{pretty_name} NOTE: HTTPMonitor #apply will not change 'defaultsFrom'"
      payload.to_json
    end

    def diff
      has_diff = false
      curr = get_server_config
      return true if curr.nil?

      payload = JSON.parse(to_json)
      payload.delete 'name'

      payload.each do |key, val|
        has_diff = !assert_same(curr[key], val, key) || has_diff
      end

      has_diff
    end

    def to_yaml
      yamlify(
        'name' => @name,
        'send' => @send,
        'recv' => @recv,
        'type' => @type
      )
    end
  end
end
