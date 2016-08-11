require 'objects/f5_object'

module F5_Object
  # Not fully implemented. Only being used for global name diffing
  class PacketFilter < F5_Object
    @path = 'net/packet-filter/'
  end
end
