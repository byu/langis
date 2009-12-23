module Langis
  module Middleware

    ##
    # Middleware class that modifies the Rackish input environment by
    # transforming a specific value in the environment before passing
    # it along to the rest of the Rackish application chain.
    #
    # Some useful applications of this transform:
    # * Serialization or Deserialization of input data.
    # * Filter or modify the message; to explicitly whitelist the list of
    #   properties in the message that may be exposed to a service or
    #   third party.
    class EnvFieldTransform

      ##
      #
      # @param app The Rackish application for which this instance is acting as
      #   middleware.
      # @option options [String] :key (Langis::MESSAGE_KEY) The hash key
      #   of the Rackish environment whose value is the object that we
      #   want to transform (transformation object).
      # @option options [Symbol,String] :to_method (:to_json) The
      #   transformation object that will respond to the invokation of this
      #   method name. The return value of that method will replace the
      #   original transformation object in the Rackish environment as
      #   the environment is passed on to the rest of the Rackish app chain.
      # @option options [Array,Object] :to_args ([]) The parameter or
      #   list of parameters to pass to the transformation method.
      def initialize(app, options={})
        @app = app
        @to_method = options[:to_method] || :to_json
        @to_args = options[:to_args] || []
        @to_args = [@to_args] unless @to_args.is_a? Array
        @key = options[:key] || MESSAGE_KEY
      end

      ##
      # Executes the object transformation, and invokes the rest of the
      # Rackish app chain.
      #
      # @param [Hash] env The Rackish input environment.
      # @return [Array<Integer,Hash,#each>] The return of the proxied Rackish
      #   application chain.
      def call(env)
        item = env[@key].send @to_method, *@to_args
        return @app.call env.merge({ @key => item })
      end
    end

    ##
    # Middleware to only continue execution of the Rackish application chain
    # if the input environment's Langis::MESSAGE_TYPE_KEY is set to a value
    # that has been whitelisted.
    class MessageTypeFilter

      ##
      #
      # @param app The Rackish application chain to front.
      # @param [#to_s] ... The whitelist of message types to allow pass.
      def initialize(app, *args)
        @app = app
        @message_types = args.map { |message_type| message_type.to_s }
      end

      ##
      # Executes the filtering, and invokes the rest of the Rackish app chain
      # if the message type is allowed.
      # 
      # @param [Hash] env The Rackish input environment.
      # @return [Array<Integer,Hash,#each>] The return of the proxied Rackish
      #   application chain, or an OK with the filter reason.
      # @see Langis::X_FILTERED_BY
      # @see Langis::X_FILTERED_TYPE
      def call(env)
        if @message_types.include? env[MESSAGE_TYPE_KEY]
          return @app.call(env)
        else
          return [
            OK,
            {
              X_FILTERED_BY => self.class.to_s,
              X_FILTERED_TYPE => env[MESSAGE_TYPE_KEY].class
            },
            ['']]
        end
      end
    end
  end
end
