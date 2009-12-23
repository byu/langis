Langis
======

Langis is a Rack inspired publish-subscribe system for Ruby.

It has flexible message routing and message handling using a custom
Domain Specific Language and a Rack-inspired message handler framework.
This can give Rails applications better (and decoupled) visibility
and management of the background processes it creates (or executes)
in response to its actions (in controllers or models).

Links
-----
* Repository - <http://github.com/byu/langis>
* Yard/RDocs - <http://rdoc.info/projects/byu/langis>
* Issues - <http://github.com/byu/langis/issues>

*Questions?* Message one of the Authors listed below.

A Brief and Incomplete Overview of Why and How Langis
-----------------------------------------------------

Our main problems:

* We have jobs that get queued up in different controllers, models and
  model observers. Jobs may even queue up other jobs. And our code becomes
  more brittle source base since we have to remember to make changes in
  each of those places whenever we modify job creation. Jobs are more
  difficult to organize.
* Higher latency response times because the model observer callbacks are run
  in the same thread as the Rails request. Clients won't get responses
  until we finish queuing up all the jobs, or handle the job queuing failures.
  Example: A queuing failure could be due to a hung queue server that receives
  the job, but hangs and doesn't return a response there by blocking our
  Rails thread.
* Sometimes we want to execute light-weight tasks like pregenerating
  (and caching) some content for a user's next page view, but needs to be
  done with more immediacy than what can be guaranteed by our job libraries.

How can Langis (Signal backwards) solve this?

* Langis first postulates that job creation is a response to Events
  (a type of Message) in the system.
* Secondly, we centralize the configuration of channels and their subscribers.
  This is done using a Domain Specific Language and central configuration in
  a Rails initializer.
* Finally, we have Rack-inspired middleware and applications that is executed
  in EventMachine deferred thread pools to respond to such Events.

For example, let's say that we have changed our model observer's after
create method to publish a "MyModelCreatedEvent" event instead of directly
(tigher coupling) creating our needed BackgroundJobX (et al).

1. We define some Rack-like middleware to transform the MyModelCreatedEvent
  message into actual data required for our BackgroundJobX.
2. We create a Rackish application using the afore mentioned middleware and
  one of Langis' predefined job sinks.
3. We finally subscribe our Rackish applications to said Event using our
  configuration language.

So, our model publishes an event. Our Rackish applications are executed
in response to said event, and we can enqueue many background jobs (not just
BackgroundJobX) without impacting the response to our client.

What if BackgroundJobX is also created in a separate controller, unrelated
to MyModel? That separate controller can instead publish its own event, and 
change the configuration to subscribe BackgroundJobX to this new separate event.

Installation and Usage
======================

Install the gem from gemcutter:

> sudo gem install 'langis'

As a plugin:

> script/plugin install git://github.com/byu/langis.git

Then add it to the project `Gemfile`.

> gem 'langis'

Or add it into the `config/environment.rb` file (only for Rails):

> config.gem 'langis'

Dependencies
------------
Be aware of the dependencies of our dependencies that have been omitted
from this list.

* set (Dsl) - Ruby stdlib
* eventmachine (Engine) - <http://rubyeventmachine.com/>
  * <http://github.com/eventmachine/eventmachine>
* hashie (Model) - <http://github.com/hassox/hashie>
* json (Model) - Your preferred json library.
* uuid (Model) - <http://github.com/assaf/uuid>
* yaml (Model) - Ruby stdlib

Optional Dependencies
---------------------
* DelayedJob - <http://github.com/tobi/delayed_job>
  * For Langis::Sinks.delayed_job
* Redis - <http://code.google.com/p/redis/>
  * For Langis::Sinks.redis
  * Redis-rb - <http://github.com/ezmobius/redis-rb>
* Resque - <http://github.com/defunkt/resque>
  * For Langis::Sinks.resque

Configuration
-------------

To use in rails, we provide a generator to create a simple initializer.

> script/generate langis_config

It generates the following file:

> config/initializers/langis_config.rb

