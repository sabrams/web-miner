require 'nokogiri'
require 'capybara'
require 'find'
require 'open-uri'
require 'ostruct'
require 'uri'

module WM

  class Miner

    def strategies
      @strategies
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

    def results
      @results
    end

    def digest(url, strategy_name)
      @results ||= []
      @results << @strategies[strategy_name].run(url, self)
      @results.flatten!
    end

    def get_binding
      return binding()
    end

    #recursively load all strategy files ending with .str or .str.rb. Use directory paths as part of strategy names
    def load_strategies_from(dir_name)
      glob_exprs = [File.join("#{dir_name}**/**", "*.str"), File.join("#{dir_name}**/**", "*.str.rb")]
      glob_exprs.each do |expr|
        Dir.glob(expr).entries.each do |f|
          rel_path = File.split(f)[0]
          # slice twice to cover strategies at top level and nested strategies both
          rel_path.slice! (dir_name)
          rel_path.slice! (File::SEPARATOR)
          rel_path = rel_path.gsub(File::SEPARATOR, ".") + "." if !rel_path.empty?        

          set_relative_path(rel_path)
          eval(File.read(f), get_binding)
        end
      end
    end

    #recursively run all command files ending with .cmd or .cmd.rb
    def run_commands_in(dir_name)
      glob_exprs = [File.join("#{dir_name}**/**", "*.cmd"), File.join("#{dir_name}**/**", "*.cmd.rb")]
      glob_exprs.each do |expr|
        Dir.glob(expr).entries.each {|f| eval(File.read(f))}
      end    
    end
  end
  
  module DSL
    def create(class_name, attr_map, &block)
      @creation_commands << lambda do |results| 
        attrs = {}
        attr_map.each do |name, path|
          attrs[name] = g_v(path)
        end          
        res = eval(class_name).new
        attrs.each {|name, value| res.send("#{name}=", value)}
        block.call(res) if block
        results << res
      end
    end
  
    def create_set(set_path, class_name, attr_map, &block)
      # requires get_nodes
      @creation_commands << lambda do |results|
        multi_object_data = get_nodes(set_path)
        multi_object_data.each do |data|
          attrs = {}
          attr_map.each {|name, path| attrs[name] = get_value(path, data)}
          res = eval(class_name).new
          attrs.each {|name, value| res.send("#{name}=", value)}
          block.call(res) if block
          results << res
        end
      end
    end  
    
    module DocumentTraversal
      module XPath
        def use_xpath
          extend ClassMethods
        end
    
        module ClassMethods
          def get_value(path, input = nil)
            return input.xpath(path).to_s if input
            return @res.xpath(path).to_s
          end

          def get_nodes(path)
            return @res.xpath(path)
          end
        end
      end
    end
  
    module ContentType
      # todo: analysis of content could determine proper parser, but need exceptions (like tendency for rss feeds to simply say xml instead of xml/rss)
      module HTML
        
        def is_html
          extend ClassMethods
        end
        
        def is_html_requiring_page_render
          # extend ClassMethods
          extend PageRenderClassMethods
        end
                
        module ClassMethods
          def update_resource(url)
            @res = Nokogiri::HTML(open(url))
          end
        end
        
        module PageRenderClassMethods
          
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

      module RSS
        
        def is_rss
          extend ClassMethods
        end
        
        module ClassMethods
          def update_resource(url)
            @res = Nokogiri::XML(open(url))
          end
        end
      end
    end
  end
        
  class MinerStrategy
    include DSL
    include DSL::ContentType::HTML
    include DSL::ContentType::RSS
    include DSL::DocumentTraversal::XPath

    def update_resource(url)
      raise NotImplementedError, "The strategy needs to know to proper way to load a resource"
    end

    def get_value(path)
      raise NotImplementedError, "The strategy needs to know to proper way to process a resource"
    end
    
    #What about a cpmposite for these methods where dec is useful? or extend this class
    # hook for decorators
    def g_v(path)
      get_value(path)
    end
    
    # Supporting chained context
    def strategies
      @context.strategies
    end

    def digest(url, strategy_name)
      @context.strategies[strategy_name].run(url, self)
    end

    def initialize(context, my_name, namespace, &block)
      # todo: change this error type, write test        
      @my_name = namespace + my_name
      @context = context
      @creation_commands = []
      instance_eval(&block)
      if !something_to_create?
        msg = "The strategy #{my_name} needs at least one model to create. Use the 'create','create_set','create_map command to declare what models should be created." 
        raise NotImplementedError, msg
      end
    end
    
    def name
      @my_name
    end

    def something_to_create?
      !@creation_commands.empty?
    end

    # no good reason for run_context without the history aspect...
    def run(url, run_context)
      results = []

      unless (url =~ URI::regexp).nil?
        update_resource url
      end
      
      @creation_commands.each {|cmd| cmd.call(results)}

      return results
    end
  end

end

