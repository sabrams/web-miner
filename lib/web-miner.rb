require 'nokogiri'
require 'open-uri'
require 'capybara'
require 'find'

module DSL
  def create(class_name, attr_map, &block)
    @classes_to_create_with_mappings ||= {}
    @classes_to_create_with_mappings[class_name] = [attr_map, block]
  end
  
  def create_map(map, &block)
    @maps_to_create ||= []
    @maps_to_create << [map, block]
  end

  def create_set(set_path, class_name, attr_map, &block)
    @create_set_mappings ||= {}
    @create_set_mappings[set_path] ||= {}
    @create_set_mappings[set_path][class_name] ||= []
    @create_set_mappings[set_path][class_name] << [attr_map, block]
  end
      
  def new_strategy(name, &block)
    @strategies ||= {}
    # by passing self in, strategies have access to any other strategies loaded by "self" at runtime
    new_strat = MinerStrategy.new(self, name, @relative_path, &block)
    @strategies[new_strat.name] = new_strat
  end
  
  # todo: review this - not thread safe, at least! (but so what)
  def set_relative_path(path)
    @relative_path = path
  end
  
  def strategies
    @strategies
  end
  
  # namespace within module to separate this method? (was MinerCommandDsl)
  def digest(url, strategy_name)
    @results ||= []
    if @strategies && @strategies[strategy_name]
      @results << @strategies[strategy_name].run(url) 
    else
      raise NotImplementedError, "#{strategy_name} strategy does not exist, options are: #{@strategies.keys}"
    end
    @results.flatten!
  end
  
  def results
    @results
  end
end

# class WebMinerBinding
#   include DSL
#   def initialize(relative_path)
#     set_relative_path(relative_path)
#   end
# def get_binding
  # return binding()
# end  
# 
# end

class WebMiner
  include DSL #todo take this include out (split DSL module)  
  
  def get_binding
    return binding()
  end
  
  #recursively load all strategy files ending with .str or .str.rb
  def load_strategies_from(dir_name)
    glob_exprs = [File.join("#{dir_name}**/**", "*.str"), File.join("#{dir_name}**/**", "*.str.rb")]
    glob_exprs.each do |expr|
      Dir.glob(expr).entries.each do |f| 
        relative_path = File.split(f)[0]
        # slice twice to cover strategies at top level and nested strategies both
        relative_path.slice! (dir_name)
        relative_path.slice! (File::SEPARATOR)
        relative_path = relative_path.gsub(File::SEPARATOR, ".") + "." if !relative_path.empty?        
        
        set_relative_path(relative_path)
        eval(File.read(f), get_binding)
      end
    end
  end

  #recursively run all command files ending with .cmd or .cmd.rb
  def run_commands_in(dir_name)
    glob_exprs = [File.join("#{dir_name}**/**", "*.cmd"), File.join("#{dir_name}**/**", "*.cmd.rb")]
    glob_exprs.each do |expr|
      Dir.glob(expr).entries.each { |f| eval(File.read(f))}      
    end    
  end
end

module MinerStrategyTemplates
  module Http
    
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
          return @res.xpath(path).to_s
        end

        def get_nodes(path)
          return @res.xpath(path)
        end

        def get_value_from(input, path)
          return input.xpath(path).to_s
        end
      end
    end

    
    module RSS
      def is_rss
        extend ClassMethods
      end
      
      module ClassMethods
        include Simple::ClassMethods
      end
    end
    module Browser
      def requires_page_render
        extend ClassMethods
        
        def update_resource(url)
          @res = Nokogiri::XML(open(url))
        end
      end

      module ClassMethods
        include Simple::ClassMethods
        def update_resource(url)
          # todo: deal with browser, driver options - modularize?
          Capybara.register_driver :selenium do |app|
            Capybara::Selenium::Driver.new(app, :browser => :chrome)
          end
          session = Capybara::Session.new(:selenium)
          session.visit(url)
          @res = Nokogiri::HTML(session.body)
        end
      end
    end

  end
end

class MinerStrategy
  include MinerStrategyTemplates::Http::Browser
  include MinerStrategyTemplates::Http::Simple
  include MinerStrategyTemplates::Http::RSS
  include DSL

  def update_resource(url)
    raise NotImplementedError, "The strategy needs to know to proper way to load a resource"
  end

  def get_value(path)
    raise NotImplementedError, "The strategy needs to know to proper way to load a resource"
  end

  #This will always return an array of results objects
  def run_strategy(url, strategy_name)
    @context.strategies[strategy_name].run(url) if @context.strategies
  end
  
  def initialize(context, my_name, namespace, &block)
    # todo: change this error type, write test        
    @my_name = namespace + my_name
    @context = context
    instance_eval(&block)
    raise NotImplementedError, "The strategy needs at least one model to create. Use the 'create' or 'create_set' command to declare what models should be created." if !something_to_create?
  end  
  
  def name
    @my_name
  end

  def something_to_create?
    @classes_to_create_with_mappings || @create_set_mappings || @maps_to_create
  end

  def run(url)
    results = []
    update_resource url

    # todo: bring these in to some component of DSL, not general run
    # create map
    if @maps_to_create
      @maps_to_create.each do |map, block|
        map.each {|k, path| map[k] = get_value(path)}
        block.call(map) if block
        results << map
      end
    end
    # create
    if @classes_to_create_with_mappings
      @classes_to_create_with_mappings.each do |class_name, attr_map_and_block|
        attrs = {}
        attr_map_and_block.first.each {|name, path| attrs[name] = get_value(path)}
        res = eval(class_name).new
        attrs.each {|name, value| res.send("#{name}=", value)}
        attr_map_and_block.last.call(res) if attr_map_and_block.last
        results << res
      end
    end
    # create_set
    if @create_set_mappings
      @create_set_mappings.each do |set_path, mappings|
        mappings.each do |class_name, attr_map_array|
          attr_map_array.each do |attr_map_and_block|
            attrs = {}
            multi_object_data = get_nodes(set_path)
            multi_object_data.each do |object_data|
              attrs = {}
              attr_map_and_block.first.each do |name, path|
                attrs[name] = get_value_from(object_data, path)
              end
              res = eval(class_name).new
              attrs.each {|name, value| res.send("#{name}=", value)}
              attr_map_and_block.last.call(res) if attr_map_and_block.last
              results << res
            end
          end
        end
      end
    end
    return results
  end
end


