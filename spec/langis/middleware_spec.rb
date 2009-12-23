require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'EnvFieldTransform' do
  it 'should call to_json on a default Langis::MESSAGE_KEY header field' do
    to_json_value = 'some random json value'
    call_env = {
      Langis::MESSAGE_KEY => to_json_value
    }
    message_mock = mock 'message'
    message_mock.should_receive(:to_json).and_return(to_json_value)
    env = {
      Langis::MESSAGE_KEY => message_mock
    }
    app_mock = mock 'app'
    app_mock.should_receive(:call).with(call_env)
    @middleware = Langis::Middleware::EnvFieldTransform.new app_mock
    @middleware.call(env)
  end

  it 'should call to_json on a "custom" header field' do
    fieldname = "custom_field"
    to_json_value = 'some random json value'
    call_env = {
      fieldname => to_json_value
    }
    message_mock = mock 'message'
    message_mock.should_receive(:to_json).and_return(to_json_value)
    env = {
      fieldname => message_mock
    }
    app_mock = mock 'app'
    app_mock.should_receive(:call).with(call_env)
    @middleware = Langis::Middleware::EnvFieldTransform.new(
      app_mock,
      :key => fieldname)
    @middleware.call(env)
  end

  it 'should call to_json on a "custom" header field with args' do
    fieldname = "custom_field"
    to_json_value = 'some random json value'
    to_args = [1, 2, 3, 4, 5]
    call_env = {
      fieldname => to_json_value
    }
    message_mock = mock 'message'
    message_mock.should_receive(:to_json).
      with(*to_args).
      and_return(to_json_value)
    env = {
      fieldname => message_mock
    }
    app_mock = mock 'app'
    app_mock.should_receive(:call).with(call_env)
    @middleware = Langis::Middleware::EnvFieldTransform.new(
      app_mock,
      :to_args => to_args,
      :key => fieldname)
    @middleware.call(env)
  end

  it 'should call "custom_to_method" on a "custom" header field' do
    fieldname = "custom_field"
    to_value = 'some random value'
    call_env = {
      fieldname => to_value
    }
    message_mock = mock 'message'
    message_mock.should_receive(:custom_to_method).and_return(to_value)
    env = {
      fieldname => message_mock
    }
    app_mock = mock 'app'
    app_mock.should_receive(:call).with(call_env)
    @middleware = Langis::Middleware::EnvFieldTransform.new(
      app_mock,
      :to_method => :custom_to_method,
      :key => fieldname)
    @middleware.call(env)
  end
end

describe 'MessageTypeFilter' do
  it 'should filter an unlisted type' do
    message_type_1 = 'MyMessageType1'
    message_type_2 = 'MyMessageType2'
    message_type_3 = 'MyMessageType3'
    message_type_4 = 'MyMessageType4'
    env = {
      Langis::MESSAGE_TYPE_KEY => message_type_1
    }
    # Set up a mock that won't receive any calls.
    app_mock = mock 'app'
    @middleware = Langis::Middleware::MessageTypeFilter.new(
      app_mock,
      message_type_2,
      message_type_3,
      message_type_4)
    @middleware.call(env)
  end

  it 'should allow a listed type through' do
    message_type_1 = 'MyMessageType1'
    message_type_2 = 'MyMessageType2'
    message_type_3 = 'MyMessageType3'
    message_type_4 = 'MyMessageType4'
    env = {
      Langis::MESSAGE_TYPE_KEY => message_type_3
    }
    app_mock = mock 'app'
    app_mock.should_receive(:call).with(env)
    @middleware = Langis::Middleware::MessageTypeFilter.new(
      app_mock,
      message_type_2,
      message_type_3,
      message_type_4)
    @middleware.call(env)
  end

  it 'should not let anything through' do
    message_type_1 = 'MyMessageType1'
    message_type_2 = 'MyMessageType2'
    message_type_3 = 'MyMessageType3'
    env1 = {
      Langis::MESSAGE_TYPE_KEY => message_type_1
    }
    env2 = {
      Langis::MESSAGE_TYPE_KEY => message_type_1
    }
    env3 = {
      Langis::MESSAGE_TYPE_KEY => message_type_1
    }

    # Set up a mock that won't receive any calls.
    app_mock = mock 'app'
    @middleware = Langis::Middleware::MessageTypeFilter.new app_mock
    @middleware.call(env1)
    @middleware.call(env2)
    @middleware.call(env3)
  end
end
