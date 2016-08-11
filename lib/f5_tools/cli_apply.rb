require 'f5_tools'

require 'utils/cli_utils'

require 'highline/import'
require 'thor'
require 'pp'

module F5_Tools::CLI
  class Apply < Thor
    include F5_Tools::Resolution
    include F5_Tools::Assertion
    include F5_Tools::YAMLUtils
    include CLI_Utils

    class_option :username, aliases: '-u'
    class_option :password, aliases: '-p'
    class_option :host, aliases: '-h'
    class_option :objtype, aliases: '-t'
    class_option :objname, aliases: '-n'

    desc 'device <facility> <device>', 'Applies the current defs to configuration on server for given device'
    def device(fac_name, device)
      authenticate_with options, facility: fac_name, device: device

      facility = init_facility fac_name, device

      puts "F5Tools - Applying: #{fac_name}/#{device}".colorize(:white).on_black
      # Apply on all specified objects
      res = facility.apply device, options[:objtype], options[:objname] # Applies recursively
      color = res ? :green : :red
      str = 'Apply ' + (res ? 'complete' : 'failed')
      puts str.colorize(color).on_black
    end

    desc 'ipsec <facility> <device>', 'Applies ipsec tunnels'
    def ipsec(fac_name, device)
      authenticate_with options, facility: fac_name, device: device

      f = init_facility fac_name, device
      n = f.net_devices[device]

      n.load_ipsecs { |name| r = ask("Pre-shared key for tunnel to '#{name}': ", echo: false); puts; r }
      ipsecs = n.ipsecs

      puts 'Applying IPSec(s)'.colorize(:white).on_black
      ipsecs.each { |x| x.apply true }
      puts 'Apply complete'.colorize(:green).on_black
    end

    desc 'cert_tgz /path/to/file.tgz', 'Uploads a key/cert tar bundle and registers those keys/certs with the F5'
    def cert_tgz(tar_file)
      authenticate_with options
      path = File.expand_path tar_file

      # Upload the tar file
      TarBallUploader.upload_cert_tarball path, opts[:user], opts[:pass], opts[:host]
    end

    desc 'user <facility> <device>', 'Applies user account settings to server'
    def user(fac_name, device)
      authenticate_with options, facility: fac_name, device: device
      init_facility fac_name, device

      yaml = load_or_create_yaml 'defs/users.yaml'
      users = yaml['users'].map { |d| User.new d }
      users = users.select { |d| d.name == options[:objname] } if options[:objname]

      puts 'Applying User(s)'.colorize(:white).on_black
      users.each(&:apply)
    end
  end
end
