require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = 'langis'
    gem.summary = %Q{
      Langis is a Rack inspired publish-subscribe system for Ruby.}
    gem.description = %Q{
      Langis is a Rack inspired publish-subscribe system for Ruby.
      It has flexible message routing and message handling using a custom
      Domain Specific Language and a Rack-inspired message handler framework.
      This can give Rails applications better (and decoupled) visibility
      and management of the background processes it creates (or executes)
      in response to its actions (in controllers or models).
    }
    gem.email = 'benjaminlyu@gmail.com'
    gem.homepage = 'http://github.com/byu/langis'
    gem.authors = ['Benjamin Yu']

    # NOTE: Following development dependencies are commented out here
    # because we include them in the Gemfile bundle. If we included them
    # here, then they are required to be installed in the base rubygems
    # repository instead of the Bundler's installation path.
    #gem.add_development_dependency 'delayed_job'
    #gem.add_development_dependency 'redis'
    #gem.add_development_dependency 'resque'
    gem.add_development_dependency 'rspec', '>= 1.2.9'
    #gem.add_development_dependency 'sqlite3-ruby'
    #gem.add_development_dependency 'temping'
    gem.add_development_dependency 'yard'

    gem.add_dependency 'blockenspiel'
    gem.add_dependency 'eventmachine'

    gem.files = FileList[
      'lib/**/*.rb',
      'bin/*',
      '[A-Z]*',
      'spec/**/*',
      'features/**/*',
      'generators/**/*'].to_a
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts 'Jeweler (or a dependency) not available. Install it with: gem install jeweler'
end

begin
  require 'yard'
  YARD::Rake::YardocTask.new
rescue LoadError
  task :yardoc do
    abort 'YARD is not available. In order to run yardoc, you must: sudo gem install yard'
  end
end
