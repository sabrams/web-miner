require 'tempfile'
require 'CSV'
require 'ruby-debug'
require 'fileutils'
require 'ostruct'
require 'json'
require 'json/add/core'

class OpenStruct
   # found online
    def to_map
      map = Hash.new
      self.instance_variable_get("@table").keys.each { |k| map[k] = self.send(k) }
      map
    end

    # found online    
    def to_json(*a)
      to_map.to_json(*a)
    end
    
    def self.from_map(map)
      res = History.new()
      map.keys.each { |k| res.send("#{k}=", map[k])}
      res
    end
end

Given /^a WebMiner instance$/ do
  web_miner
end

Given /^a WebMiner instance configured to keep a history of its mining activities$/ do
  web_miner(true)
end

Then /^there should be a strategy called "([^\"]*)"$/ do |expected_name|
  wm = web_miner
  web_miner.strategies.should_not be_nil
  web_miner.strategies[expected_name].should_not be_nil
end

Then /^there should be a history \(expressed in YAML\):$/ do |text|
  web_miner.history.should eq(YAML::load(text.to_s))
end

Then /^there should be a history \(expressed in JSON\):$/ do |string|
    # todo don't index here check whole array
  web_miner.history[0].should eq(WM::History.from_map(JSON.parse(JSON.pretty_generate web_miner.history)[0]))
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

Then /^the WebMiner should have a History with attribute values$/ do |table|
  history = web_miner.history.first
  assert_object_class_and_attributes_from_table(table, "WM::History", history)
  @last_history = history
end

def assert_object_class_and_attributes_from_table(table, class_name, object)
  attributes = {}
  # table.raw.each {|n, v| puts attributes[n] = v}
  raise "expected type '#{class_name}' but was type: '#{object.class}'" if eval(class_name) != object.class
  attributes.each {|n, v| raise "expected attribute '#{n}' to be '#{v}' but was '#{object.send(n)}'" if !object.send(n).eql? v}
end

Then /^that WebMiner History should have a child History with attribute values$/ do |table|
  # table is a Cucumber::Ast::Table
  child_history = @last_history.children.first
  assert_object_class_and_attributes_from_table(table, "WM::History", child_history)
  @last_history = child_history
end

Then /^that WebMiner History should have the warning "(.*?)"$/ do |warning|
  @last_history.warnings.member?(warning)
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

def web_miner(historic=false)
  if !@web_miner_instance
      @web_miner_instance = historic ? WM::HistoryAwareMiner.new : WM::Miner.new
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
