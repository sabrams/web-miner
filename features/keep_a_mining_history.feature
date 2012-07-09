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
@sandbox3
Scenario: Create an OpenStruct, has a nested failure
  Given the following strategy file "strat_dir/get_event.str":
  """
  new_strategy 'TOP_LEVEL_STRATEGY' do

    is_html
    use_xpath

    create "OpenStruct", ({
      "name" => "//p/text()",
      "link" => "//a/text()"
      }), do |res|
        res.description = digest(res.link, "NESTED_STRATEGY").first.description
      end
  end
  """
  And the following strategy file "strat_dir/get_description.str":
  """
  new_strategy 'NESTED_STRATEGY' do
  
    is_html
    use_xpath
  
    # this could just be a string too, would need new way to deal (or not? can set as attr?)
    create "OpenStruct", ({
      "description" => "//p/text()"
    })
  end 
  """
  And the following command file "command_dir/my_commands.cmd":
  """
    digest "http://localhost:8080/events/102", "TOP_LEVEL_STRATEGY"
  """
  And a world wide web where a GET to "http://localhost:8080/events/102" returns
  """
  <html>
    <body>
      <p>Laid back space rock - udder delight!</p>
      <a>http://localhost:8080/events/102/description</a>
    </body>
  </html>
  """
  And a world wide web where a GET to "http://localhost:8080/events/102/description" returns
  """
  <html>
    <body>
    </body>
  </html>
  """
  When the WebMiner is loaded with strategies from "strat_dir"
  And the WebMiner runs commands from "command_dir"
  Then there should be an OpenStruct with attribute values
    | name        | Laid back space rock - udder delight! |
    | link        | http://localhost:8080/events/102/description |
    | description | |
  And the WebMiner should have a History with attribute values
    | strategy_name | TOP_LEVEL_STRATEGY               |
    | url           | http://localhost:8080/events/102 |
  And that WebMiner History should have a child History with attribute values
    | strategy_name | NESTED_STRATEGY |
    | url           | http://localhost:8080/events/102/description |
  And that WebMiner History should have the warning "Did not find value for '//p/text()'"


