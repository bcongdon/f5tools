require 'objects/f5_object'

module F5_Object
  # F5_Object to manage iRules
  class Rule < F5_Object
    include Assertion

    @path = 'ltm/rule/'

    # @param [Hash] opts Options hash
    # @option opts [String] name Rule name
    # @option opts [String] rule TCL rule source
    def initialize(opts)
      @name = opts.fetch 'name'
      @rule = opts.fetch 'rule'

      @ext  = "~Common~#{@name}"
    end

    def to_json
      payload = {
        'apiAnonymous' => @rule,
        'name' => @name
      }.to_json
    end

    def diff
      has_dif = false
      curr = get_server_config
      return true if curr.nil?

      # Remove leading / trailing whitespace before comparing iRule text
      has_dif = !assert_same(curr['apiAnonymous'].strip, @rule.strip, 'rule', diff_output = true)

      has_dif
    end
  end
end
