require 'objects/f5_object'

module F5_Object
  # Not fully implemented. Only being used for global name diffing
  class SnatTranslation < F5_Object
    @path = 'ltm/snat-translation/'

    def initialize(opts)
      @name = opts.fetch 'name'

      @ext = "~Common~#{@name}"
    end

    # To supress warning. Does nothing.
    def diff
      false
    end
  end
end
