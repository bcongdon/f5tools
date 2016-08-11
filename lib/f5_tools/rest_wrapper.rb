require 'colorize'
require 'json'
require 'net/http'
require 'openssl'
require 'resolv'

module F5_Tools
  # Simple F5 iControl REST API wrapper
  class F5Wrapper
    # Authentication state
    @@authenticated = false

    # Authenticates the REST Wrapper
    #
    # @param [String] user the username to be used on the F5
    # @param [String] pass the password to be used on the F5
    # @param [String] host the hostname of the F5
    def self.authenticate(user, pass, host)
      @@username = user
      @@password = pass

      # Gracefully handle failing to connect to device
      begin
        Resolv.getaddress host
      rescue Resolv::ResolvError
        throw "Could not connect to device at: #{host}"
      end

      @@host = host
      @@host = 'https://' + @@host unless @@host.start_with? *['http://', 'https://']
      @@authenticated = true
    end

    # Returns current authentication status
    #
    # @raise [RuntimeError] raises exception when called and wrapper is unauthenticated
    # @return [bool] returns current authentication state
    def self.check_auth
      unless @@authenticated
        raise 'REST Wrapper is unauthenticated! Cannot serve request.'
      end
      @@authenticated
    end

    # Runs an authenticated request and loosely handles warnings
    #
    # @param [Net::HTTPGenericRequest] req Request object to be used
    # @param [URI] uri URI to be used to make the request
    # @param [bool] warn If true, will print error description on failure to execute request
    # @return [Hash] returns the parsed body of the request response
    def self.do_request(req, uri, warn)
      # Authorize the reqest
      req.basic_auth @@username, @@password
      # Use insecure mode with HTTPS (per F5 website)
      res = Net::HTTP.start(uri.hostname, uri.port,
                            use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
        http.request(req)
      end

      if !res.is_a?(Net::HTTPOK) && warn
        case res.code
        when '400'
          STDERR.puts "[Error: 400] Resource error: #{JSON.parse(res.body)['message']}".colorize(:red).on_black
        when '401'
          STDERR.puts '[Error: 401] '.red + "Not authorized to access resource: #{uri}".colorize(:red).on_black
        when '404'
          STDERR.puts '[Error: 404] '.red + "Resource not found: #{uri}; #{res.body}".colorize(:red).on_black
        else
          STDERR.puts "[Error: #{res.code}] ".red + "An error ocurred: #{res.body}".colorize(:red).on_black
        end
      end

      # Return as parsed JSON
      JSON.parse(res.body)
    end

    # GET Request wrapper
    #
    # @param [String] path Extension from the base F5 path to be requested
    # @param [bool] warn See {F5Wrapper.do_request}
    def self.get(path, warn = true)
      F5Wrapper.check_auth
      uri_str = "#{@@host}/mgmt/tm/#{path}"
      uri = URI(uri_str)
      req = Net::HTTP::Get.new uri

      F5Wrapper.do_request(req, uri, warn)
    end

    # PUT Request wrapper
    #
    # @param [String] path Extension from the base F5 path to be requested
    # @param [bool] warn See {F5Wrapper.do_request}
    def self.put(path, payload, warn = true)
      F5Wrapper.check_auth

      uri_str = "#{@@host}/mgmt/tm/#{path}"
      uri = URI(uri_str)
      req = Net::HTTP::Put.new uri
      req.content_type = 'application/json'
      req.body = payload

      F5Wrapper.do_request(req, uri, warn)
    end

    # POST Request wrapper
    #
    # @param [String] path Extension from the base F5 path to be requested
    # @param [bool] warn See {F5Wrapper.do_request}
    def self.post(path, payload, warn = true)
      F5Wrapper.check_auth

      uri_str = "#{@@host}/mgmt/tm/#{path}"
      uri = URI(uri_str)
      req = Net::HTTP::Post.new uri
      req.content_type = 'application/json'
      req.body = payload

      F5Wrapper.do_request(req, uri, warn)
    end
  end
end
