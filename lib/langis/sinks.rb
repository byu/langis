module Langis

  ##
  # Predefined sinks, destinations for a message pumped into the Langis Engines.
  module Sinks

    ##
    # The header key whose value is the DelayedJob enqueue result.
    DELAYED_JOB_RESULT_KEY = 'langis.sink.delayed_job.result'

    ##
    # Module function that creates the endpoint Rackish app that will
    # enqueue a new instance of a DelayedJob job class with instantiation
    # parameters extracted from the Rackish input environment.
    #
    # @param [Class] job_class The DelayedJob job class to enqueue.
    # @option options [String] :env_key (Langis::MESSAGE_KEY) The Rackish
    #   input environment key whose value is passed to the given job_class
    #   constructor. If the value of this key is an array, then the elements
    #   of that array are passed as though they were individually specified.
    # @option options [Integer] :priority (0) DelayedJob priority to be used
    #   for all jobs enqueued with this sink.
    # @option options [Time] :run_at (nil) DelayedJob run_at to be used for
    #   all jobs enqueued with this sink.
    # @return [Array<Integer,Hash,#each>] A simple OK return with the header
    #   hash that contains the delayed job enqueue result.
    def delayed_job(job_class, options={})
      priority = options[:priority] || 0
      run_at = options[:run_at]
      env_key = options[:env_key] || MESSAGE_KEY
      lambda { |env|
        args = env[env_key] || []
        args = [args] unless args.is_a? Array
        result = Delayed::Job.enqueue job_class.new(*args), priority, run_at
        return [OK, { DELAYED_JOB_RESULT_KEY => result }, ['']]
      }
    end
    module_function :delayed_job

    ##
    # The header key whose value is the Redis push_tail result.
    REDIS_RESULT_KEY = 'langis.sink.redis.result'

    ##
    # Module function that creates the endpoint Rackish app that will
    # push_tail an input environment's value into a list stored in a Redis
    # database.
    #
    # @param [Object] connection The redis database connection.
    # @param [String] key The index key of the list in the Redis database.
    # @option options [String] :env_key (Langis::MESSAGE_KEY) The Rackish
    #   input environment key whose value is pushed onto the end of the
    #   Redis key's list.
    # @return [Array<Integer,Hash,#each>] A simple OK return with the header
    #   hash that contains the Redis#push_tail result.
    def redis(connection, key, options={})
      env_key = options[:env_key] || MESSAGE_KEY
      lambda { |env|
        message = env[env_key]
        result = connection.push_tail key, message
        return [OK, { REDIS_RESULT_KEY  => result }, ['']]
      }
    end
    module_function :redis

    ##
    # The header key whose value is the Resque enqueue result.
    RESQUE_RESULT_KEY = 'langis.sink.resque.result'

    ##
    # Module function that creates the endpoint Rackish app that will
    # push_tail an input environment's value into a list stored in a Redis
    # database.
    #
    # @param [Class] job_class The Resque job class for which we want
    #   to enqueue the message.
    # @option options [String] :env_key (Langis::MESSAGE_KEY) The Rackish
    #   input environment key whose value is passed as the input arguments
    #   to the actual execution of the Resque job. The found value can be
    #   an Array, in which case the elements will be used as the execution
    #   parameters of the given job.
    # @return [Array<Integer,Hash,#each>] A simple OK return with the header
    #   hash that contains the Resque enqueue result.
    def resque(job_class, options={})
      env_key = options[:env_key] || MESSAGE_KEY
      lambda { |env|
        args = env[env_key] || []
        args = [args] unless args.is_a? Array
        result = Resque.enqueue job_class, *args
        return [OK, { RESQUE_RESULT_KEY => result }, ['']]
      }
    end
    module_function :resque
  end
end
