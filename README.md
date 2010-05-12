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

* We have long running jobs that get queued up in different controllers,
  models and model observers. Jobs may even queue up other jobs.
  Application business process becomes increasingly difficult to maintain
  as every new change may touch (or add to) different parts of the code.
* Higher latency response times because the model observer callbacks are run
  in the same thread as the Rails request. Clients won't get responses
  until we finish queuing up all the jobs, or handle the job queuing failures.
  Example: A queuing failure could be due to a hung queue server that receives
  the job, but hangs and doesn't return a response there by blocking our
  Rails thread.
* Sometimes we want to execute light-weight tasks like pregenerating
  (and caching) some content for a user's next page view, but needs to be
  done with more immediacy than what can be guaranteed by our job libraries.

How can Langis (Signal spelled backwards) solve this?

* Langis first postulates that job creation is a response to Events
  (a type of Message) in the system.
* Secondly, we centralize the configuration of channels and their subscribers.
  This is done using a Domain Specific Language and central configuration in
  a Rails initializer.
* Finally, we have Rack-inspired middleware and applications that is executed
  in EventMachine deferred thread pools to respond to such Events.

For example, an ActiveRecord observer model will just publish a "ModelEvent"
message (e.g. - to represent Article Created) into Langis instead of directly
(tigher coupling) creating respective DelayedJob jobs. Langis will be
configured to route the "ModelEvent" to listening Rack-based applications
that will then create the jobs (looser coupling).

A Quick Note on Nomenclature
----------------------------

Langis is inspired by **Rack**, but does not explicitly implement the Rack
Specification.

**Rackish** is used to describe things that are based in Rack, but not
actually Rack Specification conformant.

For example, we use the term *Rackish Application* to talk about an
actual Rack Application that doesn't actually require a fully conformant
*Rack Environment* as input. To be more clear, Langis does not provide
environment variables such as SCRIPT_NAME, rack.version, etc.

However, it is possible to run real Rack Applications from Langis if the
Rack Environment is set up properly by prepending custom middleware to
the Rackish Application stack.

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

* blockenspiel (Dsl) - Our Domain Specific Language engine
* set (Dsl) - Ruby stdlib
* eventmachine (Engine)
  * <http://rubyeventmachine.com/>
  * <http://github.com/eventmachine/eventmachine>

Optional Dependencies
---------------------
* DelayedJob - <http://github.com/tobi/delayed_job>
  * For Langis::Sinks.delayed_job
* Redis - <http://code.google.com/p/redis/>
  * For Langis::Sinks.redis
  * Redis-rb - <http://github.com/ezmobius/redis-rb>
* Resque - <http://github.com/defunkt/resque>
  * For Langis::Sinks.resque
* ActiveModel - <http://github.com/rails/rails>
  * To help model your messages

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

Usage: An Event Model and DelayedJob
------------------------------------

Now one can pump arbitrary messages through the engine to the default intake.

    LangisEngine.pump 'Hello World'

Or one can target the intake specifically.

    LangisEngine.pump 'Hello World', :default

It would be more useful to pump messages that are meaningful and routable.
In the following example, we use ActiveModel modules to help implement
such a message.

    # A generic class used to describe ActiveRecord observable events.
    class ModelEvent
      extend ActiveModel::Naming
      include ActiveModel::Serializers::JSON

      attr_accessor :model_name
      attr_accessor :model_id
      attr_accessor :event_type
      attr_accessor :uuid
      attr_accessor :timestamp

      def initialize(attributes={})
        self.model_name = attributes[:model_name]
        self.model_id = attributes[:model_id]
        self.event_type = attributes[:event_type]
        self.uuid = UUID.new
        self.timestamp = DateTime.now
      end

      # required by the serializer
      def attributes
        {
          'model_name' => model_name,
          'model_id' => model_id,
          'event_type' => event_type,
          'uuid' => uuid,
          'timestamp' => timestamp
        }
      end

      # Langis introspects the message_type to help route messages.
      def message_type
        "#{model_name}_#{event_type}"
      end
    end

