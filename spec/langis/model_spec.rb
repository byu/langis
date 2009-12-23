require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

MY_MESSAGE_TYPE = 'MyMessageType'
MY_DEFAULT_ATTR_SET = 'some default value'
class MyMessage < Langis::Models::Message
  property :mtype, :default => MY_MESSAGE_TYPE
  property :attr_one
  property :attr_set, :default => MY_DEFAULT_ATTR_SET
end

MY_EVENT_TYPE = 'MyEventType'
MY_DEFAULT_ATTR_TWO = 'MyDefaultAttrTwo'
class MyEvent < Langis::Models::Event
  property :mtype, :default => MY_EVENT_TYPE 
  property :attr_two, :default => MY_DEFAULT_ATTR_TWO 
end

describe 'Langis Messages' do
  before :each do
    @message = MyMessage.new
  end

  it 'should have an mtype property' do
    @message.should respond_to :mtype
  end

  it 'should have the mtype property set from default value' do
    @message.mtype.should eql MY_MESSAGE_TYPE
  end

  it 'should have additional attr_one property' do
    @message.should respond_to :attr_one
  end

  it 'should have attr_one property without a default' do
    @message.attr_one.should be_nil
  end

  it 'should convert to hash' do
    hash = @message.to_hash
    hash.should be_a_kind_of Hash
    hash['mtype'].should eql MY_MESSAGE_TYPE
    hash['attr_one'].should be_nil
    hash['attr_set'].should eql MY_DEFAULT_ATTR_SET
  end

  it 'should convert to json' do
    json_string = @message.to_json
    hash = JSON.parse json_string
    hash['mtype'].should eql MY_MESSAGE_TYPE
    hash['attr_one'].should be_nil
    hash['attr_set'].should eql MY_DEFAULT_ATTR_SET
  end

  it 'should have to_s equal json' do
    json_string = @message.to_json
    to_s_string = @message.to_s
    to_s_string.should eql json_string
  end

  it 'should convert to yaml' do
    yaml_string = @message.to_yaml
    hash = YAML::load yaml_string
    hash['mtype'].should eql MY_MESSAGE_TYPE
    hash['attr_one'].should be_nil
    hash['attr_set'].should eql MY_DEFAULT_ATTR_SET
  end

  it 'should load from hash' do
    value = 12345
    source = {
      'mtype' => MY_MESSAGE_TYPE,
      'attr_one' => value
    }
    @message.from_hash! source
    @message.mtype.should eql MY_MESSAGE_TYPE
    @message.attr_one.should eql value
    @message.attr_set.should be_nil
  end

  it 'should raise when mtype is mismatched in #from_hash' do
    begin
      source = {
        'mtype' => MY_MESSAGE_TYPE + 'randomness'
      }
      @message.from_hash! source
      fail 'should have thrown a Langis::Models::MismatchedType'
    rescue Langis::Models::MismatchedType => e
    end
  end

  it 'should not raise on from_hash mtype mismatch with ignore_type option' do
    value = 12345
    source = {
      'mtype' => MY_MESSAGE_TYPE + 'randomness',
      'attr_one' => value
    }
    @message.from_hash! source, :ignore_type => true
    @message.mtype.should eql MY_MESSAGE_TYPE
    @message.attr_one.should eql value
    @message.attr_set.should be_nil
  end

  it 'should raise on unknown fields with #from_hash' do
    begin
      source = {
        'mtype' => MY_MESSAGE_TYPE,
        'some_random_key' => 12345
      }
      @message.from_hash! source
      fail 'should have thrown Langis::Models::UnknownFields'
    rescue Langis::Models::UnknownFields => e
    end
  end

  it 'should not raise on from_hash unknown fields with ignore_unknown' do
    value = 12345
    source = {
      'mtype' => MY_MESSAGE_TYPE,
      'some_random_key' => 12345,
      'attr_one' => value
    }
    @message.from_hash! source, :ignore_unknown => true
    @message.mtype.should eql MY_MESSAGE_TYPE
    @message.attr_one.should eql value
    @message.attr_set.should be_nil
  end
end


describe 'Langis Events' do
  before :each do
    @event = MyEvent.new
  end

  it 'should have an mtype property' do
    @event.should respond_to :mtype
  end

  it 'should have the mtype property set from default value' do
    @event.mtype.should eql MY_EVENT_TYPE
  end

  it 'should have the event_uuid property' do
    @event.should respond_to :event_uuid
  end

  it 'should have the event_timestamp property' do
    @event.should respond_to :event_timestamp
  end

  it 'should have initialized event_uuid' do
    @event.event_uuid.should_not be_nil
  end

  it 'should have initialized event_timestamp' do
    @event.event_timestamp.should_not be_nil
  end

  it 'should have additional attr_two property' do
    @event.should respond_to :attr_two
  end

  it 'should have attr_two property with a default' do
    @event.attr_two.should eql MY_DEFAULT_ATTR_TWO
  end
end
