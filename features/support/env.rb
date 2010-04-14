# Load in all dependent libs using Bundler
require 'bundler'
Bundler.setup
Bundler.require :default, :features

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../../lib')
require 'langis'

require 'spec/expectations'
