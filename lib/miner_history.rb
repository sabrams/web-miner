require 'forwardable'

module WM
  
  History = Struct.new(:strategy_name, :url, :results, :children, :warnings)
  
  # we can't decorate methods that are called within the class - 
  class MinerStrategyForHistoryDecorator < MinerStrategy
    
    def g_v(path)
      res = super(path)
      @history.warnings << "Did not find value for '#{path}'" if res.nil? || (res.respond_to?('empty?') && res.empty?)
      res
    end
    
    def is_root?
      false
    end
    
    def history
      @history
    end
    
    def run(url, context)
      @history = History.new
      @history.warnings = []
      @history.children = []
      @history.strategy_name = name()
      @history.url = url
      if context.is_root?
        context.history << @history
      else
        context.history.children << @history
      end
      results = super(url, context)
      @history.results = results
      results
    end
  end
  
  class HistoryAwareMiner < Miner
    
    
    def initialize()
      @m_history = []
    end
      
    def history
      @m_history
    end
    
    def is_root?
      true
    end
    
    def new_strategy(name, &block)
      @strategies ||= {}
      # by passing self in, strategies have access to any other strategies loaded by "self" at runtime
      # delegate_strat = MinerStrategyForHistoryDecorator.new(self, name, @relative_path, &block)
      # new_strat = MinerStrategyHistoryDecorator.new(delegate_strat)
      new_strat = MinerStrategyForHistoryDecorator.new(self, name, @relative_path, &block)
      # @m_history << new_strat.history
      @strategies[new_strat.name] = new_strat
    end
  end
  
end
  