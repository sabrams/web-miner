require 'rubygems'
require 'rack'
require 'capybara/cucumber'
require 'thin'

Given /^a web world where a GET to "([^\"]*)" returns$/ do |path, content|
  add_to_web_world path, content
end

When /^I go to "([^\"]*)"$/ do |path|
  visit(path)
end

Then /^I should see "([^\"]*)"$/ do |content|
  page.should have_content(content)
end

def add_to_web_world(path, content)
  @web_world ||= Rack::Builder.new
  
  kill_running_server
  @web_world.map path do
    run Proc.new {|env| [200, {"Content-Type" => "text/html"}, content] } #return [200, {"Content-Type" => "text/html"}, ["contentHELLO"]]
  end

  server = Thin::Server.new('0.0.0.0', 8080, @web_world)
  server.silent= true
  server.pid_file= "tmp/pids/thin.pid"
  server.log_file= "log/thin.log"

  @pid = fork {server.start}
  sleep 2 # better way?
  
end

After('@adds_world_wide_web') do |scenario|
  kill_running_server
end

def kill_running_server
  if @pid
    Process.kill("INT", @pid)
    Process.wait(@pid)
    @pid = nil
  end
end
