# Load in all dependent libs using Bundler
require "#{File.dirname(__FILE__)}/../vendor/bundler_gems/environment"
Bundler.require_env :spec

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'langis'
require 'spec'
require 'spec/autorun'

Spec::Runner.configure do |config|
  
end
