# require 'capybara'
require 'capybara/dsl'

Capybara.run_server = false 
Capybara.current_driver = :selenium 
Capybara.app_host = 'http://localhost:8080'
Capybara.server_boot_timeout = 30 

Capybara.register_driver :selenium do |app|
  Capybara::Selenium::Driver.new(app, :browser => :chrome)
end