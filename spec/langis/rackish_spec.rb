require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Langis::Rackish::RackishJob do
  before :all do
    Langis::Rackish::RackishJob.register_rackish_app('my_app', lambda { |env|
      [200, {}, ["Hello World, #{env['name']}"]]
    })
  end

  it 'should raise an error on an unregistered app' do
    lambda {
      Langis::Rackish::RackishJob.perform 'unregistered_app'
    }.should raise_error(Langis::Rackish::NotFoundError)
  end

  it 'should properly call a registered app using class method' do
    result = Langis::Rackish::RackishJob.perform 'my_app', 'name' => 'Langis'
    result.should eql [200, {}, ["Hello World, Langis"]]
  end

  it 'should properly call a registered app using instance method' do
    rackish_job = Langis::Rackish::RackishJob.new 'my_app', 'name' => 'Langis'
    result = rackish_job.perform
    result.should eql [200, {}, ["Hello World, Langis"]]
  end

  it 'should handle a nil env by instance method' do
    rackish_job = Langis::Rackish::RackishJob.new 'my_app', nil
    result = rackish_job.perform
    result.should eql [200, {}, ["Hello World, "]]
  end

end
