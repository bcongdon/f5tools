require 'f5_tools'

module F5_Tools
  module ObjectUtils
    def self.defined_objects
      # Only select direct descendents of F5_Object
      ObjectSpace.each_object(Class).map { |d| d.to_s.split('::') }.select { |d| d.first == 'F5_Object' }.map(&:last)
    end
  end
end
