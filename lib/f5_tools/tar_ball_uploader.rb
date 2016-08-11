require 'net/scp'
require 'rubygems/package'
require 'zlib'

module F5_Tools
  # Uploads tar archive of certs
  class TarBallUploader
    # Extracts the tar archive and returns a list of extracted files
    # @param [String] tar_file path to the tar archive
    # @return [Array<String>] returns an array of filenames of extracted certs
    def self.extract(tar_file)
      tar_extract = Gem::Package::TarReader.new(Zlib::GzipReader.open(tar_file))
      tar_extract.rewind # The extract has to be rewinded after every iteration
      files = []
      tar_extract.each do |entry|
        # Only care about .crt and .key files
        next unless entry.file? && (entry.full_name.end_with? *['.crt', '.key'])
        files << entry.full_name.split('/').last
        File.open(entry.full_name.split('/').last, 'w') do |file|
          file << entry.read
        end
      end
      tar_extract.close
      files
    end

    # Uploads a cert file to the F5 using SCP
    def self.upload(username, password, host, file)
      Net::SCP.start(host, username, password: password) do |scp|
        file_exp = File.expand_path("./#{file}")
        puts "[Cert Uploader] Uploading: #{file}"
        scp.upload! file_exp, "/var/tmp/#{file}", recursive: true
      end
    end

    # Extracts the tar file, uploads each cert/key to the F5, and registers each cert/key
    # @param [String] tar_file path to tar archive
    def self.upload_cert_tarball(tar_file, username, password, host)
      files = extract tar_file
      files.each { |f| upload username, password, host, f }
      files.each { |f| File.delete f }

      F5Wrapper.authenticate username, password, host
      files.each do |f|
        payload = {
          'command' => 'install',
          'name' => f.split('.').slice(0..-2).join('.'),
          'from-local-file' => "/var/tmp/#{f}"
        }.to_json
        if f.end_with? '.crt'
          path = 'sys/crypto/cert'
        elsif f.end_with? '.key'
          path = 'sys/crypto/key'
        end
        puts "[Cert Uploader] Registering: #{f}"
        F5Wrapper.post(path, payload)
      end
    end
  end
end
