require 'diffy'

module F5_Tools
  # Utilities for assertions used for {F5_Object::F5_Object#diff}
  module Assertion
    # Does a simple '==' check, pretty-prints + returns the result if check is false
    # @param [String] found the value to test
    # @param [String] exp the expected value
    # @param [String] key the 'type' of check being performed (used for result pretty-printing)
    # @return [bool] Returns the result of the check
    def assert_same(found, exp, key, diff_output = false)
      return true if found == exp

      if diff_output
        puts "#{pretty_name(key).colorize(:blue)} Diff found:"
        puts Diffy::Diff.new(found, exp, context: 5).to_s(:color)
      else
        puts "#{pretty_name(key).colorize(:blue)} Found '#{found}' but expected '#{exp}'"
      end

      false
    end

    # Utility function for asserting that an array has contains an object. Then pretty prints (if false)
    # and returns the result
    # @param [String] arr the array to test
    # @param [String] obj the value that is expected to be included in the array
    # @param [String] key the 'type' of check being performed (used for result pretty-printing)
    # @return [bool] Returns the result of the check
    def assert_contains(arr, obj, key)
      if arr.nil? || !arr.include?(obj)
        puts "#{pretty_name(key).colorize(:blue)} Couldn't find '#{obj}' in '#{key}'"
        return false
      else
        return true
      end
    end

    # Utility function for asserting that two hashes are equivalent.
    # Pretty prints any discrepancies. Returns the value of the check
    # @param [String] serv the hash found on the server
    # @param [String] loc the authoratative hash obtained from local config
    # @param [String] key the 'type' of check being performed (used for result pretty-printing)
    # @param [String] common Allows ignoring the partition prefix '/Common/' in value checks
    # @return [bool] Returns the result of the check
    def assert_coverage(serv, loc, key, common = false, pretty_str = nil)
      pretty_name_str = pretty_str || pretty_name(key)
      if serv.nil? && !loc.empty?
        puts "#{pretty_name(key).red}} '#{key}' is empty"
        return true
      end
      mine = loc - serv
      mine = mine.each do |x|
        next false if (serv.include?("/Common/#{x}") || serv.map { |a| "/Common/#{a}" }.include?(x)) && common
        puts "#{pretty_name_str.colorize(:blue)} '#{x}' not found on the server"
        true
      end

      theirs = serv - loc
      theirs = theirs.each do |x|
        next false if (loc.include?("/Common/#{x}") || loc.map { |a| "/Common/#{a}" }.include?(x)) && common
        puts "#{pretty_name_str.colorize(:blue)} '#{x}' not found in local config"
      end
      mine.empty? && theirs.empty?
    end
  end
end
