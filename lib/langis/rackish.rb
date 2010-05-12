module Langis
  module Rackish

    ##
    # Error raised when RackishJob is asked to run an unregistered Rackish
    # Application.
    #
    # @see RackishJob
    class NotFoundError < LangisError
    end

    ##
    # RackishJob is a dual DelayedJob-Resque job that is used to execute
    # Rackish applications, or Rack applications that are robust against
    # non-conformant "Rack Environments", in the background.
    # Rackish Applications are created and registered with this RackishJob
    # class. Each registration is associated with an app_key that is well
    # known to any component that wants to execute that particular Rackish
    # Application. Client components then queue up this job class with
    # the app_key and the input hash for that application.
    #
    # Notes
    # * This class does not provide a compliant Rack specified environment
    #   to the Rackish applications it calls. Prepend middleware that
    #   provides such an environment to the application chain if required.
    #
    # For example, to queue up a RackishJob using DelayedJob:
    #     Delayed::Job.enqueue Langis::Rackish::RackishJob.new(
    #       'my_app',
    #       {
    #         'input_key' => 'value'
    #       })
    #
    # For example, to queue up a RackishJob using Resque:
    #     Resque.enqueue(
    #       Langis::Rackish::RackishJob,
    #       'my_app',
    #       {
    #         'input_key' => 'value'
    #       })
    #
    # The my_app job may be registered in the worker process as follows:
    #     Langis::Rackish::RackishJob.register_rackish_app(
    #       'my_app',
    #       lambda { |env|
    #         # Do something
    #       })
    #
    class RackishJob < Struct.new(:app_key, :env)
      class << self

        ##
        # Registers a Rackish Application under a given name so it can be
        # executed by the RackishJob class via the DelayedJob or Resque
        # background job libraries.
        #
        # For example, the following can be found in a Rails initializer.
        #     my_app = Rack::Builder.app do
        #       run MyApp
        #     end
        #     RackishJob.register 'my_app', my_app
        #
        # @param [String] app_key The name used to lookup which Rackish
        #  application to call.
        # @param [#call] app The Rackish Application to call for the requested
        #  app_key.
        # @return [#call] The Rackish Application passed in is returned back.
        def register_rackish_app(app_key, app)
          @apps ||= {}
          @apps[app_key.to_s] = app
        end

        ##
        # Acts as the Resque starting point.
        #
        # For example, the following can be used to execute the 'my_app'
        # Rackish application using Resque from an ActiveRecord callback:
        #     def after_create(record)
        #       Resque.enqueue RackishJob, 'my_app', { 'my.data' => record.id }
        #     end
        #
        # @param [String] app_key The registered application's name that
        #  is to be called with the given env input.
        # @param [Hash] env The Rackish input environment. This is the input
        #  that should be relevant to the called app. There is no guarantee
        #  that this environment hash is a fully compliant Rack environment.
        # @raise [RackishAppNotFoundError] Signals that the given app_key
        #  was not registered with RackishJob. See DelayedJob and Resque
        #  documentation to understand how to ignore or handle raised
        #  exceptions for retry.
        def perform(app_key=nil, env={})
          app = @apps[app_key]
          if app.respond_to? :call
            app.call env 
          else
            raise NotFoundError.new "#{app_key} not found"
          end
        end
      end

      ##
      # Acts as the DelayedJob starting point. All this does is relays the
      # call to the Resque starting point.
      #
      # For example, the following can be used to execute the 'my_app'
      # Rackish application using DelayedJob from an ActiveRecord callback:
      #     def after_create(record)
      #       Delayed::Job.enqueue(
      #         RackishJob.new('my_app', { 'my.data' => record.id }))
      #     end
      #
      # @see RackishJob.perform
      def perform
        self.class.perform(app_key.to_s, env || {})
      end
    end
  end
end
