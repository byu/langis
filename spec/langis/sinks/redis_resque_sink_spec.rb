require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'redis/raketasks'

REDIS_KEY = 'langis_spec:logs'

RESQUE_QUEUE = 'langis_spec_test_queue'
RESQUE_REDIS_KEY = 'resque:queue:' + RESQUE_QUEUE 
class MyJob
  @queue = RESQUE_QUEUE
  def perform(*args)
    # Do nothing
  end 
end

# A helper class to test transforms
class Transformable
  def initialize(message, args)
    @message = message
    @args = args
  end

  def transformer(*args)
    raise 'Transform Arguments mismatch' unless @args == args
    return @message
  end
end

describe 'Redis' do
  before :each do
    begin
      @redis = Redis.new :db => 15
      Resque.redis = @redis
      @redis.flushdb
    rescue Errno::ECONNREFUSED
      raise <<-EOS

      Cannot connect to Redis.

      Make sure Redis is running on localhost, port 6379.
      This testing suite connects to the database 15.

      redis-server spec/redis.conf

      EOS
    end
  end

  describe 'normal sink' do
    it 'should add the message to a redis key, from the default MESSAGE_KEY' do
      my_message = 'Hello World'
      env = {
        Langis::MESSAGE_KEY => my_message
      }
      sink = Langis::Sinks.redis @redis, REDIS_KEY
      sink.call(env)
      messages = @redis.lrange REDIS_KEY, 0, -1
      messages.size.should eql 1
      messages[0].should eql my_message
    end

    it 'should add the message to a redis key, from an alt key' do
      my_key = 'mycustomkey'
      my_message = 'Hello World Custom Key'
      env = {
        my_key => my_message
      }
      sink = Langis::Sinks.redis @redis, REDIS_KEY, :env_key => my_key
      sink.call(env)
      messages = @redis.lrange REDIS_KEY, 0, -1
      messages.size.should eql 1
      messages[0].should eql my_message
    end

    it 'should add a transformed message to a redis key' do
      transform_message = "Hello Transformed World"
      transform_arguments = [1,2,3,4]
      my_message = Transformable.new(
        transform_message,
        transform_arguments)
      env = {
        Langis::MESSAGE_KEY => my_message
      }
      sink = Langis::Sinks.redis(@redis, REDIS_KEY,
        :transform => :transformer,
        :transform_args => transform_arguments)
      sink.call(env)
      messages = @redis.lrange REDIS_KEY, 0, -1
      messages.size.should eql 1
      messages[0].should eql transform_message
    end

    it 'should add a transformed message to a redis key, nil args' do
      transform_message = "Hello Transformed World"
      transform_arguments = []
      my_message = Transformable.new(
        transform_message,
        transform_arguments)
      env = {
        Langis::MESSAGE_KEY => my_message
      }
      sink = Langis::Sinks.redis(@redis, REDIS_KEY,
        :transform => :transformer,
        :transform_args => nil)
      sink.call(env)
      messages = @redis.lrange REDIS_KEY, 0, -1
      messages.size.should eql 1
      messages[0].should eql transform_message
    end

    it 'should add a transformed message to a redis key, without args' do
      transform_message = "Hello Transformed World"
      transform_arguments = []
      my_message = Transformable.new(
        transform_message,
        transform_arguments)
      env = {
        Langis::MESSAGE_KEY => my_message
      }
      sink = Langis::Sinks.redis(@redis, REDIS_KEY,
        :transform => :transformer)
      sink.call(env)
      messages = @redis.lrange REDIS_KEY, 0, -1
      messages.size.should eql 1
      messages[0].should eql transform_message
    end
  end

  describe 'Resque Sink' do
    it 'should add the message as a job to a resque queue, from default key' do
      my_message = 'Hello World Resque Job'
      env = {
        Langis::MESSAGE_KEY => my_message
      }
      sink = Langis::Sinks.resque MyJob
      sink.call(env)
      messages = @redis.lrange RESQUE_REDIS_KEY, 0, -1
      messages.size.should eql 1
      job_hash = JSON.parse messages[0]
      job_hash.should be_a_kind_of Hash
      job_hash['class'].should eql MyJob.to_s
      job_hash['args'].should be_a_kind_of Array
      job_hash['args'].size.should eql 1
      job_hash['args'][0].should eql my_message
    end

    it 'should add the message as a job to a resque queue, from an alt key' do
      my_key = 'mycustomkey'
      my_message = 'Hello World Resque Job Alternate Key'
      env = {
        my_key => my_message
      }
      sink = Langis::Sinks.resque MyJob, :env_key => my_key
      sink.call(env)
      messages = @redis.lrange RESQUE_REDIS_KEY, 0, -1
      messages.size.should eql 1
      job_hash = JSON.parse messages[0]
      job_hash.should be_a_kind_of Hash
      job_hash['class'].should eql MyJob.to_s
      job_hash['args'].should be_a_kind_of Array
      job_hash['args'].size.should eql 1
      job_hash['args'][0].should eql my_message
    end

    it 'should add the transformed message to a resque queue' do
      transform_message = "Hello Transformed World"
      transform_arguments = [1,2,3,4]
      my_message = Transformable.new(
        transform_message,
        transform_arguments)
      env = {
        Langis::MESSAGE_KEY => my_message
      }
      sink = Langis::Sinks.resque(MyJob,
        :transform => :transformer,
        :transform_args => transform_arguments)
      sink.call(env)
      messages = @redis.lrange RESQUE_REDIS_KEY, 0, -1
      messages.size.should eql 1
      job_hash = JSON.parse messages[0]
      job_hash.should be_a_kind_of Hash
      job_hash['class'].should eql MyJob.to_s
      job_hash['args'].should be_a_kind_of Array
      job_hash['args'].size.should eql 1
      job_hash['args'][0].should eql transform_message
    end

    it 'should add the transformed message to a resque queue, nil args' do
      transform_message = "Hello Transformed World"
      transform_arguments = []
      my_message = Transformable.new(
        transform_message,
        transform_arguments)
      env = {
        Langis::MESSAGE_KEY => my_message
      }
      sink = Langis::Sinks.resque(MyJob,
        :transform => :transformer,
        :transform_args => nil)
      sink.call(env)
      messages = @redis.lrange RESQUE_REDIS_KEY, 0, -1
      messages.size.should eql 1
      job_hash = JSON.parse messages[0]
      job_hash.should be_a_kind_of Hash
      job_hash['class'].should eql MyJob.to_s
      job_hash['args'].should be_a_kind_of Array
      job_hash['args'].size.should eql 1
      job_hash['args'][0].should eql transform_message
    end

    it 'should add the transformed message to a resque queue, without args' do
      transform_message = "Hello Transformed World"
      transform_arguments = []
      my_message = Transformable.new(
        transform_message,
        transform_arguments)
      env = {
        Langis::MESSAGE_KEY => my_message
      }
      sink = Langis::Sinks.resque(MyJob,
        :transform => :transformer)
      sink.call(env)
      messages = @redis.lrange RESQUE_REDIS_KEY, 0, -1
      messages.size.should eql 1
      job_hash = JSON.parse messages[0]
      job_hash.should be_a_kind_of Hash
      job_hash['class'].should eql MyJob.to_s
      job_hash['args'].should be_a_kind_of Array
      job_hash['args'].size.should eql 1
      job_hash['args'][0].should eql transform_message
    end
  end
end
