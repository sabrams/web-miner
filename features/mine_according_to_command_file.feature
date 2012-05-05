Feature: 
In order to allow a quick creation of a web mining strategy
I want to be able to run command files writen in a DSL 

Synopsis:
require web-miner

web_miner = WebMiner.new
web_miner.load_strategies_from("your_strategies")  # each file ends with .str or .str.rb. 
web_miner.run_commands_in("your_commands") # each file ends with .str or .cmd.rb

your_results = web_miner.results

Background:
  Given a domain class "Event" with attributes "name", "description", "link"
  And a WebMiner instance
    
@adds_world_wide_web
@creates_test_directories
Scenario: Process a simple HTML document, creating a custom object from a strategy using XPath navigation
  Given the following strategy file "strat_dir/local_paper.str":
  """
  new_strategy "UPCOMING_EVENT_PAGE" do
    
    requires_simple_get
    
    create "Event", {
      "name" => "//title/text()"
      }
  end

  """
  And the following command file "command_dir/process_local_paper.cmd":
  """
  digest "http://localhost:8080/newspaper/this_weekend/article1", "UPCOMING_EVENT_PAGE"
  """
  # LOCAL_NEWSPAPER.UPCOMING_EVENT_PAGE
  And a world wide web where a GET to "/newspaper/this_weekend/article1" returns
  """
  <html>
    <body>
      <title>Laid back space rock - udder delight!</title>
    </body>
  </html>
  """
  # digest {
  #   "http://localhost:8080/newspaper/this_weekend/article1" => "UPCOMING_EVENT_PAGE"
  #   }
  When the WebMiner is loaded with strategies from "strat_dir"
  And the WebMiner runs commands from "command_dir"
  Then there should be an Event with attribute values "name": "Laid back space rock - udder delight!"
  
@adds_world_wide_web
@creates_test_directories
Scenario: Sometimes a strategy needs access to the DOM after resource rendered by a browser. This can be done by specifying "requires_page_render"
  This scenario shows how to process a DOM after it is manipulated by document-embedded Javascript on page load.
  Given the following strategy file "strat_dir/local_paper.str":
  """
  new_strategy "EVENT_PAGE_WITH_WEIRD_JAVASCRIPT_ACTIONS" do

    requires_page_render

    create "Event", {
      "name" => "//title/text()"
    }
  end
  """
  And the following command file "command_dir/process_local_paper.cmd":
  """
  digest "http://localhost:8080/event/page/with/javascript/manipulation", "EVENT_PAGE_WITH_WEIRD_JAVASCRIPT_ACTIONS"
  """
  And a world wide web where a GET to "/event/page/with/javascript/manipulation" returns
  """
  <script type='text/javascript'>
  function add_title(txt){
    document.title = txt;
  }
  </script>
  <html>
    <body onload="add_title('The Funky Monkeys, Tonight!');">
      <title></title>
    </body>
  </html>
  """
  When the WebMiner is loaded with strategies from "strat_dir"
  And the WebMiner runs commands from "command_dir"
  Then there should be an Event with attribute values "name": "The Funky Monkeys, Tonight!"
  
@adds_world_wide_web
@creates_test_directories
Scenario: RSS feed with list of elements need individual processing
  Given the following strategy file "strat_dir/book_worm_rss.str":
  """
  new_strategy 'BOOK_WORM_RSS' do
    
    is_rss
    
    create_set '//rss/events/event', 'Event', {
      'name' => './/title/text()'
      }
  end
  """
  And the following command file "command_dir/process_book_worm_rss.cmd":
  """
    digest "http://localhost:8080/book/worm/rss", "BOOK_WORM_RSS"
  """
  And a world wide web where a GET to "/book/worm/rss" returns
  """
  <?xml version="1.0" encoding="UTF-8"?>
    <rss version="0.92">
     <events>
      <event>
        <title>Tonight at Bennighans</title>
      </event>
      <event>
        <title>Tonight at Joes</title>
      </event>
     </events>
    </rss>
  </xml>
  """
  When the WebMiner is loaded with strategies from "strat_dir"
  And the WebMiner runs commands from "command_dir"
  Then there should be an Event with attribute values "name": "Tonight at Bennighans"
  And there should be an Event with attribute values "name": "Tonight at Joes"

@adds_world_wide_web
@creates_test_directories
Scenario: Create a simple map (no predefined classes to populate)
  Given the following strategy file "strat_dir/strategy_to_create_simple_map.str":
  """
  new_strategy 'MAKE_A_MAP' do

    requires_simple_get

    create_map ({
      'description' => '//p/text()'
      })
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
  Then there should be a map
  """
  {
    'description' => 'An informative description about what is at Bennighans'
  }
  """

@adds_world_wide_web
@creates_test_directories
@sandbox
Scenario: Sometimes understanding the relationships of resources (through links) is necesary.
  This scenario populates a set of elements while following references
Given the following strategy file "strat_dir/big_one.str":
"""
new_strategy 'BIG_ONE' do

  is_rss

  create_set '//rss/events/event', 'Event', {
    'name' => './/title/text()',
    'link' => './/more/text()'
    }, do |res|
      res.description = digest(res.link, "LITTLE_ONE").first['description']
    end
