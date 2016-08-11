require 'objects/f5_object'

module F5_Object
  # Object to to manage VLANs on the F5.
  # Not completely implemented right now because it was difficult to see
  # how VLANs worked with interfaces using the F5 provided AMI I was
  # developing on.
  class VLAN < F5_Object
    @path = 'net/vlan/'

    YAML_LOC = YAMLUtils::NET_DEVICE_YAML

    CREATION_INFO = {
      'name' => { conversion: String },
      'tag' => { conversion: String, optional: true },
      'segment' => { conversion: String, optional: true }
    }.freeze

    # @option opts [String] name VLAN name
    # @option opts [String] tag VLAN tag (Optional)
    # @option opts [String] segment segment to bind VLAN to (Optional)
    def initialize(opts)
      @name = opts.fetch 'name'
      @tag  = opts.fetch('tag', nil).to_s
      @segment = opts.fetch 'segment', nil

      @ext = "~Common~#{@name}"
    end

    attr_reader :name
    attr_reader :segment

    def to_json
      payload = {
        'name' => @name
      }
      payload['tag'] = @tag if @tag

      payload.to_json
    end

    def diff
      has_dif = false
      curr = get_server_config
      return true if curr.nil?

      has_dif = !assert_same(curr['tag'].to_s, @tag, 'tag') || has_dif if @tag

      has_dif
    end

    def to_yaml
      yamlify(
        'name' => @name,
        'tag' => @tag,
        'segment' => segment
      )
    end
  end
end
