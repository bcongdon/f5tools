require 'fileutils'

module F5_Tools
  # Module for managing YAML file locations, as well as YAML edits
  module YAMLUtils
    FACILITY_PATH   = 'defs/facilities/~facility~/'.freeze
    FACILITIES_YAML = 'defs/facilities.yaml'.freeze
    FACILITY_VARS_YAML = 'defs/facilities/~facility~/_vars.yaml'.freeze
    FACILITY_ENDPOINTS_YAML = FACILITY_PATH + 'endpoints.yaml'

    NET_DEVICE_YAML = :net_device_yaml
    FACILITY_NET_DEVICE_YAML = FACILITY_PATH + 'net_devices/~device~.yaml'
    TEMPLATE_NET_DEVICE_YAML = 'defs/device_templates/~device~.yaml'.freeze

    GLOBAL_SEGMENTS_YAML = 'defs/segments.yaml'.freeze
    FACILITY_SEGMENTS_YAML = FACILITY_PATH + 'segments.yaml'

    PORT_SYMBOL_YAML = 'defs/port_symbols.yaml'.freeze
    DATA_GROUP_FOLDER = 'defs/data_groups/'.freeze

    NO_YAML = :no_yaml

    ROOT = :root

    # Insert F5_Object into correct YAML file for given facility/net_device
    # @param [F5_Object] obj the object to save. Needs to have YAML_LOC defined.
    def insert_object(obj, facility = nil, device = nil)
      Resolution.warn = false
      # Bail if class says it doesn't have a defined YAML location
      if obj.class.const_defined?('YAML_LOC') && obj.class::YAML_LOC == NO_YAML
        raise "Class '#{obj.class}'' does not have an editable YAML representation."
      elsif !obj.class.const_defined?('YAML_LOC')
        raise "Class '#{obj.class}' does not have a YAML file location defined."
      end

      puts "Saving #{obj.class} to YAML.".colorize(:green)
      payload = YAML.load(obj.to_yaml)
      path = object_yaml_path obj, facility, device

      modify_yaml(path) do |yaml_data|
        # Get YAML_KEY constant or infer YAML key from class name (i.e. Node -> nodes)
        yaml_key = class_yaml_key obj.class

        if yaml_key != ROOT
          # Create Array if doesn't exist
          yaml_data[yaml_key] = [] unless yaml_data[yaml_key]
          # Push the payload to yaml data
          yaml_data[yaml_key].push(payload)
        else
          yaml_data.merge!(payload)
        end
        yaml_data
      end
    end

    def class_yaml_key(cls)
      cls.const_defined?('YAML_KEY') ? cls::YAML_KEY : cls.to_s.split('::').last.downcase + 's'
    end

    def delete_named_object(cls, name = nil, facility = nil, device = nil)
      path = class_yaml_path cls, facility, device
      key = class_yaml_key cls
      modify_yaml path do |data|
        if key != ROOT
          raise "Need object name to delete a #{cls}" unless name
          data[key].reject! { |d| d['name'] == name } if data[key]
          data
        else
          data.delete cls.const_get 'YAML_ROOT_KEY'
          data
        end
      end
    end

    # Infer full YAML file path from Object constants and given facility / net_device name
    # @return [String] Returns full YAML path infered from object (and facility/device)
    def object_yaml_path(obj, facility = nil, device = nil)
      class_yaml_path obj.class, facility, device
    end

    def class_yaml_path(cls, facility = nil, device = nil)
      # Duplicate constant if it's a String
      path = cls::YAML_LOC.is_a?(String) ? cls::YAML_LOC.dup : cls::YAML_LOC

      construct_yaml_path(path, facility, device)
    end

    # Do facility / device substitutions on YAML path
    # @return [String] Returns constructed filepath
    def construct_yaml_path(path, facility = nil, device = nil)
      # Exception
      if path == NET_DEVICE_YAML
        device = "#{facility}/#{device}" if facility && !device.include?('/')
        construct_device_path device
      else
        path = path.dup

        raise 'Object needs facility name' if path.include?('~facility~') && facility.nil?
        raise 'Object needs device name' if path.include?('~device~') && device.nil?

        path.gsub!('~facility~', facility) if facility
        path.gsub!('~device~', device) if device
        path
      end
    end

    def needs_device?(path)
      path == NET_DEVICE_YAML || path.include?('~device~')
    end

    def needs_facility?(path)
      if path == NET_DEVICE_YAML
        false
      else
        path.include?('~facility~')
      end
    end

    # Infer from device name if device is a template, or facility specific device
    def construct_device_path(device)
      # Containing slash indicates facility specific YAML
      # => i.e. ord/front
      if device.include? '/'
        fac_name, dev_name = device.split('/')
        construct_yaml_path FACILITY_NET_DEVICE_YAML, fac_name, dev_name
      # Otherwise, must be template device
      else
        construct_yaml_path TEMPLATE_NET_DEVICE_YAML, nil, device
      end
    end

    # Load YAML file, yield the data (for modification) and save the changes
    # @yield [Hash] Gives YAML data as a hash
    def modify_yaml(yaml_file)
      # Load current YAML data, yield it, and save the result
      yaml = yield load_or_create_yaml(yaml_file)
      # Open YAML file and dump the (potentially) modified data
      File.open(yaml_file, 'w') { |f| f.write yaml.to_yaml }
    end

    def load_or_create_yaml(yaml_file)
      FileUtils.touch(yaml_file) unless File.exist? yaml_file
      YAML.load_file(yaml_file) || {}
    end
  end
end
