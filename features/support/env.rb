# Load in all dependent libs using Bundler
require "#{File.dirname(__FILE__)}/../../vendor/bundler_gems/environment"
Bundler.require_env :features

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../../lib')
require 'langis'

require 'spec/expectations'
