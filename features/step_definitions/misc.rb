require 'tempfile'
require 'nokogiri'
require 'open-uri'
require 'CSV'
require 'ruby-debug'
require 'capybara'

include WebMiner

Given /^the following strategy file "([^\"]*)":$/ do |arg1, string|
  strategy_files << create_temp_file(arg1, string)
end

Given /^the following command file:$/ do |string|
  command_files << create_temp_file('command_file_', string)
end

When /^the commands are run$/ do
  (strategy_files|command_files).each do |f|
    eval(File.read(f))
  end
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
  @results.each do |arr|
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

def create_temp_file(base_name, content)
  file = Tempfile.new(base_name)
  file.write(content)
  file.close
  return file
end


