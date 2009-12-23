module Langis
  module Models

    ##
    # Error thrown when the type specified by a Langis Message does not
    # match the type given in the input hash for a Message#from_hash! merge.
    class MismatchedType < LangisError
    end

    ##
    # Error thrown when a property in the input hash passed Message#form_hash!
    # does not exist in the Message.
    class UnknownFields < LangisError
    end

    ##
    # Superclass for models that want to be pumped through the Langis Engines
    # and Sinks easily. It implements helper methods to handle the common cases
    # for marshalling and unmarshalling, and for the message type (mtype)
    # routing that the Dsl describes.
    #
    # Subclassing this Message class is not required, but it can make things
    # easier.
    class Message < Hashie::Dash
      property :mtype

      ##
      #
      def initialize(*args, &block)
        super(*args, &block)
      end

      ##
      # Executes when this class is inherited so it can set an :mtype property
      # in the child class. Properties are not inherited when subclassed due
      # to Hashie implementation details.
      def self.inherited(subclass)
        subclass.send :property, :mtype
      end  

      ##
      # Merges the values of the source hash into the Message instance,
      # overwriting previous values and setting nil any property not listed
      # in the source hash.
      #
      # @param [Hash] source The source hash from which to copy the values.
      # @option options [Boolean] :ignore_type (false) Don't raise an
      #   error if the source and target message type property are unmatched.
      # @option options [Boolean] :ignore_unknown (false) Don't raise an
      #   error if we encounter a property in the source hash that is
      #   undeclared in this target instance.
      # @raise [MismatchedType] Raised when the source hash's message type
      #   field doesn't match this instances mtype property.
      # @raise [UnknownFields] Raised when we encounter a property in the
      #   source hash that is undeclared in this target instance. The
      #   target Message instance's properties are unchanged when this happens.
      def from_hash!(source={}, options={})
        # Check for the type mismatch, if needed.
        unless options[:ignore_type]
          raise MismatchedType.new unless mtype == source['mtype']
        end

        # Check for unknown properties unless ignored.
        message_properties = self.class.properties - ['mtype']
        unless options[:ignore_unknown]
          unknown_fields = source.keys - message_properties - ['mtype']
          raise UnknownFields.new unless unknown_fields.empty?
        end

        # Now actually set each property value using the accessor methods.
        message_properties.each do |key|
          send "#{key}=", source[key]
        end

        # return itself so we can method chain.
        return self
      end

      ##
      # @return [::Hash] The hash representation of this Message.
      def to_hash(*args)
        # We return the ruby stdlib implementation of hash instead of a Hashie.
        # We coerce the keys into the string type instead of the default
        # symbols. This is for better serialization compatability (json, yaml)
        ::Hash.new.merge!(self.stringify_keys)
      end

      ##
      # Serializes this object to its json representation.
      #
      # @return [String] json string of this object.
      def to_json(*args)
        to_hash.to_json *args
      end

      ##
      # Serializes this object to its yaml representation.
      #
      # @return [String] yaml string of this object.
      def to_yaml(*args)
        to_hash.to_yaml *args
      end

      ##
      # Serializes this object to its to_s representation, which is an alias
      # to #to_json.
      #
      # @return [String] to_s string of this object.
      # @see #to_json
      def to_s(*args)
        to_json *args 
      end
    end

    ##
    # An Event the representation of a time significant observable
    # occurrence in the system. Each event has a type that is inherited from
    # the Message class that when set can signify what actually happened.
    # The event_timestamp property signals the time this even occurred,
    # and the event_uuid is the universally unique id representing this event.
    #
    # Events can be used as is, but mostly one will want to subclass this
    # class to add additional properties that describes.
    class Event < Message
      property :event_uuid
      property :event_timestamp

      ##
      # Constructor that generates the event_uuid and event_timestamp
      # in addition to setting any other properties passed to it.
      def initialize(*args, &block)
        super(*args, &block)

        self.event_uuid = UUID.new.generate
        self.event_timestamp = Time.new.to_f
      end

      ##
      # Executes when this class is inherited so it can set an :mtype,
      # :event_uuid, and :event_timestamp properties in the child class.
      # Properties are not inherited when subclassed due to Hashie
      # implementation details.
      def self.inherited(subclass)
        # Must set the type here because it isn't inherited from Message.
        subclass.send :property, :mtype
        subclass.send :property, :event_uuid
        subclass.send :property, :event_timestamp
      end  
    end
  end
end