end
"""
Given the following strategy file "strat_dir/little_one.str":
"""
new_strategy 'LITTLE_ONE' do

  requires_simple_get

  create_map ({
    'description' => '//p/text()'
    })
end
"""
And the following command file "command_dir/process_book_worm_rss.cmd":
"""
  digest "http://localhost:8080/event/rss", "BIG_ONE"
"""
And a world wide web where a GET to "/event/rss" returns
"""
<?xml version="1.0" encoding="UTF-8"?>
  <rss version="0.92">
   <events>
    <event>
      <title>Tonight at Bennighans</title>
      <more>http://localhost:8080/events/102</more>
    </event>
   </events>
  </rss>
</xml>
"""
And a world wide web where a GET to "/events/102" returns
"""
<html>
  <body>
    <p>A more informative description about what is at Bennighans</p>
  </body>
</html>
"""
When the WebMiner is loaded with strategies from "strat_dir"
And the WebMiner runs commands from "command_dir"
Then there should be an Event with attribute values
  | name        | Tonight at Bennighans |
  | description | A more informative description about what is at Bennighans |

@creates_test_directories
Scenario: Strategies can be organized by directory tree. When this is done, these strategies are named according to the directory layout. 
  This scenario shows nested strategy files in the strategy directory (happens to be using .str.rb extension)
Given the following strategy file "strat_dir/SUBDIR1/SUBDIR2/some_strat.str.rb":
"""
new_strategy 'NESTED_NAME' do

  create 'PlaceHolderSoStratCreationIsntRejected', {
    }
end
"""
When the WebMiner is loaded with strategies from "strat_dir"
Then there should be a strategy called "SUBDIR1.SUBDIR2.NESTED_NAME"

# Then there should be an Event with attribute values "name": "Tonight at Bennighans","description": "A more informative description about what is at Bennighans"



  






# @adds_world_wide_web
# Scenario: 
#   Given a world wide web where a GET to "/newspaper/this_weekend/article1" returns
#   """
#    "HELLO WORLD"
#   """
#   When I go to "/newspaper/this_weekend/article1"
#   Then I should see "YOYOYO"
  
# Scenario: Basic case
#   Given the following strategy file "local_newspaper_upcoming_event.ps":
#   """
#   create event where:
#     name = /path/to/event/@string
#   """
#   And the following command file:
#   """
#   digest http://localhost:8080/newspaper/this_weekend/article1 using local_newspaper_upcoming_event.ps
#   
#   """
#   And a world wide web where a GET to "/newspaper/this_weekend/article1" returns "HELLO WORLD"
#   Then there should be an Event with:
#   | name  | Laid back space rock - udder delight! |
#   | bands | 0 | band...
#   And there should be an event...?>
  
  
# Background:
  # Given a domain class Band that has:
  # | name  |
  # | genre |
  # And a domain class Event that has many Bands and has:
  # | name  |

  
  
  # And a GET request to "http://localhost:8080/newspaper/this_weekend/article1" returns document with:
  #   | 
  # And a GET request to "http://localhost:8080/newspaper/this_weekend/article1" returns:  
  # """
  # <html>
  #   <body>
  #     <div id='e_name'>Laid back space rock - udder delight!</div>
  #     <div id='path_to_band_page'>http://localhost:8080/newspaper/bands/1</div
  #   </body>
  # </html>
  # """
#   And a GET request to "http://localhost:8080/newspaper/bands/1" returns:
#   """
#   <html>
#     <body>
#       <div id='b_name'>Hippie Spacecows</div>
#       <div id='b_genre'>rockabilly</div>
#     </body>
#   </html>
#   """
#   
# Scenario: Basic case
#   Given the following command file:
#   """
#   digest http://localhost:8080/newspaper/this_weekend/article1 using local_newspaper_upcoming_event.ps
#   
#   """ 
#   And the following strategy file "local_newspaper_upcoming_event.ps":
#   """
#   #render response in browser
#   get band by processing /path/to/band/page using local_newspaper_band_page_parsing_strategy
#   create event where:
#     name = /path/to/event/@string
#     bands << that band
#   """
#   Then there should be an Event with:
#   | name  | Laid back space rock - udder delight! |
#   | bands | 0 | band...
#   And there should be an event...?>
  
  
  
  
  
  
  
  
  