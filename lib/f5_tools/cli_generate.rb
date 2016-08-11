require 'f5_tools'

require 'utils/cli_utils'

require 'highline/import'
require 'thor'
require 'pp'

module F5_Tools::CLI
  class Generate < Thor
    include F5_Tools::Resolution
    include F5_Tools::Assertion
    include F5_Tools::YAMLUtils
    include CLI_Utils

    class_option :username, aliases: '-u'
    class_option :password, aliases: '-p'
    class_option :host, aliases: '-h'

    option :save, type: :boolean
    desc 'device <device_template> <facility>', 'Renders a device template with facility variables'
    def render(template_name, fac_name)
      rendered_template = F5_Tools::DeviceTemplateRenderer.render_in_facility template_name, fac_name
      if options[:save]
        path = construct_yaml_path NET_DEVICE_YAML, fac_name, template_name
        File.open(path, 'w') { |file| file.write rendered_template }
        puts "Saved rendered template for #{fac_name} #{template_name}".colorize(:green)
      else
        puts rendered_template
      end
    end

    option :objtype, aliases: '-t'
    option :objname, aliases: '-n'
    desc 'json <facility> <device>', 'Shows json \'rendered\' representation of selected object(s)'
    def json(fac_name, device)
      f = init_facility fac_name, device
      n = f.net_devices[device]
      objs = n.get_object_jsons(options[:objtype], options[:objname]).map do |type, arr|
        puts type.colorize(:white).on_black
        arr.map do |obj|
          begin
            puts obj.respond_to?(:to_json) ? JSON.pretty_generate(JSON.parse(obj.to_json)) : ''
          rescue NotImplementedError
            puts 'Caught NotImplementedError'
          end
        end
      end
    end
  end
end
