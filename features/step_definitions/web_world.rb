require 'rubygems'
require 'rack'
require 'capybara/cucumber'
require 'thin'

After do |scenario|
  kill_running_server
end

Given /^a domain class "([^\"]*)" that has:$/ do |arg1, table|
  create_domain_class("CAR", ["fds", "fdsd"])
  # table is a Cucumber::Ast::Table
end

Given /^a web world where a GET to "([^"]*)" returns "([^"]*)"$/ do |path, content|
  add_to_web_world path, content
end

When /^I go to "([^\"]*)"$/ do |path|
  visit(path)
end

Then /^I should see "([^\"]*)"$/ do |content|
  page.should have_content(content)
end

def add_to_web_world(path, content)
  if !@web_world
    @web_world ||= Rack::Builder.new
    
    @web_world.map '/' do
      run Proc.new {|env| [200, {"Content-Type" => "text/html"}, "infinity 0.1"] } #return [200, {"Content-Type" => "text/html"}, ["contentHELLO"]]
    end
  end

  kill_running_server
  # sleep 2
  @web_world.map path do
    run Proc.new {|env| [200, {"Content-Type" => "text/html"}, content] } #return [200, {"Content-Type" => "text/html"}, ["contentHELLO"]]
  end

  server = Thin::Server.new('0.0.0.0', 8080, @web_world)
  server.silent= true
  server.pid_file= "tmp/pids/thin.pid"
  server.log_file= "log/thin.log"

  @pid = fork {server.start}
  
end

def kill_running_server
  if @pid
    Process.kill("INT", @pid)
    Process.wait(@pid)
    @pid = nil
  end
end

        