Assuming that we have an ActiveModel record for our Rails app:

    class Article < ActiveRecord::Base
    end

The ModelEvent object is created in Article's create observer.

    def after_create(article)
      LangisEngine.pump ModelEvent.new(
        :model_id => article.id,
        :model_name => article.class.model_name,
        :event_type => 'created')
    end

The LangisEngine's routes may be configure using the following DSL:

    intake :default do
      flow_to :xmpp_article, :webhook_article, :when => 'Article_created'
    end

    for_sink :xmpp_article do
      run Langis::Sinks.delayed_job XmppArticle, :transform => :model_id
    end

    for_sink :webhook_article do
      run Langis::Sinks.delayed_job WebhookArticle, :transform => :model_id
    end

The above DSL describes the default intake that accepts messages, which is
configured to send messages of message_type "Article_created" to the
:xmpp_article and :webhook_article sinks. Also note that a transform is
declared for these sinks. The declared transforms execute the :model_id
method on each received ModelEvent, which then takes that method's return
value an uses it as the DelayedJob's job #new parameters. For Resque sinks,
those said return values would be the parameters for the Resque job's perform 
method. These transforms are used to accommodate the different serialization
techniques for different background processing libraries-- DelayedJob's
Yaml deserialization isn't so good with ActiveModel based objects.

    class XmppArticle < Struct.new(:article_id)
      def perform
        # Load model, create text message, and send Xmpp message
      end
    end

    class WebhookArticle < Struct.new(:article_id)
      def perform
        # Load model, create xml message, and post to Webhook
      end
    end

Note that DelayedJob 2.0+ requires additional initialization to declare
the type of DelayedJob Backend to use. Example:

    Delayed::Worker.backend = :active_record

Usage: Resque and Json
----------------------

The marshalling for Resque jobs is Json based. So, it is possible to pass
in the ModelEvent without using the :transform option. It will be serialized
to_json automatically, but deserialized into a Hash object in the Resque job
perform. To actually get it back into an actual ModelEvent object, one will
have to implement that Hash-to-ModelEvent code.

    # A different job implementation
    class ArticleResqueWebhook
      def self.perform(model_event)
        # This model_event will be a Hash map, the deserialized object
        # from the ModelEvent#to_json
      end
    end

    # Using the same observer
    def after_create(article)
      LangisEngine.pump ModelEvent.new(
        :model_id => article.id,
        :model_name => article.class.model_name,
        :event_type => 'created')
    end

    # In the Langis Dsl
    intake :default do
      flow_to :article_resque_webhook, :when => 'Article_created'
    end
    for_sink :article_resque_webhook do
      run Langis::Sinks.resque ArticleResqueWebhook
    end

Usage: Route by Intakes
-----------------------

Langis is flexible in the ability to handle different types of messages and
routing. For example, we could just pass on the actual ActiveRecord objects to
different intakes:

    # In the Article observer
    def after_create(article)
      LangisEngine.pump article, :article_created
    end

    # In the Dsl, assuming all messages to this intake are Article objects.
    # NOTE: If that can't be guaranteed, then implement a middleware
    # filter for the alternate_xmpp_article sink.
    intake :article_created do
      flow_to :alternate_xmpp_article
    end

    # Gets the article's id as the input to the job
    for_sink :alternate_xmpp_article do
      run Langis::Sinks.delayed_job XmppArticle, :transform => :id
    end

Usage: Dump to Redis
--------------------

But now, I want to log each message published into a Redis log. The following
takes every message in and RPUSHes its #to_json representation into a
Redis key. Implementation note: Redis calls #to_s to serialize objects
before saving to the database. So even if the message does not respond to
to_json, its to_s (for the following example) will be used.

    REDIS_DB = Redis.new

    intake :default do
      # This captures all messages
      flow_to :log_to_redis
    end

    for_sink :log_to_redis do
      run Langis::Sinks.redis(REDIS_DB, 'myapp:event_logs',
        :transform => :to_json)
    end

