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
    @strategies[name] = MinerStrategy.new(name, &block)
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

class WebMiner
  include DSL
  
  def add_strategy_directory(name)
    @strat_dirs ||= []
    @strat_dirs << name
  end

  def add_command_directory(name)
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

    module Browser
      def requires_page_render
        extend ClassMethods
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
  include DSL

  def update_resource(url)
    raise NotImplementedError, "The strategy needs to know to proper way to load a resource"
  end

  def get_value(path)
    raise NotImplementedError, "The strategy needs to know to proper way to load a resource"
  end

  def initialize(my_name, &block)
    # todo: change this error type, write test        
    @my_name = my_name # useful?
    instance_eval(&block)
    raise NotImplementedError, "The strategy needs at least one model to create. Use the 'create' or 'create_set' command to declare what models should be created." if !something_to_create?
  end  

  def something_to_create?
    @classes_to_create_with_mappings || @create_set_mappings     
  end

  def run(url)
    results = []
    update_resource url

    # todo: bring these in to some component of DSL, not general run
    # create
    if @classes_to_create_with_mappings
      @classes_to_create_with_mappings.each do |class_name, attr_map|
        attrs = {}
        attr_map.each {|name, path| attrs[name] = get_value(path)}
        res = eval(class_name).new
        attrs.each {|name, value| res.send("#{name}=", value)}
        results << res
      end
    end
    # create_set
    if @create_set_mappings
      @create_set_mappings.each do |set_path, mappings|
        mappings.each do |class_name, attr_map_array|
          attr_map_array.each do |attr_map|
            attrs = {}
            multi_object_data = get_nodes(set_path)
            multi_object_data.each do |object_data|
              attrs = {}
              attr_map.each do |name, path|
                attrs[name] = get_value_from(object_data, path)
              end
              res = eval(class_name).new
              attrs.each {|name, value| res.send("#{name}=", value)}
              results << res
            end
          end
        end
      end
    end
    return results
  end
end


