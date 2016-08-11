require 'objects/f5_object.rb'

module F5_Object
  # Abstract F5_Object to maintain the high level segment concept
  class Segment < F5_Object
    # @param [Hash] opts Options hash
    # @option opts [String] name Segment name
    # @option opts [String] cidr Segment CIDR block
    # @option opts [String] size CIDR block size (Optional, can be passed in cidr)
    def initialize(opts)
      name = opts.fetch 'name'
      cidr = opts.fetch 'cidr'
      size = opts.fetch 'size', nil
      # Support legacy inits
      cidr = cidr + '/' + size.to_i unless size.nil?
      @name = name
      @cidr = NetAddr::CIDR.create(cidr)
    end

    # @return Returns the first IP *after* this segment
    def next_addr
      @cidr.next_ip
    end

    # @return Returns the first IP addr in this segment
    def first
      @cidr.ip
    end

    # @return Returns the segment netmask
    def mask
      @cidr.wildcard_mask
    end

    def to_s
      @cidr.to_s
    end

    attr_reader :name
    attr_reader :cidr
  end
end
