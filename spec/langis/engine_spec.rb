require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

# We want an ipmlementation of EventMachine::Channel without EventMachine
# to run inside these tests.
class NonEvmChannel
  def initialize
    @list = []
  end

  def subscribe(*args, &block)
    @list << args[0]
  end

  def push(*args)
    @list.each do |subscriber|
      subscriber.call *args
    end
  end
end

# We need EventMachine defer without EventMachine.
class EventMachineStub
  def self.defer(op = nil, callback = nil)
    if callback
      callback.call(op.call)
    else
      op.call
    end
  end
end

describe 'EventMachineEngine' do
  it 'should pump a message to one intake' do
    my_message = 'pingy pong'
    env = {
      Langis::MESSAGE_KEY => my_message,
      Langis::INTAKE_KEY => 'intake_1'
    }
    service = mock 'service'
    service.should_receive(:call).with(env).once
    config = Langis::Dsl.langis_plumbing do
      intake :intake_1, :intake_2 do
        flow_to :sink_1
      end
      for_sink :sink_1 do
        run service
      end
    end
    engine = Langis::Engine::EventMachineEngine.new(config.build_pipes,
      :evm => EventMachineStub,
      :evm_channel => NonEvmChannel)
    engine.pump my_message, :intake_1
  end

  it 'should pump a message to multiple intakes' do
    my_message = 'pingy pong'
    env1 = {
      Langis::MESSAGE_KEY => my_message,
      Langis::INTAKE_KEY => 'intake_1'
    }
    env2 = {
      Langis::MESSAGE_KEY => my_message,
      Langis::INTAKE_KEY => 'intake_2'
    }
    service = mock 'service'
    service.should_receive(:call).with(env1).once
    service.should_receive(:call).with(env2).once
    config = Langis::Dsl.langis_plumbing do
      intake :intake_1, :intake_2 do
        flow_to :sink_1
      end
      for_sink :sink_1 do
        run service
      end
    end
    engine = Langis::Engine::EventMachineEngine.new(config.build_pipes,
      :evm => EventMachineStub,
      :evm_channel => NonEvmChannel)
    engine.pump my_message, :intake_1, :intake_2
  end

  it 'should handle success callbacks' do
    my_message = 'pingy pong'
    return_message = [200, {}, ['']]
    env = {
      Langis::MESSAGE_KEY => my_message,
      Langis::INTAKE_KEY => 'intake_1'
    }
    service = mock 'service'
    service.should_receive(:call).with(env).once.and_return(return_message)
    success_channel = mock 'success channel'
    success_channel.should_receive(:push).with(return_message).once
    config = Langis::Dsl.langis_plumbing do
      intake :intake_1, :intake_2 do
        flow_to :sink_1
      end
      for_sink :sink_1 do
        run service
      end
    end
    engine = Langis::Engine::EventMachineEngine.new(config.build_pipes,
      :evm => EventMachineStub,
      :evm_channel => NonEvmChannel,
      :success_channel => success_channel)
    engine.pump my_message, :intake_1
  end

  it 'should handle error callback' do
    my_message = 'pingy pong'
    my_error = RuntimeError.new
    env = {
      Langis::MESSAGE_KEY => my_message,
      Langis::INTAKE_KEY => 'intake_1'
    }
    error_result = [
      Langis::SERVER_ERROR,
      {
        Langis::MESSAGE_KEY => my_message,
        Langis::INTAKE_KEY => 'intake_1',
        Langis::X_EXCEPTION => my_error
      },
      ['']
    ]
    service = mock 'service'
    service.should_receive(:call).with(env).once.and_raise(my_error)
    error_channel = mock 'error channel'
    error_channel.should_receive(:push).with(error_result).once
    config = Langis::Dsl.langis_plumbing do
      intake :intake_1, :intake_2 do
        flow_to :sink_1
      end
      for_sink :sink_1 do
        run service
      end
    end
    engine = Langis::Engine::EventMachineEngine.new(config.build_pipes,
      :evm => EventMachineStub,
      :evm_channel => NonEvmChannel,
      :error_channel => error_channel)
    engine.pump my_message, :intake_1
  end

  it 'should set the mtype field if the message can return an mtype' do
    my_type = 'MyMessageType'
    my_message = mock 'message'
    my_message.should_receive(:respond_to?).with(:mtype).once.and_return true
    my_message.should_receive(:mtype).once.and_return(my_type)
    env = {
      Langis::MESSAGE_TYPE_KEY => my_type,
      Langis::MESSAGE_KEY => my_message,
      Langis::INTAKE_KEY => 'intake_1'
    }
    service = mock 'service'
    service.should_receive(:call).with(env)
    config = Langis::Dsl.langis_plumbing do
      intake :intake_1, :intake_2 do
        flow_to :sink_1
      end
      for_sink :sink_1 do
        run service
      end
    end
    engine = Langis::Engine::EventMachineEngine.new(config.build_pipes,
      :evm => EventMachineStub,
      :evm_channel => NonEvmChannel)
    engine.pump my_message, :intake_1
  end
end
