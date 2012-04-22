module WebMiner
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
          # todo: deal with browser, driver options - modularize?
          Capybara.register_driver :selenium do |app|
            Capybara::Selenium::Driver.new(app, :browser => :chrome)
          end
          @session = Capybara::Session.new(:selenium)
          @session.visit(url)
        end
        
        def get_value(path)
          @session.find(:xpath, path).text
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
          return @res.xpath(path).text
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


