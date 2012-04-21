Feature: 
In order to allow a quick creation of a web mining strategy
I want to be able to run command files writen in a DSL 


Background:
  Given a domain class "Event" that has:
  | name  |

  
Scenario: 
  Given a web world where a GET to "/newspaper/this_weekend/article1" returns "HELLO WORLD"
  And a web world where a GET to "/blah" returns "YOYOYO"
  When I go to "/blah"
  Then I should see "YOYOYO"
  
# Scenario: Basic case
#   Given the following strategy file "local_newspaper_upcoming_event.ps":
#   """
#   #render response in browser
#   
#   create event where:
#     name = /path/to/event/@string
#   """
#   And the following command file:
#   """
#   digest http://localhost:8080/newspaper/this_weekend/article1 using local_newspaper_upcoming_event.ps
#   
#   """
#   And a web world where a GET to "/newspaper/this_weekend/article1" returns "HELLO WORLD"
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
  
  
  
  
  
  
  
  
  