By default, it initializes a LangisEngine that pretty much does nothing.

    LangisEngine = (lambda {
      # Define the routes
      config = Langis::Dsl.langis_plumbing do
        intake :default do
          flow_to :default
        end

        for_sink :default do
          run lambda { |env| puts Rails.logger.info(env.inspect) }
        end

        check_valve do
        end
      end

      # Create an example success callback channel.
      success_channel = EM::Channel.new
      success_channel.subscribe(proc do |msg|
        # TODO: Implement your own success handler.
        # Rails.logger.info "Success: #{msg.inspect}"
      end)

      # Create an example error callback channel.
      error_channel = EM::Channel.new
      error_channel.subscribe(proc do |msg|
        # TODO: Implement your own error handler.
        # Rails.logger.warn "Error: #{msg.inspect}"
      end)

      # Create and return the actual EventMachine based Langis Engine.
      return Langis::Engine::EventMachineEngine.new(
        config.build_pipes,
        :success_channel => success_channel,
        :error_channel => error_channel)
    }).call

Usage
-----

Now one can pump arbitrary messages through the engine to the default intake.

    LangisEngine.pump 'Hello World'

Or one can target the intake specifically.

    LangisEngine.pump 'Hello World', :default

But what we really want to do is create Messages and Events that each
contain properties (See Yard/Rdocs) that help with routing.

    class MyModelCreatedEvent < Langis::Models::Event
      property :mtype => 'MyModelCreatedEvent'
      property :my_model_id

      def to_my_model_id
        return my_model_id
      end
    end

Pump this model into the intake from your model's observer.

    LangisEngine.pump MyModelCreatedEvent.new(:my_model_id => 1)

We have a corresponding background job:

    class BackgroundJobX < Struct.new(:my_model_id)
      def perform
        # do something
      end
    end

The corresponding handler may be declared like this:

    intake :default do
      # This routes only the MyModelCreatedEvent mtypes.
      flow_to :background_job_x, :when => 'MyModelCreatedEvent'
    end

    for_sink :background_job_x do
      use Langis::Middleware::EnvFieldTransform, :to_method => :to_my_model_id
      run Langis::Sinks.delayed_job BackgroundJobX
    end

Note that the base Langis Message and Events are serializable to Json and
Yaml. So one could create background jobs that take in events instead of
separate ids.

But now, I want to log each event published into a Redis log. Langis Events
have helpful default properties that make keeping track of history:
event_uuid and event_timestamp.

    REDIS_DB = Redis.new

    intake :default do
      # This captures all messages
      flow_to :log_to_redis
    end

    for_sink :log_to_redis do
      run Langis::Sinks.redis REDIS_DB, 'myapp:event_logs'
    end

Note that you can reuse the same Redis connection between the Redis
sink and the Resque sink.

    REDIS_DB = Redis.new
    Resque.redis = REDIS_DB

Running EventMachine in Webservers
==================================

The main Langis Engine is built using EventMachine. And one must take care
about how to start up EventMachine depending on the web server used.

Mongrel
-------

Mongrel is simple and single threaded, so you need to run the following
somewhere in the initializer code.

    Thread.new do
      EM.run
    end

There shouldn't be any problem if a Message is published to a Langis
Intake before EventMachine fully comes up. That message will stay in
the EventMachine Channel queue, waiting to be processed once EventMachine
does start.

Thin
----

Thin also uses EventMachine. So you don't need to do anything in particular.

Passenger and Unicorn
---------------------

TODO: Needs investigating

Testing
=======
This library uses [Bundler](http://github.com/wycats/bundler) instead
of the base system's rubygems to pull in the requirements for tests.

> gem bundle
>
> rake spec
>
> rake features
>
> rake rcov

However, `rake rcov` requires rcov to be installed in the base system.

Note on Patches/Pull Requests
=============================
* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a
  commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

Authors
=======
* Benjamin Yu - <http://benjaminyu.org/>, <http://github.com/byu>

Copyright
=========

> Copyright 2009 Benjamin Yu
>
> Licensed under the Apache License, Version 2.0 (the "License");
> you may not use this file except in compliance with the License.
> You may obtain a copy of the License at
>
> http://www.apache.org/licenses/LICENSE-2.0
>
> Unless required by applicable law or agreed to in writing, software
> distributed under the License is distributed on an "AS IS" BASIS,
> WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
> See the License for the specific language governing permissions and
> limitations under the License.
