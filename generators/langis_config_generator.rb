class LangisConfigGenerator < Rails::Generator::Base 
  def manifest 
    record do |m| 
      m.template 'langis_config.rb', 'config/initializers/langis_config.rb'
    end
  end
end
