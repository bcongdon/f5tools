require 'objects/f5_object'

module F5_Object
  # F5_Object to manage User accounts
  class User < F5_Object
    @path = 'auth/user/'

    # @param [Hash] opts Options ahsh
    # @option opts [String] name User name
    # @option opts [String] encrypted_password Hashed user password (SHA-512 $6$ hash)
    # @option opts [Array<Hash>] partition_access List of partition access hashes:
    #   ('name' => <partition>, 'role' => <role>) (Optional)
    def initialize(opts)
      @name = opts.fetch 'name'
      @encrypted_password = opts.fetch 'encrypted_password'
      @partition_access = opts.fetch 'partition_access', nil
      @ext = @name
    end

    def to_json
      payload = {
        'name' => @name,
        'encrypted-password' => @encrypted_password
      }
      payload['partitionAccess'] = @partition_access if @partition_access
      payload.to_json
    end

    def diff
      has_dif = false
      curr = get_server_config
      return true if curr.nil?
      has_dif = !assert_same(curr['encryptedPassword'], @encrypted_password, 'encrypted_password') || has_dif
      has_dif = !assert_same(curr['partitionAccess'], @partition_access, 'partition_access') || has_dif

      has_dif
    end
  end
end
