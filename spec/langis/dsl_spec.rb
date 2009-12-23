require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

# Just a plain old middleware class for these specs
class TestMiddleware
  def initialize(app, service, value)
    @app = app
    @service = service
    @value = value
  end
  def call(env)
    @service.my_expected_method(@value)
    @app.call(env)
  end
end

describe 'Langis Dsl Config' do
  it 'should handle an empty dsl block' do
    config = Langis::Dsl.langis_plumbing do
    end
    pipes = config.build_pipes
    pipes.should be_empty
  end

  it 'should handle raise error on missing sink' do
    begin
      config = Langis::Dsl.langis_plumbing do
        intake :intake_1 do
          flow_to :non_existent_sink
        end
      end
      pipes = config.build_pipes
      fail 'did not raise PipingConfigError'
    rescue Langis::Dsl::PipingConfigError => e
    end
  end

  it 'should create a single intake with a single app' do
    config = Langis::Dsl.langis_plumbing do
      intake :intake_1 do
        flow_to :sink_1
      end
      for_sink :sink_1 do
      end
    end
    pipes = config.build_pipes
    pipes.size.should eql 1
    pipes['intake_1'].size.should eql 1
  end

  it 'should create one intake with a three apps' do
    config = Langis::Dsl.langis_plumbing do
      intake :intake_1 do
        flow_to :sink_1
        flow_to :sink_2, :sink_3
      end
      for_sink :sink_1 do
      end
      for_sink :sink_2 do
      end
      for_sink :sink_3 do
      end
    end
    pipes = config.build_pipes
    pipes.size.should eql 1
    pipes['intake_1'].size.should eql 3
  end

  it 'should create ignore unreferenced sinks, executing proper sink' do
    env = {
      :envkey => 1
    }

    # Create 3 mocks where 1 is called and the other 2 are uncalled.
    service1= mock 'service1'
    service2 = mock 'service2'
    service2.should_receive(:call).with(env).once
    service3 = mock 'service3'

    # Now create the config.
    config = Langis::Dsl.langis_plumbing do
      intake :intake_1 do
        flow_to :sink_2
      end
      for_sink :sink_1 do
        run service1
      end
      for_sink :sink_2 do
        run service2
      end
      for_sink :sink_3 do
        run service3
      end
    end

    # build the pipes and run the test.
    pipes = config.build_pipes
    pipes.size.should eql 1
    pipes['intake_1'].size.should eql 1
    pipes['intake_1'][0].call(env)
  end

  it 'should create two intakes with a three apps each' do
    config = Langis::Dsl.langis_plumbing do
      intake :intake_1, :intake_2 do
        flow_to :sink_1
        flow_to :sink_2, :sink_3
      end
      for_sink :sink_1 do
      end
      for_sink :sink_2 do
      end
      for_sink :sink_3 do
      end
    end
    pipes = config.build_pipes
    pipes.size.should eql 2
    pipes['intake_1'].size.should eql 3
    pipes['intake_2'].size.should eql 3
  end

  it 'should have sinks that run middleware in order' do
    env = {}
    first_value = 1
    second_value = 2
    service = mock 'middleware_service'
    service.should_receive(:my_expected_method).once.with(first_value).ordered
    service.should_receive(:my_expected_method).once.with(second_value).ordered
    config = Langis::Dsl.langis_plumbing do
      intake :intake_1 do
        flow_to :sink_1
      end
      for_sink :sink_1 do
        use TestMiddleware, service, first_value
        use TestMiddleware, service, second_value
      end
    end
    pipes = config.build_pipes
    pipes['intake_1'].size.should eql 1
    pipes['intake_1'][0].call(env)
  end

  it 'should have sinks that run middleware in order, with a final app' do
    env = {}
    first_value = 1
    second_value = 2
    service = mock 'middleware_service'
    service.should_receive(:my_expected_method).once.with(first_value).ordered
    service.should_receive(:my_expected_method).once.with(second_value).ordered
    service.should_receive(:call).once.with(an_instance_of(Hash))
    config = Langis::Dsl.langis_plumbing do
      intake :intake_1 do
        flow_to :sink_1
      end
      for_sink :sink_1 do
        use TestMiddleware, service, first_value
        use TestMiddleware, service, second_value
        run service
      end
    end
    pipes = config.build_pipes
    pipes['intake_1'].size.should eql 1
    pipes['intake_1'][0].call(env)
  end

  it 'should have separate sinks that run middleware and app in order' do
    env = {}
    first_value = 1
    second_value = 2
    service1 = mock 'middleware_service1'
    service1.should_receive(:my_expected_method).once.with(first_value).ordered
    service1.should_receive(:my_expected_method).once.with(second_value).ordered
    service1.should_receive(:call).once.with(an_instance_of(Hash))
    service2 = mock 'middleware_service2'
    service2.should_receive(:my_expected_method).once.with(first_value).ordered
    service2.should_receive(:my_expected_method).once.with(second_value).ordered
    service2.should_receive(:call).once.with(an_instance_of(Hash))
    config = Langis::Dsl.langis_plumbing do
      intake :intake_1 do
        flow_to :sink_1, :sink_2
      end
      for_sink :sink_1 do
        use TestMiddleware, service1, first_value
        use TestMiddleware, service1, second_value
        run service1
      end
      for_sink :sink_2 do
        use TestMiddleware, service2, first_value
        use TestMiddleware, service2, second_value
        run service2
      end
    end
    pipes = config.build_pipes
    pipes['intake_1'].size.should eql 2
    pipes['intake_1'][0].call(env)
    pipes['intake_1'][1].call(env)
  end

  it 'should allow message through with a set type' do
    message_type = 'MyMessageType'
    message_type_2 = 'MyMessageType2'
    env = {
      Langis::MESSAGE_TYPE_KEY => message_type
    }
    service = mock 'middleware_service'
    service.should_receive(:call).once.with(
      hash_including(Langis::MESSAGE_TYPE_KEY => message_type))
    config = Langis::Dsl.langis_plumbing do
      intake :intake_1 do
        flow_to :sink_1, :when => message_type
      end
      for_sink :sink_1 do
        run service
      end
    end
    pipes = config.build_pipes
    pipes['intake_1'].size.should eql 1
    pipes['intake_1'][0].call(env)
  end

  it 'should allow message through a filter looking for a list of types' do
    message_type = 'MyMessageType'
    message_type_2 = 'MyMessageType2'
    env = {
      Langis::MESSAGE_TYPE_KEY => message_type
    }
    service = mock 'middleware_service'
    service.should_receive(:call).once.with(
      hash_including(Langis::MESSAGE_TYPE_KEY => message_type))
    config = Langis::Dsl.langis_plumbing do
      intake :intake_1 do
        flow_to :sink_1, :when => [message_type.to_sym, message_type_2.to_sym]
      end
      for_sink :sink_1 do
        run service
      end
    end
    pipes = config.build_pipes
    pipes['intake_1'].size.should eql 1
    pipes['intake_1'][0].call(env)
  end

  it 'should filter by message types given by array' do
    message_type = 'MyMessageType'
    message_type_2 = 'MyMessageType2'
    env = {
      Langis::MESSAGE_TYPE_KEY => 'NotTheRightType'
    }
    # Service should receive zero calls.
    service = mock 'middleware_service'
    config = Langis::Dsl.langis_plumbing do
      intake :intake_1 do
        flow_to :sink_1, :when => [message_type.to_sym, message_type_2.to_sym]
      end
      for_sink :sink_1 do
        run service
      end
    end
    pipes = config.build_pipes
    pipes['intake_1'].size.should eql 1
    pipes['intake_1'][0].call(env)
  end

  it 'should run the check_valve middleware for all routes' do
    value = 'TestMiddlewareValue'
    env = {
      :envkey => 1
    }
    service1= mock 'service1'
    service1.should_receive(:call).with(env).once
    service2 = mock 'service2'
    service2.should_receive(:call).with(env).once
    service3 = mock 'service3'
    service3.should_receive(:call).with(env).once
    check_valve_service = mock 'check_valve'
    check_valve_service.
      should_receive(:my_expected_method).with(value).exactly(3).times
    config = Langis::Dsl.langis_plumbing do
      intake :intake_1 do
        flow_to :sink_1, :sink_2, :sink_3
      end
      for_sink :sink_1 do
        run service1
      end
      for_sink :sink_2 do
        run service2
      end
      for_sink :sink_3 do
        run service3
      end
      check_valve do
        use TestMiddleware, check_valve_service, value
      end
    end
    pipes = config.build_pipes
    pipes.size.should eql 1
    pipes['intake_1'].size.should eql 3
    pipes['intake_1'].each do |sink|
      sink.call(env)
    end
  end
end
