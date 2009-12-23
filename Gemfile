bundle_path 'vendor/bundler_gems'
bin_path 'vendor/bundler_gems/bin'

clear_sources
source 'http://gemcutter.org'

# Dependencies for base library
gem 'blockenspiel'
gem 'eventmachine'
gem 'hashie'
gem 'json'
gem 'uuid'

only :features do
  gem 'cucumber'
end

only :spec do
  gem 'activerecord', :require_as => 'active_record'
  gem 'activesupport', :require_as => 'active_support'
  gem 'delayed_job'
  gem 'redis'
  gem 'resque'
  gem 'rspec'
  gem 'sqlite3-ruby', :require_as => 'sqlite3'
  gem 'temping'
end
