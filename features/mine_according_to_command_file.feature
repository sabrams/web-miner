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
  Given a WebMiner instance

@adds_world_wide_web
@creates_test_directories
Scenario: Using XPath, create an instance of a map from a simple HTML document
  Given the following strategy file "strat_dir/local_paper.str":
  """
  new_strategy "UPCOMING_EVENT_PAGE" do

    requires_simple_get

    create_map ({
      "name" => "//title/text()",
      "link" => "//a/text()"
      })
  end

  """
  And the following command file "command_dir/process_local_paper.cmd":
  """
  digest "http://localhost:8080/newspaper/this_weekend/article1", "UPCOMING_EVENT_PAGE"
  """
  And a world wide web where a GET to "/newspaper/this_weekend/article1" returns
  """
  <html>
    <body>
      <title>Laid back space rock - udder delight!</title>
      <a>http://link_to_event.html</a>
    </body>
  </html>
  """
  When the WebMiner is loaded with strategies from "strat_dir"
  And the WebMiner runs commands from "command_dir"
  Then there should be a map
  """
  {
    'name' => 'Laid back space rock - udder delight!',
    'link' => 'http://link_to_event.html'
  }
  """
    
@adds_world_wide_web
@creates_test_directories
Scenario: Using XPath, create an instance of a custom class from a simple HTML document
  Given a domain class "Event" with attributes "name", "link"
  Given the following strategy file "strat_dir/local_paper.str":
  """
  new_strategy "UPCOMING_EVENT_PAGE" do
    
    requires_simple_get
    
    create "Event", {
      "name" => "//title/text()",
      "link" => "//a/text()"
      }
  end

  """
  And the following command file "command_dir/process_local_paper.cmd":
  """
  digest "http://localhost:8080/newspaper/this_weekend/article1", "UPCOMING_EVENT_PAGE"
  """
  And a world wide web where a GET to "/newspaper/this_weekend/article1" returns
  """
  <html>
    <body>
      <title>Laid back space rock - udder delight!</title>
      <a>http://link_to_event.html</a>
    </body>
  </html>
  """
  When the WebMiner is loaded with strategies from "strat_dir"
  And the WebMiner runs commands from "command_dir"
  Then there should be an Event with attribute values "name": "Laid back space rock - udder delight!", "link": "http://link_to_event.html"
  
# Sometimes a strategy needs access to the DOM after resource rendered by a browser. This can be done by specifying "requires_page_render"

@adds_world_wide_web
@creates_test_directories
Scenario: Using XPath, process a document AFTER it is manipulated by document-embedded Javascript on a browser page load.
  Given the following strategy file "strat_dir/local_paper.str":
  """
  new_strategy "EVENT_PAGE_WITH_WEIRD_JAVASCRIPT_ACTIONS" do

    requires_page_render
    
    create_map ({
      "name" => "//title/text()"
    })
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
  Then there should be a map
  """
  {
    'name' => 'The Funky Monkeys, Tonight!'
  }
  """
  
# To create sets of data, use 'create_set' method

@adds_world_wide_web
@creates_test_directories
Scenario: Using XPath, process an RSS feed with list of elements that each need individual processing
  Given a domain class "Event" with attributes "name", "link"
  And the following strategy file "strat_dir/book_worm_rss.str":
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
        <title>Tonight at Sallys</title>
        <a>http://sallys.com/event1</a>
      </event>
      <event>
        <title>Tonight at Joes</title>
        <a>http://joes.com/eventA</a>
      </event>
     </events>
    </rss>
  </xml>
  """
  When the WebMiner is loaded with strategies from "strat_dir"
  And the WebMiner runs commands from "command_dir"
  Then there should be an Event with attribute values "name": "Tonight at Sallys", "link": "<a>http://sallys.com/event1</a>"
  And there should be an Event with attribute values "name": "Tonight at Joes", "link": "<a>http://joes.com/eventA</a>"

# Sometimes understanding the relationships of resources (through links) is necesary. This can be accomplished with a callback.
# The link can be included in the object being constructed (TODO: way to do this with meta data per object)

@adds_world_wide_web
@creates_test_directories
Scenario: Populate a set of elements using 'create_set' while following references
  Given a domain class "Event" with attributes "name", "description", "link"
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
        <title>Tonight at Bills</title>
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
      <p>A more informative description about what is at Bills</p>
    </body>
  </html>
  """
  When the WebMiner is loaded with strategies from "strat_dir"
  And the WebMiner runs commands from "command_dir"
  Then there should be an Event with attribute values
    | name        | Tonight at Bills |
    | description | A more informative description about what is at Bills |
# Then there should be an Event with attribute values "name": "Tonight at Bennighans","description": "A more informative description about what is at Bennighans"

#Strategies can be organized by directory tree. When this is done, these strategies are named according to the directory layout. 

@creates_test_directories
Scenario: nested strategy files in the strategy directory (happen to be using .str.rb extension)
Given the following strategy file "strat_dir/SUBDIR1/SUBDIR2/some_strat.str.rb":
"""
new_strategy 'NESTED_NAME' do

  create 'PlaceHolderSoStratCreationIsntRejected', {
    }
end
"""
When the WebMiner is loaded with strategies from "strat_dir"
Then there should be a strategy called "SUBDIR1.SUBDIR2.NESTED_NAME"
  
  
  
  
  
  
  
  