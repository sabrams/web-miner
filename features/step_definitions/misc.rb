require 'tempfile'
require 'nokogiri'
require 'open-uri'
require 'CSV'
require 'ruby-debug'

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

######################## DSL

module CommandContext

  # namespace within module to separate this method? (was MinerCommandDsl)
  def digest(url, strategy_name)
    @results ||= []
    @results << @strategies[strategy_name].run(url) if @strategies
  end

  def new_strategy(name, &block)
    @strategies ||= {}
    @strategies[name] = Miner.new(name, &block)
  end
end

module MinerStrategy
  module Http

    module Browser        
      def requires_page_render
        extend ClassMethods
      end

      module ClassMethods
        def update_resource(url)
          @res = "FDLKJHFDLKJHFDLKJHFDLKJFHDLKJDFSH"
        end
        
        def get_value(path)
          return "IS IT ANYTHING YET?"
        end
      end
    end

    # todo: analysis of content could determine proper parser, but need exceptions (like tendency for rss feeds to simply say xml instead of xml/rss)
    module Simple

      def requires_simple_get
        extend ClassMethods
      end

      module ClassMethods
        
        def update_resource(url)
          @res = Nokogiri::HTML(open(url))
        end

        def get_value(path)
          # return @res.xpath('//title').first.text
          return @res.xpath('//title[1]/text()').text
        end
      end
    end
  end
end

class Miner
  include MinerStrategy::Http::Browser
  include MinerStrategy::Http::Simple
  
  def create(class_name, attr_map)
    @classes_to_create_with_mappings ||= {}
    @classes_to_create_with_mappings[class_name] = attr_map
  end

  def update_resource(url)
    raise NotImplementedError, "The strategy needs to know to proper way to load a resource"
  end
  
  def get_value(path)
    raise NotImplementedError, "The strategy needs to know to proper way to load a resource"
  end
  # include Http::SimpleGet

  def initialize(my_name, &block)
    # todo: change this error type, write test    
    @my_name = my_name # useful?
    instance_eval(&block)
    raise NotImplementedError, "The strategy needs at least one model to create. Use the 'create' command to set one." if !@classes_to_create_with_mappings      
  end  

  def run(url)
    results = []
    update_resource url
    @classes_to_create_with_mappings.each do |class_name, attr_map|
      attrs = {}
      attr_map.each {|name, path| attrs[name] = get_value(path)}
      res = eval(class_name).new
      attrs.each {|name, value| res.send("#{name}=", value)}
      results << res
    end
    return results
  end
end

include CommandContext

