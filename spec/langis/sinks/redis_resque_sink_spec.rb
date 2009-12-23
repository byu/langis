require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'redis/raketasks'

REDIS_KEY = 'langis_spec:logs'
TEST_DATABASE_FILE = 'spec_test_redis_db.rdb'

# We subclass the redis-rb runner task so we can start up using a redis
# conf file of our choosing.
class MyRedisRunner < RedisRunner
  def self.redisconfdir
    File.expand_path(File.dirname(__FILE__) + '/../../redis.conf')
  end
end

RESQUE_QUEUE = 'logs'
RESQUE_REDIS_KEY = 'resque:queue:' + RESQUE_QUEUE 
class MyJob
  @queue = RESQUE_QUEUE
  def perform(*args)
    # Do nothing
  end 
end

describe 'Redis' do
  before :all do
    File.unlink(TEST_DATABASE_FILE) if File.exist?(TEST_DATABASE_FILE)
    result = MyRedisRunner.start_detached
    raise("Could not start redis-server, aborting") unless result
    # Might just need to wait just a little bit for it to spin up
    sleep 1
    @redis = Redis.new
    Resque.redis = @redis
  end

  after :all do
    begin
      @redis.quit
    ensure
      RedisRunner.stop
    end
  end

  describe 'normal sink' do
    after :each do
      @redis.del REDIS_KEY
    end

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
  end

  describe 'Resque Sink' do
    after :each do
      @redis.del RESQUE_REDIS_KEY
    end
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
      my_message = 'Hello World Resque Job Alternat Key'
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
  end
end
