require 'liquid'
require 'erb'

module F5_Tools
  class ERBRenderer < OpenStruct
    def render(template)
      ERB.new(template).result(binding)
    end
  end

  class DeviceTemplateRenderer
    class << self
      include YAMLUtils
    end

    def self.render_in_facility(template_name, facility_name)
      template_file = File.read "defs/device_templates/#{template_name}.yaml"
      facility_vars = load_or_create_yaml("defs/facilities/#{facility_name}/_vars.yaml")
      DeviceTemplateRenderer.render template_file, facility_vars
    end

    def self.render(template, tags_dict)
      # Create template
      liquid_template = Liquid::Template.parse template, error_mode: :strict
      # Render with liquid
      liquid_rendered = liquid_template.render(tags_dict)
      # Render with ERB
      completely_rendered = ERBRenderer.new(tags_dict).render(liquid_rendered)

      # Put rendered string through YAML parser to ensure correct formatting
      yaml_hash = YAML.load completely_rendered
      yaml_hash.to_yaml
    end
  end
end
