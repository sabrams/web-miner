require 'tempfile'
require 'CSV'
require 'ruby-debug'
require 'fileutils'
require 'ostruct'

Given /^a WebMiner instance$/ do
  web_miner
end

Given /^a WebMiner instance configured to keep a history of its mining activities$/ do
  web_miner.keep_history
end

Then /^there should be a strategy called "([^\"]*)"$/ do |expected_name|
  wm = web_miner
  web_miner.strategies.should_not eql nil
  web_miner.strategies[expected_name].should_not eql nil
end

Then /^there should be a history \(expressed in YAML\):$/ do |text|
  web_miner.history.should eq(YAML::load(text.to_s))
end

When /^the WebMiner is loaded with strategies from "([^\"]*)"$/ do |dir_name|
  web_miner.load_strategies_from(dir_name)
end

Given /^the following (?:strategy|command) file "([^\"]*)":$/ do |filename, content|
  create_file(filename, content)
end

When /^the WebMiner runs commands from "([^\"]*)"$/ do |dir|
  web_miner.run_commands_in dir
end

# todo: this belongs in domain, but how to deal with 'global' var?
ATTRIBUTE_VALUES = Transform /with attribute values (.*)$/ do |attribute_values|
  attributes = {}
  begin
    CSV.parse(attribute_values).each do |attribute_value|
      attributes[$1] = $2 if attribute_values =~ /\s*"([^\"]*)"\s*:\s*"([^\"]*)"\s*/
    end
    # just one entry - todo - better way?
  rescue
    attributes[$1] = $2 if attribute_values =~ /\s*"([^\"]*)"\s*:\s*"([^\"]*)"\s*/
  end
  attributes
end

Then (/^there should be an? ([\S]*) with attribute values$/) do |class_name, table|
  attributes = {}
  table.raw.each {|name, value| attributes[name] = value}
  assert_object(class_name, attributes)
end

Then /^there should be a map$/ do |map_string|
  expected_map = eval(map_string)
  found = false
  web_miner.results.each do |result|
    if result.kind_of? Hash
      found = true if result.eql? expected_map
    end
    raise "Map:\n #{expected_map} was not found in the results:\n #{web_miner.results.to_yaml}" if !found
  end
end

# todo this is a mess - use pickle? else clean up in aisle 5
Then (/^there should be an? ([\S]*) (#{ATTRIBUTE_VALUES})$/) do |class_name, attributes|
  assert_object(class_name, attributes)
end

def assert_object(class_name, attributes)
  expected = eval(class_name).new
  attributes.each {|name, val| expected.send("#{name}=", val)}
  found = false
  web_miner.results.each do |result|
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
  raise "object:\n #{expected.to_yaml} was not found in the results:\n#{web_miner.results.to_yaml}" if !found
end

After('@creates_test_directories') do |scenario|
  delete_test_data_directories
end

def web_miner
  if !@web_miner_instance
      @web_miner_instance = WM::Miner.new
  end
  @web_miner_instance
end

def mark_dir_for_deletion_after_test(name)
  @created_dirs ||= []
  @created_dirs << name
end

def create_file(name, content)
  if name.rindex('/')
    path = name[0..name.rindex('/')]
    FileUtils.mkdir_p path
    mark_dir_for_deletion_after_test(path[0..path.index('/')])
  end  
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
