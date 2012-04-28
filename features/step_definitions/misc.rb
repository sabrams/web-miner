require 'tempfile'
require 'nokogiri'
require 'open-uri'
require 'CSV'
require 'ruby-debug'
require 'capybara'

module WebMiner::Context
  def add_strategy_directory(name)
    create_directory_if_not_exists(name)
    @strat_dirs ||= []
    @strat_dirs << name
  end
  
  def add_command_directory(name)
    create_directory_if_not_exists(name)
    @command_dirs ||= []
    @command_dirs << name
  end
  
  def run
    (@strat_dirs).each do |dir|
      Dir.glob("#{dir}**/*.str").entries.each { |f| eval(File.read(f))}      
    end

    (@command_dirs).each do |dir|
      Dir.glob("#{dir}**/*.cmd").entries.each { |f| eval(File.read(f))}      
    end
  end
end

class WebMinerSession
  include WebMiner
  include WebMiner::Context
end

module DSL
  def create(class_name, attr_map)
    @classes_to_create_with_mappings ||= {}
    @classes_to_create_with_mappings[class_name] = attr_map
  end

  def create_set(set_path, class_name, attr_map)
    @create_set_mappings ||= {}
    @create_set_mappings[set_path] ||= {}
    @create_set_mappings[set_path][class_name] ||= []
    @create_set_mappings[set_path][class_name] << attr_map
  end
      
  def new_strategy(name, &block)
    @strategies ||= {}
    @strategies[name] = Miner.new(name, &block)
  end
  
  # namespace within module to separate this method? (was MinerCommandDsl)
  def digest(url, strategy_name)
    @results ||= []
    @results << @strategies[strategy_name].run(url) if @strategies
  end
  
  def results
    @results
  end
end
include DSL

def web_miner_session
  @web_miner_instance ||= WebMinerSession.new
end

Given /^web\-miner is configured to load strategies from "([^\"]*)"$/ do |dir|
  web_miner_session.add_strategy_directory(dir)
end

Given /^web\-miner is configured to load commands from "([^\"]*)"$/ do |dir|
  web_miner_session.add_command_directory(dir)
end

Given /^the following (?:strategy|command) file "([^\"]*)":$/ do |filename, content|
  create_file(filename, content)
end


# Given /^the following strategy file "([^\"]*)":$/ do |arg1, string|
#   strategy_files << create_temp_file(arg1, string)
# end
# 
# Given /^the following command file:$/ do |string|
#   command_files << create_temp_file('command_file_', string)
# end

# THIS IS ACTUALLY WHERE IT IS FAILING
When /^the commands are run$/ do
  web_miner_session.run
    # (strategy_files|command_files).each do |f|
    #   eval(File.read(f))
    # end
end

# Given(/^a domain class "([^\"]*)" (#{ATTRIBUTES})$/) do |name, attributes|
#   create_domain_class(name, attributes)
# end

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
  web_miner_session.results.each do |arr|
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

def strategy_files
  @strategy_files ||= []
end

def command_files
  @command_files ||= []
end

def create_directory_if_not_exists(name)
  Dir.mkdir(name) unless File.exists?(name)
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


