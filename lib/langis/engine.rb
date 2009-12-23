module Langis
  module Engine

    ##
    # Instances of this class are executed when a message is pushed to
    # the intake's EventMachine::Channel that it subscribed to. Its
    # primary function is to safely execute the Langis sink
    # (Rackish application) that it has been tasked to manage. To do
    # this safely with performance considerations, it enqueues a
    # Proc to be handled by the EvenMachine's deferred thread pool and
    # protects the thread pool by wrapping the sink call with a rescue block.
    # Any caught errors will result in an error message with the caught
    # exception pushed into the given EventMachine error channel. All
    # successful completions will push the returned Rackish result to the
    # EventMachine success channel.
    class EventMachineRunner

      ##
      #
      # @param [#call] app The Rackish app to execute.
      # @param [Hash] options ({})
      # @option options [EventMachine::Channel] :success_channel (nil) The
      #   EventMachine::Channel instance to push the Rackish app's return
      #   results to. This happens when there are no errors raised.
      # @option options [EventMachine::Channel] :error_channel (nil) The
      #   EventMachine::Channel instance to push error messages to when the
      #   runner catches an exception during the execution of the Rackish app.
      # @option options [Object] :evm (EventMachine) Specify a different
      #   class/module to use when executing deferred calls. Mainly useful
      #   for unit testing, or if you want to run the app directly in
      #   the main thread instead of the deferred thread pool.
      def initialize(app, options={})
        @app = app
        @success_channel = options[:success_channel]
        @error_channel = options[:error_channel]
        @evm = options[:evm] || EventMachine
        @intake_name = options[:intake_name]
      end

      ##
      # The method that is called in the EventMachine's main reactor thread
      # whose job is to enqueue the main app code to be run by EventMachine's
      # deferred thread pool.
      #
      # This method sets up the Rackish environment hash that is passed
      # as the main input to the Rackish app; it sets up the Proc that will
      # be actually executed in by the deferred thread pool. The proc
      # protects the thread pool from exceptions, and pushes respective
      # error and success results to given EventMachine channels.
      #
      # @param [Object] message The message that is getting pushed through
      #   the Langis pipes to their eventual handlers.
      def call(message)
        # Assign local variables to the proper apps, etc for readability.
        app = @app
        success_channel = @success_channel
        error_channel = @error_channel
        intake_name = @intake_name
        # Enqueue the proc to be run in by the deferred thread pool.
        @evm.defer(proc do
          # Create the base environment that is understood by the Rackish apps.
          env = {}
          env[MESSAGE_TYPE_KEY] = message.mtype.to_s if(
            message.respond_to? :mtype)
          env[MESSAGE_KEY] = message
          env[INTAKE_KEY] = intake_name
          # Actually run the Rackish app, protected by a rescue block.
          # Push the results to their respective channels when finished.
          begin
            results = app.call env
            success_channel.push(results) if success_channel
          rescue => e
            # It was an error, so we have to create a Rackish response array.
            # We push a SERVER_ERROR status along with an enhanced
            # headers section: the exception and original message.
            error_channel.push([
              SERVER_ERROR,
              env.merge({ X_EXCEPTION => e}),
              ['']]) if error_channel
          end
        end)
      end
    end

    ##
    # And EventMachine based implementation of a Langis Engine. Its sole
    # job is to take a pumped message into an intake and broadcast the same
    # message to all of the intake's registered sinks. In essense these
    # engines need to execute the sinks handler methods for each message.
    #
    # This class leverages EventMachine's features to easily do efficient
    # publishing to the subscribers, and uses the EventMachineRunner
    # to do the actual code execution.
    #
    # @see EventMachineRunner
    class EventMachineEngine

      ##
      # @param [Hash{String=>Array<#call>}] intakes The mapping of intake
      #   names to the list of Rackish applications (sinks) that subscribed
      #   to the given intake.
      # @option options [Object] :evm (EventMachine) Specify a different
      #   class/module to use when executing deferred calls. Mainly useful
      #   for unit testing, or if you want to run the app directly in
      #   the main thread instead of the deferred thread pool.
      # @option options [Class] :evm_channel (EventMachine::Channel) The
      #   channel class to instantiate as the underlying pub-sub engine. This
      #   is useful for unittesting, or if you want to implement a
      #   non-EventMachine pub-sub mechanism.
      def initialize(intakes, options={})
        evm_channel_class = options[:evm_channel] || EventMachine::Channel
        @intake_channels = {}
        intakes.each do |intake_name, apps|
          runner_options = {
            :success_channel => options[:success_channel],
            :error_channel => options[:error_channel],
            :evm => options[:evm],
            :intake_name => intake_name
          }
          @intake_channels[intake_name] = channel = evm_channel_class.new
          apps.each do |app|
            channel.subscribe EventMachineRunner.new(app, runner_options)
          end
        end
      end

      ##
      # Publishes a message into the Langis publish-subscribe bus.
      #
      # @overload pump(message)
      #   Publishes the message to the :default intake.
      #   @param [Object] message The message to publish.
      # @overload pump(message, ...)
      #   Publishes the message to the given list of intakes.
      #   @param [Object] message The message to publish.
      #   @param [#to_s] ... Publish the message to these listed intakes
      def pump(message, *intakes)
        intakes.unshift :default if intakes.empty?
        intakes.each do |name|
          channel = @intake_channels[name.to_s]
          channel.push(message) if channel
        end
      end
    end
  end
end
