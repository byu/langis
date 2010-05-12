##
# The base Langis module namespace is used to define global constants for
# this library.
module Langis

  ##
  # The key in the Rack-like environment whose value is the intake
  # that received the message.
  INTAKE_KEY = 'langis.intake'

  ##
  # The key in the Rack-like environment whose value is the message
  # that is "pumped" into a Langis engine.
  MESSAGE_KEY = 'langis.message'
  ##
  # The key in the Rack-like environment whose value is the message
  # type of the message that is pumped into the Langis engine. This is
  # set if the message's responds to the #message_type method.
  MESSAGE_TYPE_KEY = 'langis.message_type'

  ##
  # The key in the Rack-like return headers whose value is the
  # caught exception raised by any middleware or application.
  X_EXCEPTION = 'X-Langis-Exception'
  ##
  # The key in the Rack-like return headers whose value is the name of the
  # middleware that prevented the message from propagating further in the
  # application stack.
  X_FILTERED_BY = 'X-Langis-Filtered-By'
  ##
  # The key in the Rack-like return headers whose value is the message type
  # that was filtered. This is 
  X_FILTERED_TYPE = 'X-Langis-Filtered-Type'

  ##
  # The application stack has completed its function successfully. This
  # return result doesn't signify that the end application of the Rack-like
  # stack was called; middleware may have completed its defined function.
  OK = 200
  ##
  # The status message that states that there was an internal error.
  SERVER_ERROR = 500

  ##
  # The base exception class for all errors that Langis will raise.
  class LangisError < RuntimeError
  end
end

# We include the Langis Library's hard dependencies.
require 'set'
require 'blockenspiel'
require 'eventmachine'

# Now we require the library modules itself.
require 'langis/middleware'
require 'langis/dsl'
require 'langis/engine'
require 'langis/sinks'
require 'langis/rackish'
