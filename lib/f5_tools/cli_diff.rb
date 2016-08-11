require 'f5_tools'

require 'utils/cli_utils'

require 'highline/import'
require 'thor'
require 'pp'

module F5_Tools::CLI
  class Diff < Thor
    include F5_Tools::Resolution
    include F5_Tools::Assertion
    include F5_Tools::YAMLUtils
    include CLI_Utils

    class_option :username, aliases: '-u'
    class_option :password, aliases: '-p'
    class_option :host, aliases: '-h'
    class_option :objtype, aliases: '-t'
    class_option :objname, aliases: '-n'

    desc 'device <facility> <device>', 'Diffs the current defs against configuration on server.'
    def device(fac_name, device)
      authenticate_with options, facility: fac_name, device: device

      facility = init_facility fac_name, device

      puts "F5Tools - Diffing: #{fac_name}/#{device}".colorize(:white).on_black
      # Diff all specified objects
      res = !facility.diff(device, options[:objtype], options[:objname]) # Diffs recursively
      str = res ? 'Diff complete' : 'Diffs exist'
      color = res ? :green : :red
      puts str.colorize(color).on_black
    end

    desc 'cert_tgz /path/to/file.tgz', 'Uploads a key/cert tar bundle and registers those keys/certs with the F5'
    def cert_tgz(tar_file)
      authenticate_with options
      path = File.expand_path tar_file

      # Upload the tar file
      TarBallUploader.upload_cert_tarball path, opts[:user], opts[:pass], opts[:host]
    end

    desc 'user <facility> <device>', 'User account operations'
    def user(fac_name, device)
      authenticate_with options, facility: fac_name, device: device
      init_facility fac_name, device

      yaml = load_or_create_yaml 'defs/users.yaml'
      users = yaml['users'].map { |d| User.new d }
      users = users.select { |d| d.name == options[:objname] } if options[:objname]

      puts 'Diffing User(s)'.colorize(:white).on_black
      users.each(&:diff)
      assert_coverage User.get_global_names, users.map(&:objname), 'name', false, 'User'
    end
  end
end
