Feature: Record mining history
As a web miner
I want a history recorded for actions taken by my strategies
So that I can learn about what has been happening with dynamically changing web content and respond accordingly

Synopsis:
require miner

web_miner = WM::Miner.new
web_miner.keep_history
web_miner.load_strategies_from("your_strategies")  # each file ends with .str or .str.rb. 
web_miner.run_commands_in("your_commands") # each file ends with .str or .cmd.rb
your_results = web_miner.results
your_history = web_miner.history

Background:
  Given a WebMiner instance configured to keep a history of its mining activities

@adds_world_wide_web
@creates_test_directories
Scenario: Create a simple map, has history of success
  Given the following strategy file "strat_dir/strategy_to_create_simple_map.str":
  
  """
  new_strategy 'MAKE_A_MAP' do

    is_html
    use_xpath
    
    create "OpenStruct", {
      'description' => '//p/text()'
      }
  end
  """
  And the following command file "command_dir/process_book_worm_rss.cmd":
  """
    digest "http://localhost:8080/events/102", "MAKE_A_MAP"
  """
  And a world wide web where a GET to "/events/102" returns
  """
  <html>
    <body>
      <p>An informative description about what is at Bennighans</p>
    </body>
  </html>
  """
  When the WebMiner is loaded with strategies from "strat_dir"
  And the WebMiner runs commands from "command_dir"
  Then there should be an OpenStruct with attribute values
    | description | An informative description about what is at Bennighans |
 
@adds_world_wide_web
@creates_test_directories
@map
Scenario: Create a simple map, has history of failure
  Given the following strategy file "strat_dir/strategy_to_create_simple_map.str":
  """
  new_strategy 'MAKE_A_MAP' do

    is_html
    use_xpath

    create_map ({
      'description' => '//p/text()'
      })
  end
  """
  And the following command file "command_dir/process_book_worm_rss.cmd":
  """
    digest "http://localhost:8080/events/102", "MAKE_A_MAP"
  """
  And a world wide web where a GET to "http://localhost:8080/events/102" returns
  """
  <html>
    <body>
    </body>
  </html>
  """
  When the WebMiner is loaded with strategies from "strat_dir"
  And the WebMiner runs commands from "command_dir"
  Then there should be a history (expressed in YAML):
  """
  --- 
      - !ruby/struct:WM::History
        url: http://localhost:8080/events/102
        strategy_name: MAKE_A_MAP
        children: []
        results: 
          - description:
        warnings:
          - description was not found at //p/text()
  """  
  
@adds_world_wide_web
@creates_test_directories
@map
Scenario: Create a map from nested strategies, all successes
  Given the following strategy file "strat_dir/strategy_to_create_simple_map.str":
  """
  new_strategy 'STRAT_1' do

    is_html
    use_xpath

    create_map ({
      'name' => '//p/text()',
      'link' => '//a/text()'
      }), do |res|
        res['description'] = digest(res['link'], "NESTED_STRATEGY").first['description']
      end
  end
  """
  And the following strategy file "strat_dir/nested_strategy.str":
  """
  new_strategy 'NESTED_STRATEGY' do

    is_html
    use_xpath

    create_map ({
      'description' => '//p/text()',
      })
  end
  """
  And the following command file "command_dir/process_book_worm_rss.cmd":
  """
    digest "http://localhost:8080/events/102", "STRAT_1"
  """
  And a world wide web where a GET to "/events/102" returns
  """
  <html>
    <body>
      <p>Super Event</p>
      <a>http://localhost:8080/events/102/more</a>
    </body>
  </html>
  """
  And a world wide web where a GET to "/events/102/more" returns
  """
  <html>
    <body>
      <p>An informative description about the super event</p>
    </body>
  </html>
  """
  When the WebMiner is loaded with strategies from "strat_dir"
  And the WebMiner runs commands from "command_dir"
  Then there should be a map
  """
  {
    'name' => 'Super Event',
    'link' => 'http://localhost:8080/events/102/more',
    'description' => 'An informative description about the super event'
  }
  """
  And there should be a history (expressed in YAML):
  """
  --- 
      - !ruby/struct:WM::History
        url: http://localhost:8080/events/102
        strategy_name: STRAT_1
        results: 
          - 
            name: Super Event
            link: http://localhost:8080/events/102/more
            description: An informative description about the super event
        children:
          - !ruby/struct:WM::History
            strategy_name: NESTED_STRATEGY
            url: http://localhost:8080/events/102/more
            results:
              - description: An informative description about the super event
            children: []
  """
  
  
  
  
# @adds_world_wide_web
# @creates_test_directories
# Scenario: Create a map from nested strategies, all successes
#   Given the following strategy file "strat_dir/big_one.str":
#   """
#   new_strategy 'BIG_ONE' do
# 
#     is_rss
# 
#     create_set '//rss/events/event', 'Event', {
#       'name' => './/title/text()',
#       'link' => './/more/text()'
#       }, do |res|
#         res.description = digest(res.link, "LITTLE_ONE").first['description']
#       end
#   end
#   """
#   Given the following strategy file "strat_dir/little_one.str":
#   """
#   new_strategy 'LITTLE_ONE' do
# 
#     requires_simple_get
# 
#     create_map ({
#       'description' => '//p/text()'
#       })
#   end
#   """
#   And the following command file "command_dir/process_book_worm_rss.cmd":
#   """
#     digest "http://localhost:8080/event/rss", "BIG_ONE"
#   """
#   And a world wide web where a GET to "/event/rss" returns
#   """
#   <?xml version="1.0" encoding="UTF-8"?>
#     <rss version="0.92">
#      <events>
#       <event>
#         <title>Tonight at Bennighans</title>
#         <more>http://localhost:8080/events/102</more>
#       </event>
#      </events>
#     </rss>
#   </xml>
#   """
#   And a world wide web where a GET to "/events/102" returns
#   """
#   <html>
#     <body>
#       <p>A more informative description about what is at Bennighans</p>
#     </body>
#   </html>
#   """
#   When the WebMiner is loaded with strategies from "strat_dir"
#   And the WebMiner runs commands from "command_dir"
#   Then there should be an Event with attribute values
#     | name        | Tonight at Bennighans |
#     | description | A more informative description about what is at Bennighans |
#   And there should be a history (expressed in YAML):
#   """
#   --- 
#       - !ruby/struct:History
#           strategy_name: BIG_ONE
#           url: http://localhost:8080/event/rss
#           results:
#             - !ruby/object:Event
#               description: A more informative description about what is at Bennighans
#               link: http://localhost:8080/events/102
#               name: Tonight at Bennighans
#           children:
#             - !ruby/struct:History
#               strategy_name: LITTLE_ONE
#               url: http://localhost:8080/events/102
#               results:
#                 - description: A more informative description about what is at Bennighans
#               children: []
#   """

  # BUT DO WE NEED TO LINK THE 'DESCRIPTION' SOURCE BACK TO THE CHILD?