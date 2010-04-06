bundle_path 'vendor/bundler_gems'
bin_path 'vendor/bundler_gems/bin'

clear_sources
source 'http://rubygems.org'

# Dependencies for base library
gem 'blockenspiel'
gem 'eventmachine'

only :features do
  gem 'cucumber'
end

only :spec do
  gem 'delayed_job'
  gem 'redis'
  gem 'resque'
  gem 'rspec'
  gem 'sqlite3-ruby', :require_as => 'sqlite3'
  gem 'temping'
end
