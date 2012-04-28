require 'tempfile'
require 'nokogiri'
require 'open-uri'
require 'CSV'
require 'ruby-debug'
require 'capybara'
require 'fileutils'

Given /^a WebMiner instance$/ do
  web_miner
end

Given /^that WebMiner is configured to load strategies from "([^\"]*)"$/ do |dir_name|
  create_directory(dir_name)
  web_miner.add_strategy_directory(dir_name)
end

Given /^that WebMiner is configured to load commands from "([^\"]*)"$/ do |dir_name|
  create_directory(dir_name)
  web_miner.add_command_directory(dir_name)
end

Given /^the following (?:strategy|command) file "([^\"]*)":$/ do |filename, content|
  create_file(filename, content)
end

When /^the web miner runs its commands$/ do
  web_miner.run
end

# todo: this belongs in domain, but how to deal with 'global' var?
ATTRIBUTE_VALUES = Transform /with attribute values (.*)$/ do |attribute_values|
  attributes = {}
  begin
    CSV.parse(attribute_values)[0].each do |attribute_value|
      attributes[$1] = $2 if attribute_value =~ /\s*"([^\"]*)"\s*:\s*"([^\"]*)"\s*/
    end
    # just one entry - todo - better way?
  rescue
    attributes[$1] = $2 if attribute_values =~ /\s*"([^\"]*)"\s*:\s*"([^\"]*)"\s*/
  end
  attributes
end

# todo this is a mess - use pickle? else clean up in aisle 5
Then (/^there should be an? ([\S]*) (#{ATTRIBUTE_VALUES})$/) do |class_name, attributes|
expected = eval(class_name).new
attributes.each {|name, val| expected.send("#{name}=", val)}
found = false
web_miner.results.each do |arr|
  arr.each do |result|
    next if expected.class != result.class
    attr_eql = true
    attributes.each do |name, val|
      if !result.respond_to?(name)
        attr_eql = false
        break
      end
      if expected.send("#{name}") != result.send("#{name}")
        attr_eql = false
        break
      end
    end
    found = true if attr_eql
  end
end
raise "object was not found in the results" if !found
end

After('@creates_test_directories') do |scenario|
  delete_test_data_directories
end

def web_miner
  @web_miner_instance ||= WebMiner.new
end

def create_directory(name)
  Dir.mkdir(name)
  @created_dirs ||= []
  @created_dirs << name
end

def create_file(name, content)
  File.open(name, 'w') {|f| f.write(content)}
end

def create_temp_file(base_name, content)
  file = Tempfile.new(base_name)
  file.write(content)
  file.close
  return file
end

def delete_test_data_directories  
  @created_dirs.each {|dir| FileUtils.rm_rf dir}
end