Note that one can reuse the same Redis connection between the Redis
sink and the Resque sink.

    # Do this in the initialization before Langis Dsl configuration.
    REDIS_DB = Redis.new
    Resque.redis = REDIS_DB

    # And in the Langis Dsl:
    for_sink :log_to_redis do
      run Langis::Sinks.redis REDIS_DB, 'myapp:event_logs'
    end

Usage: Running Rackish Apps in Background Jobs
-----------------------------------------------

Langis also provides a simple driver class to run Rackish applications as
DelayedJob or Resque background jobs. What this means is that a developer
can create a Langis Sink (Rackish Application) and have it run either from
the thread pool in the main process (Rails) or in background worker processes.
This assumes that the env (including the pumped message) can be marshalled
by Yaml or Json (as used by DelayedJob and Resque).

For example, we may want to post data to a webhook.

    # A super simple Rack app that posts data to a uri.
    class JsonWebhookOutlet
      def call(env)
        # Make HTTP POST to uri with json data here.
        uri = env['uri']
        data = env['data']

        # Then return the success response.
        [200, {}, 'OK']
      end
    end

Based on when new articles are created.

    # In the Article observer
    def after_create(article)
      LangisEngine.pump article, :article_created
    end

We use Langis to handle the observed events.

    # In the Langis Dsl, the following intake is defined
    intake :article_created do
      flow_to :webhook_article
    end

The following is a sink that will post to the webhook in the background
thread of the same process.

    # This Langis Dsl sink definition executes the JsonWebhookOutlet
    # Rackish application using the thread pool in the main Rails process.
    # The uri and json data are obtained using Langis middleware transforms;
    # it assumes that the actual Article instance has the following to_methods.
    for_sink :webhook_article do
      use EnvFieldTransform, :to_method => :to_json, :key => 'data'
      use EnvFieldTransform, :to_method => :get_owner_webhook, :key => 'uri'
      run JsonWebhookOutlet.new
    end

But we really would like to use the background jobs such as the following.
This is the alternative Langis sink definition that queues up the
work as a background job. It has the same to_method transforms as above.
But this sink definition also uses the Parameterizer to create the
proper arguments so the RackishJob job will run the json webhook
Rackish Application. The Parameterizer is defined to do the following:

1. Create an Array of 2 items.
    a. The first item is a fixed string: 'post_to_webhook'.
    b. The second item is a new hash containing the uri and data elements
      from the prior EnvFieldTransforms.
2. Save the new Array to the the input enviromentment under the key
  named 'save.to.this.key'.

The delayed job sink finally queues up the Rackish job with the
arguments listed in 'save.to.this.key'.

    for_sink :webhook_article do
      use EnvFieldTransform, :to_method => :to_json, :key => 'data'
      use EnvFieldTransform, :to_method => :get_webhook, :key => 'uri'
      use Langis::Middleware::Parameterizer,
        'post_to_webhook',
        lambda { |env|
          {
            'uri' => env['uri'],
            'data' => env['data']
          }
        },
        :env_key => 'save.to.this.key'
      run Langis::Sinks.delayed_job(
        Langis::Rackish::RackishJob,
        :env_key => 'save.to.this.key')
    end

And in the background process, we need to wire up the 'post_to_webhook'
name to the actual code.

    # This initializer code is run by the background worker process on startup.
    # It is not needed in the main Rails process.
    Langis::Rackish::RackishJob.register_rackish_app(
      'post_to_webhook',
      Rack::Builder.app do
        run JsonWebhookOutlet.new
      end)

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
This library uses [Bundler](http://gembundler.com/) instead
of the base system's rubygems to pull in the requirements for tests.

> bundle install
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
