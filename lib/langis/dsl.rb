module Langis

  ##
  # Module that implements the Domain Specific Language which is used
  # to define Langis publish-subscribe routes.
  module Dsl

    ##
    # Error that is raised when there is an error in the definition of
    # a set of routes in the Dsl.
    class PipingConfigError < LangisError
    end

    ##
    # Method to parse the configuration of the routes.
    #
    #   config = Langis::Dsl.langis_plumbing do
    #     intake :inbound_name do
    #       flow_to :sink_name, :when => [:message_type1, :message_type2]
    #       flow_to :catch_all
    #     end
    #     intake :inbound_name do
    #       # NOTE that we have a second intake block with the same
    #       # :inbound_name name. The configuration in this block
    #       # will be merged with the previously declared block.
    #       # NOTE that the above :catch_all flow to sink can be overwritten
    #       # if we declare a `flow_to :catch_all, :when => [...]`. The
    #       # catch all will be restricted to the types declared in this
    #       # second flow_to.
    #       # NOTE that if we add a `flow_to :sink_name, :when => :type_3`,
    #       # it will add :type_3 to the list of message types already
    #       # declared in the prior block.
    #     end
    #     for_sink :sink_name do
    #       use SinkSpecificMiddlewareApp, :argument1, :argument2
    #       run MyRealApp.new(:argument1, :argument2)
    #     end
    #     for_sink :catch_all do
    #       run lambda { |env| puts Rails.logger.info(env.inspect) }
    #     end
    #     check_valve do
    #       use GlobalMiddlewareApp, :argument1, :argument2
    #     end
    #   end
    #   engine = Langis::Engine::EventMachineEngine.new config.build_pipes
    #   engine.pump MyMessage.new(:someinfo), :inbound_name
    #
    # @see RackishConfig
    # @param &block for the dsl configuration
    # @return [PipesConfig] the parsed configuration of the defined routes.
    def langis_plumbing(&block)
      config = PipesConfig.new
      Blockenspiel.invoke block, config
      return config
    end
    module_function :langis_plumbing

    ##
    # This represents the configuration of the overall Langis piping.
    # It is the configuration of the message intakes and their corresponding
    # Rackish applications.
    #
    # @see Langis::Dsl#langis_plumbing
    class PipesConfig
      include Blockenspiel::DSL

      ##
      #
      def initialize
        @intakes = {}
        @sinks = {}
        @check_valve = nil
      end

      ##
      # Dsl only method that parses a sub-block that defines an "intake".
      # An intake is the "queue" name that a message is sent to, and whose
      # defined "sinks" (application stacks) are executed in turn.
      #
      # @param [#to_s] name The name of the intake to define.
      # @param [#to_s] *args Additional named aliases of this intake.
      # @param [Block] &block The dsl configuration block for this intake.
      # @return [IntakeConfig] The configuration of this intake block.
      def intake(name, *args, &block)
        # We require at least one intake to be defined here, and merge
        # it into a list where other intake names have been defined.
        intake_names = args.clone
        intake_names.unshift name
        intake_names.map! { |n| n.to_s }

        # Here we launch the blockenspiel dsl processing for the intake block.
        config = IntakeConfig.new
        Blockenspiel.invoke block, config
        sink_type_links = config.sink_type_links

        # Iterate over the returned pipes, then only create intakes that have
        # actual sinks. We don't want to have intakes without sinks.
        # This also is set up so that we can use multiple intake dsl blocks
        # to define a single intake (i.e.- intakes with identical names
        # are only thought of as a single intake.)
        sink_type_links.each do |sink_name, message_types|
          intake_names.each do |intake_name|
            @intakes[intake_name] ||= {}
            @intakes[intake_name][sink_name] ||= Set.new
            @intakes[intake_name][sink_name].merge message_types
          end
        end
      end

      ##
      # Dsl only method to define a "sink", a Rackish application stack.
      # Subsequent sinks of the same name will overwrite the configuration
      # of a previously defined sink of that name.
      #
      # @param [#to_s] name The name of the sink to define.
      # @param [Block] &block The dsl configuration block for this sink.
      # @return [RackishConfig] The Rackish application stack for this sink.
      def for_sink(name, &block)
        config = RackishConfig.new
        Blockenspiel.invoke block, config 
        @sinks[name.to_s] = config
      end

      ##
      # Dsl only method to define a Rackish application stack that is
      # prepended to all sinks defined in the Langis config. This is
      # so one can define a global intercept patch for functionality like
      # global custom error handling. Note that one SHOULD only declare
      # `use Middleware` type statements since this stack will be prepended
      # to the other sinks. A `run` declaration in here will
      # terminate the execution, or even more likely fail to wire up correctly.
      #
      # @param [#to_s] name The name of the sink to define.
      # @param [Block] &block The dsl configuration block for this sink.
      # @return [RackishConfig] The Rackish application stack.
      def check_valve(&block)
        config = RackishConfig.new
        Blockenspiel.invoke block, config 
        @check_valve = config
      end

      dsl_methods false

      ##
      # Creates the sinks (application stacks) and references them in their
      # assigned intakes. A create sink can be referenced by multiple intakes.
      #
      # @return [{String => Array<#call>}] The intake name to list of
      #   created sinks.
      # @raise [PipingConfigError] Error raised when an intake references
      #   a non-existent sink; we are unable to wire up an app.
      def build_pipes
        # Build the main sinks, which may be added to the end of other
        # defined middleware.
        built_sinks = {}
        @sinks.each do |key, value|
          built_sinks[key] = value.to_app
        end

        # Full pipes is the final return hash to the caller. Its keys are the
        # intake names, and its values are Arrays of the sinks. Each sink
        # is a Rackish application stack.
        full_pipes = {}
        @intakes.each do |intake_name, sink_type_links|
          # Right now, each intake's value is a list of pairs. Each
          # pair is a sink name and the set of message types it should watch
          # for. Empty sets mean to do a catch all.
          sink_type_links.each do |sink_name, message_types|
            built_sink = built_sinks[sink_name]
            # We want to confirm that the sink the intake is referencing
            # actually exists.
            unless built_sink
              raise PipingConfigError.new "Sink not found: #{sink_name}"
            end

            # If any message type was defined to filter in the intaked block,
            # then we want to create a middleware to filter out all messages
            # whose type is not in that list. Otherwise we'll just flow
            # all messages to this defined sink.
            if message_types.empty?
              half_pipe = built_sink
            else
              half_pipe = ::Langis::Middleware::MessageTypeFilter.new(
                built_sink, *message_types)
            end

            # If we have a check_valve defined in the configuration, then
            # we want to prepend it to the sink.
            if @check_valve
              full_pipe = @check_valve.to_app half_pipe
            else
              full_pipe = half_pipe
            end

            # Now add the wired up sink to the list of sinks to be handled
            # by given intake.
            full_pipes[intake_name] ||= []
            full_pipes[intake_name] << full_pipe
          end
        end
        return full_pipes
      end
    end

    ##
    # Dsl config class used to define an intake.
    #
    # @see Langis::Dsl#langis_plumbing
    class IntakeConfig
      include Blockenspiel::DSL

      dsl_methods false

      ##
      # Returns the intake's configuration mapping between its sinks (names)
      # and the list of types to filter for.
      #
      # @return [Hash{String => Set<String>}] The sink name to the set of
      #   message types to filter for.
      attr_reader :sink_type_links

      ##
      #
      def initialize
        @sink_type_links = {}
      end

      dsl_methods true

      ##
      # Dsl only method to define which sinks to propagate a message to.
      #
      # @overload flow_to(...)
      #   Flow all messages for the intake to the given sink names.
      #   @param [Array<#to_s>] ... The list of sink names to push messages to.
      # @overload flow_to(..., options={})
      #   Flow all messages for the intake to the given sink names, but
      #     may be restricted by type if that option is set.
      #   @param [Array<#to_s>] ... The list of sink names to push messages to.
      #   @option options [Array<#to_s>] :when ([]) The list of message types
      #     that should be sent to the sink, all unlisted types are filtered
      #     out. If a sink has zero listed types at the end of the Dsl config,
      #     then ALL messages will be sent to that sink.
      def flow_to(*args)
        # Check to see if we have an options hash. Properly pull out the
        # options, and then make the list of sinks to push to.
        case args[-1]
        when Hash
          options = args[-1]
          sink_names = args[0...-1].map! { |name| name.to_s }
        else
          options = {}
          sink_names = args.clone.map! { |name| name.to_s }
        end

        # Coerce the message types to handle into an Array of strings
        case options[:when]
        when Array
          message_types = options[:when].map { |item| item.to_s }
        when nil
          # For the nil case, we have an empty array.
          # The build_pipes method will interpret a sink with an empty set
          # of types to actually handle all types.
          message_types = []
        else
          message_types = [ options[:when].to_s ]
        end

        # We add the types to a Set, one set per sink name. This is for the
        # multiple intake definitions.
        sink_names.each do |name|
          @sink_type_links[name] ||= Set.new
          @sink_type_links[name].merge message_types
        end
      end
    end

    ##
    # A Dsl class used to define Rackish application stacks. This classes
    # implementation is heavily inspired by Rack itself.
    #
    # Example:
    #   block = proc do
    #     use Middleware, arg1, arg2
    #     run lambda { |env| return [200, {}, env[:input1]] }
    #   end
    #   config = Langis::RackishConfig.new
    #   Blockenspiel.invoke block, config 
    #   my_app = config.to_app
    #
    #   env = {
    #     :input1 => 'Hello World'
    #   }
    #   results = my_app.call env
    #
    # @see Langis::Dsl#langis_plumbing
    class RackishConfig
      include Blockenspiel::DSL

      dsl_methods false

      ##
      # @param [#call] app Optional endpoint to declare up front.
      #   If nil, then a "no-op" end-point is used with a very basic return.
      def initialize(app=nil)
        @ins = []
        @app = app ? app : lambda { |env| [OK, {}, [""]] }
      end

      ##
      # The method that actually wires up each middleware and the end point
      # into a real Rack stack.
      #
      # @param [#call] app Optional endpoint to use instead of the one
      #   previously defined by a `run`.
      # @return [#call] The Rackish application.
      def to_app(app=nil)
        app ||= @app
        @ins.reverse.inject(app) { |a, e| e.call(a) }
      end

      dsl_methods true

      ##
      # Dsl only method that defines a piece of Middleware to run, in order,
      # in this Rack-lik application.
      #
      # @param [Class] middleware The middleware class to instantiate.
      # @param *args The arguments to pass to the initialize method for
      #   the middleware class instantiation.
      # @param &block A code block to pass to the initialize method for
      #   the middleware class instantiation.
      def use(middleware, *args, &block)
        @ins << lambda { |app| middleware.new(app, *args, &block) }
      end
   
      ##
      # Dsl only method that defines the end point Rack app handler.
      #
      # @param [#call] app The Rackish endpoint for this app.
      def run(app)
        @app = app
      end
    end
  end
end
