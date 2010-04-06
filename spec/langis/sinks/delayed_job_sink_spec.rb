require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

include Temping

# We create a plain no-op DelayedJob job class.
class MyJob < Struct.new(:message)
  def perform
    nil
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

describe 'DelayedJobSink' do
  before :all do
    # We have to set up the Delayed::Job constant for this test
    Delayed::Worker.backend = :active_record

    create_model :delayed_jobs do
      with_columns do |table|
        table.integer  :priority, :default => 0
        table.integer  :attempts, :default => 0
        table.text     :handler
        table.string   :last_error
        table.datetime :run_at
        table.datetime :locked_at
        table.datetime :failed_at
        table.string   :locked_by
        table.timestamps
      end
    end
  end

  after :each do
    DelayedJob.all.each do |job|
      job.delete
    end
  end

  it 'should create a delayed job' do
    my_message = 'Hello World'
    env = {
      Langis::MESSAGE_KEY => my_message
    }
    sink = Langis::Sinks.delayed_job(MyJob)
    sink.call(env)
    delayed_jobs = DelayedJob.all
    delayed_jobs.size.should eql 1
    delayed_job = delayed_jobs[0]
    delayed_job.priority.should eql 0
    delayed_job.run_at.should_not be_nil
    my_job = YAML::load delayed_job.handler
    my_job.message.should eql my_message
  end

  it 'should create a delayed job with alternate priority' do
    my_priority = 10239
    my_message = 'Hello World'
    env = {
      Langis::MESSAGE_KEY => my_message
    }
    sink = Langis::Sinks.delayed_job(MyJob, :priority => my_priority)
    sink.call(env)
    delayed_jobs = DelayedJob.all
    delayed_jobs.size.should eql 1
    delayed_job = delayed_jobs[0]
    delayed_job.priority.should eql my_priority
    delayed_job.run_at.should_not be_nil
    my_job = YAML::load delayed_job.handler
    my_job.message.should eql my_message
  end

  it 'should create a delayed job with alternate run_at' do
    my_run_at = Time.now
    my_message = 'Hello World'
    env = {
      Langis::MESSAGE_KEY => my_message
    }
    sink = Langis::Sinks.delayed_job(MyJob, :run_at => my_run_at)
    sink.call(env)
    delayed_jobs = DelayedJob.all
    delayed_jobs.size.should eql 1
    delayed_job = delayed_jobs[0]
    delayed_job.priority.should eql 0
    delayed_job.run_at.to_s.should eql my_run_at.to_s
    my_job = YAML::load delayed_job.handler
    my_job.message.should eql my_message
  end

  it 'should create a delayed job with message from alternate key' do
    my_message = 'Hello World'
    my_alternate_key = 'MyAlternateKey'
    env = {
      my_alternate_key => my_message
    }
    sink = Langis::Sinks.delayed_job(MyJob, :env_key => my_alternate_key)
    sink.call(env)
    delayed_jobs = DelayedJob.all
    delayed_jobs.size.should eql 1
    delayed_job = delayed_jobs[0]
    delayed_job.priority.should eql 0
    delayed_job.run_at.should_not be_nil
    my_job = YAML::load delayed_job.handler
    my_job.message.should eql my_message
  end

  it 'should create a delayed job with a message transform' do
    transform_message = "Hello Transformed World"
    transform_arguments = [1,2,3,4]
    my_message = Transformable.new(
      transform_message,
      transform_arguments)
    env = {
      Langis::MESSAGE_KEY => my_message
    }
    sink = Langis::Sinks.delayed_job(MyJob,
      :transform => :transformer,
      :transform_args => transform_arguments)
    sink.call(env)
    delayed_jobs = DelayedJob.all
    delayed_jobs.size.should eql 1
    delayed_job = delayed_jobs[0]
    delayed_job.priority.should eql 0
    delayed_job.run_at.should_not be_nil
    my_job = YAML::load delayed_job.handler
    my_job.message.should eql transform_message
  end

  it 'should create a delayed job with a message transform, with nil args' do
    transform_message = "Hello Transformed World"
    transform_arguments = []
    my_message = Transformable.new(
      transform_message,
      transform_arguments)
    env = {
      Langis::MESSAGE_KEY => my_message
    }
    sink = Langis::Sinks.delayed_job(MyJob,
      :transform => :transformer,
      :transform_args => nil)
    sink.call(env)
    delayed_jobs = DelayedJob.all
    delayed_jobs.size.should eql 1
    delayed_job = delayed_jobs[0]
    delayed_job.priority.should eql 0
    delayed_job.run_at.should_not be_nil
    my_job = YAML::load delayed_job.handler
    my_job.message.should eql transform_message
  end

  it 'should create a delayed job with a message transform, without args' do
    transform_message = "Hello Transformed World"
    transform_arguments = []
    my_message = Transformable.new(
      transform_message,
      transform_arguments)
    env = {
      Langis::MESSAGE_KEY => my_message
    }
    sink = Langis::Sinks.delayed_job(MyJob,
      :transform => :transformer)
    sink.call(env)
    delayed_jobs = DelayedJob.all
    delayed_jobs.size.should eql 1
    delayed_job = delayed_jobs[0]
    delayed_job.priority.should eql 0
    delayed_job.run_at.should_not be_nil
    my_job = YAML::load delayed_job.handler
    my_job.message.should eql transform_message
  end

  it 'should create a delayed job with a message transform, non Array arg' do
    transform_message = "Hello Transformed World"
    one_arg = "ITSY BITSY ONE"
    transform_arguments = [one_arg]
    my_message = Transformable.new(
      transform_message,
      transform_arguments)
    env = {
      Langis::MESSAGE_KEY => my_message
    }
    sink = Langis::Sinks.delayed_job(MyJob,
      :transform => :transformer,
      :transform_args => one_arg)
    sink.call(env)
    delayed_jobs = DelayedJob.all
    delayed_jobs.size.should eql 1
    delayed_job = delayed_jobs[0]
    delayed_job.priority.should eql 0
    delayed_job.run_at.should_not be_nil
    my_job = YAML::load delayed_job.handler
    my_job.message.should eql transform_message
  end

  it 'should create a delayed job with all options changed' do
    my_message = 'Hello World'
    my_priority = 10239
    my_alternate_key = 'MyAlternateKey'
    my_run_at = Time.now
    env = {
      my_alternate_key => my_message
    }
    sink = Langis::Sinks.delayed_job(MyJob,
      :env_key => my_alternate_key,
      :priority => my_priority,
      :run_at => my_run_at)
    sink.call(env)
    delayed_jobs = DelayedJob.all
    delayed_jobs.size.should eql 1
    delayed_job = delayed_jobs[0]
    delayed_job.priority.should eql my_priority
    delayed_job.run_at.to_s.should eql my_run_at.to_s
    my_job = YAML::load delayed_job.handler
    my_job.message.should eql my_message
  end
end
