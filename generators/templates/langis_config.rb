# This file requires modifications to be run in your rails app.

# Create the LangisEngine for the rails app to pump messages into.
LangisEngine = (lambda {
  # Define the routes
  config = Langis::Dsl.langis_plumbing do
    intake :default do
      flow_to :default
    end

    for_sink :default do
    end

    check_valve do
    end
  end

  # Create an example success callback channel.
  success_channel = EM::Channel.new
  success_channel.subscribe(proc do |msg|
    # TODO: Implement your own success handler.
    # Rails.logger.info "Success: #{msg.inspect}"
  end)

  # Create an example error callback channel.
  error_channel = EM::Channel.new
  error_channel.subscribe(proc do |msg|
    # TODO: Implement your own error handler.
    # Rails.logger.warn "Error: #{msg.inspect}"
  end)

  # Create and return the actual EventMachine based Langis Engine.
  return Langis::Engine::EventMachineEngine.new(
    config.build_pipes,
    :success_channel => success_channel,
    :error_channel => error_channel)
}).call

# Start up the EventMachine reactor here if need be.
# Note that starting up the EventMachine is different depending on what
# web server you are running in.
#Thread.new do
#  EM.run
#end
