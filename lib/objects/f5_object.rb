require 'colorize'
require 'f5_tools'
require 'json'

module F5_Object
  # @abstract Subclass and override {#diff}, {#to_json}, and optionally {#apply}
  class F5_Object
    include F5_Tools
    include Resolution
    include Assertion
    include YAMLUtils

    # Barely used, currently only to enable printing "OK" diff messages
    @@debug = false

    @path = nil
    class << self
      # Base API endpoint path of the F5_Object
      # @return [String] Default nil path, must be overridden in subclasses if ever used
      attr_reader :path
    end

    @prefix = nil
    class << self
      # Acceptable prefixes for this type of F5_Object. Can be a String, or Array of prefixes
      # @return [String, Array] Default nil path, must be overridden in subclasses if ever used
      attr_reader :prefix
    end

    attr_accessor :name

    # Non-'abstract' F5_Objects should be able to output a JSON payload
    # @raise [NotImplementedError] needs to be overwritten
    def to_json
      puts "#{self.class} doesn't know how to JSONify itself."
      raise NotImplementedError.new
    end

    # JSON object used for modifications (sometimes different than creation json)
    def modify_safe_json
      to_json
    end

    # Takes current settings in the F5 object and overwrites the existing settings on F5
    # @param [bool] force Unless true, will bail on application if there is no diff
    def apply(force = false)
      # Need a path to assemble the full request URL
      raise NotImplementedError, 'No path found in object.' unless defined? self.class.path.nil?

      # Only apply if the object has a diff - for safety and [sometimes] fewer total requests
      if !diff && !force
        puts("#{pretty_name} Skipping because no diff.") if @@debug
        return true
      end

      puts report_apply

      # Special_ext needed for classes like Profile
      special_ext = defined?(@spec_ext) && !@spec_ext.nil? ? @spec_ext : ''

      # Do a get to see if the object already exists on the server
      get_res = F5Wrapper.get(self.class.path + special_ext + @ext, false)
      res = if get_res['code'] == 404
              # Do POST - creating an object that doesn't exist
              F5Wrapper.post(self.class.path + special_ext, to_json)
            else
              # Do PUT - modifying an object that already exists
              F5Wrapper.put(self.class.path + special_ext + @ext, modify_safe_json)
            end

      # Return whether or not a valid object response has been received
      # (Object response indicates successfully create/modify)
      res.key?('kind') ? res : false
    end

    # Pretty console print for applying
    def report_apply
      pretty_name.to_s + ' Applying...'.colorize(:green)
    end

    # Returns a human-readable heirarchy of the current F5_Object instance.
    # (Strips out all the module / superclass info)
    def pretty_name(key = nil)
      return "[#{self.class.to_s.split('::').last}:#{@name}]" if key.nil?
      # @name = "" unless defined? @name
      "[#{self.class.to_s.split('::').last}:#{@name}:#{key}]"
    end

    # Returns true iff there is a diff, else false
    # Must be overridden in all subclasses that need to be able to diff
    def diff
      puts "#{self.class.to_s.split('::').last} doesn't know how to diff itself."
    end

    # Returns names of all objects of the current type
    # i.e. if the instance is a Profile, returns names of all Profiles on the server
    def self.get_global_names
      return get_spec_global_names if defined? @spec_types
      raise NotImplementedError, 'No path found in object.' if path.nil?

      get_res = F5Wrapper.get(path, warn = false)
      if get_res['code'] == 404
        puts "#{pretty_name.red} Something went wrong."
        return nil
      else
        return get_res['items'].map { |x| x['name'] }.select { |x| !x.nil? } if get_res['items']
        []
      end
    end

    # Have to get names for each type of 'special' object - different endpoints for each
    def self.get_spec_global_names
      names = []
      @spec_types.each do |type|
        get_res = F5Wrapper.get("#{path}#{type}", warn = false)
        if get_res['code'] == 404
          puts "#{pretty_name.red} Something went wrong."
          return nil
        elsif get_res['items']
          names += get_res['items'].map { |x| x['name'] }.select { |x| !x.nil? }
        end
      end
      # By convention, user-definied profile names start with uppercase, so ignore all the other sys default profiles
      names.select { |x| x[0] == x[0].upcase }
    end

    # Does a GET for the object instance to get current config.
    # Catches 404s and other errors which would signal a diff, or auth error
    # @param [String] path Base path. Defaults to .path
    # @param [String] ext Extension from the base path to reference the specific object
    # @param [String] object_name Used for pretty-printing errors
    # @return [Hash] Returns a hash of the current F5 Object on the server
    def get_server_config(path = self.class.path, ext = @ext, object_name = 'Object')
      raise NotImplementedError, 'No path found in object.' if path.nil?

      # Special_ext needed for classes like Profile
      special_ext = defined?(@spec_ext) && !@spec_ext.nil? ? @spec_ext : ''
      get_res = F5Wrapper.get(path + special_ext + ext, warn = false)
      if get_res['code'] == 404
        puts "#{pretty_name.red} #{object_name} doesn't exist on server"
        return nil
      elsif get_res['code'] && get_res['code'] != 200
        puts "#{pretty_name.red.on_black} Something went wrong: #{get_res['message']}"
        return nil
      else
        get_res
      end
    end

    # Used to strip localhost prefixes in cases when F5 self_link contains these types of references
    # @return [String] uri with `https://localhost/mgmt/tm` removed
    def strip_localhost_path(uri)
      uri['https://localhost/mgmt/tm/'.length..-1]
    end

    # Convenience method. Just prints out {#to_json}
    def to_s
      to_json
    end

    # Removes YAML header
    def yamlify(payload)
      payload.to_yaml.gsub("---\n", '')
    end
  end
end
