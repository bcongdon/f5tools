require 'objects/f5_object'
require 'resolv'

module F5_Object
  class Node < F5_Object
    include Assertion

    YAML_LOC = YAMLUtils::FACILITY_PATH + 'nodes.yaml'
    CREATION_INFO = {
      'host' => { class: String },
      'name' => { class: String, optional: true }
    }.freeze

    @path = 'ltm/node/'

    # @param [Hash] opts Options hash
    # @option opts [String] name Node name. If no addr, addr is resolved from 'name' as an fqdn
    # @option opts [String] addr Node address
    def initialize(opts)
      @opts = opts
      hostname = opts.fetch('host')
      @addr = Resolv.getaddress hostname
      @name = @opts.fetch 'name', hostname
      @ext  = "~Common~#{@name}"
    end

    def to_json
      {
        'name' => @name,
        'address' => @addr
      }.to_json
    end

    attr_reader :name

    def diff
      has_dif = false
      curr = get_server_config
      return true if curr.nil?

      has_dif = !assert_same(@addr, curr['address'], 'address') || has_dif

      has_dif
    end

    # Nodes cannot be modified programatically w/o delete + recreate
    # This introduces a variety of dependency issues that probably should not be automated
    def apply
      unless diff
        puts "#{pretty_name} Skipping because no diff." if @@debug
        return true
      end
      puts report_apply
      get_res = F5Wrapper.get(self.class.path + @ext, false)
      if get_res['code'] == 404
        # Do POST
        F5Wrapper.post(self.class.path, to_json)
      else
        puts "[Node:#{@name}] Node already exists, and cannot be modified by f5_tools.".colorize(:red)
        false
      end
    end

    def to_yaml
      yamlify(@opts)
    end
  end
end
