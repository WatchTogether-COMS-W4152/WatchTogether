@tmdb
Feature: Where can we all watch

  Background:
    Given "Alice" has an account
    And "Bob" has an account
    And "Alice" owns a group named "Friday Night"
    And "Bob" joined "Friday Night" using an invitation
    And the TMDB catalogue is available

  @US35
  Scenario: A member lists the services they pay for
    Given I am signed in as "Alice"
    When I save the streaming services "Netflix, Hulu"
    Then my streaming services are "Netflix, Hulu"
    When I clear my streaming services
    Then my streaming services are ""
    When I save streaming services including an unknown service
    Then my streaming services are "Netflix"

  @US35
  Scenario: Members can see which services each person pays for
    Given I am signed in as "Alice"
    When I save the streaming services "Hulu, Netflix"
    And I am signed in as "Bob"
    When I view the group "Friday Night"
    Then "Alice" is listed with the streaming services "Netflix, Hulu"
    And "Bob" is listed with the streaming services ""
    And the page does not list streaming service ids

  @US35
  Scenario: A member cannot change someone else's services
    Given I am signed in as "Alice"
    When I save the streaming services "Netflix"
    And I am signed in as "Bob"
    When I save the streaming services "Hulu"
    And I am signed in as "Alice"
    When I visit my profile
    Then my streaming services are "Netflix"

  @US36
  Scenario: Catalogue titles say whether everyone can watch without paying extra
    Given I am signed in as "Alice"
    When I save the streaming services "Netflix"
    And I am signed in as "Bob"
    When I save the streaming services "Netflix"
    And I add catalogue movie 329865 to the watchlist for "Friday Night"
    And I add catalogue movie 329865 to the suggestions for "Friday Night"
    And I view the watchlist for "Friday Night"
    Then the watchability of "Arrival" on the watchlist is "On everyone's services"
    When I view the suggestions for "Friday Night"
    Then the watchability of "Arrival" on the picks is "On everyone's services"
    And the page does not list streaming service ids

  @US36
  Scenario: A member who lacks the service is told they would have to rent
    Given I am signed in as "Alice"
    When I save the streaming services "Netflix"
    And I add catalogue movie 329865 to the watchlist for "Friday Night"
    And I am signed in as "Bob"
    When I view the watchlist for "Friday Night"
    Then the watchability of "Arrival" on the watchlist is "Bob needs a rental"

  @US36
  Scenario: A free title is watchable even when nobody has listed a service
    Given I am signed in as "Alice"
    When I add catalogue movie 515151 to the watchlist for "Friday Night"
    Then the watchability of "Harbor Lights" on the watchlist is "On everyone's services"

  @US36
  Scenario: A title with no shared service and no rental names everyone
    Given I am signed in as "Alice"
    When I add catalogue movie 616161 to the watchlist for "Friday Night"
    Then the watchability of "Night Shift" on the watchlist is "Not available for Alice and Bob"

  @US36
  Scenario: Several members who would have to rent are named in order
    Given "Carol" has an account
    And "Carol" joined "Friday Night" using an invitation
    And I am signed in as "Alice"
    When I add catalogue movie 424242 to the watchlist for "Friday Night"
    Then the watchability of "Paper Moons" on the watchlist is "Alice, Bob, and Carol need a rental"

  @US36
  Scenario: A manually added title explains that streaming information is unavailable
    Given I am signed in as "Bob"
    When I add "Our home movie" to the watchlist for "Friday Night"
    Then the watchability of "Our home movie" on the watchlist is "Streaming information is not available for manually added titles."

  @US36
  Scenario: An empty US catalogue result is explained
    Given I am signed in as "Bob"
    When I add catalogue TV show 63639 to the watchlist for "Friday Night"
    Then the watchability of "The Expanse" on the watchlist is "No watch providers are currently listed in the United States."

  @US36
  Scenario: An outsider cannot see who can watch a group's titles
    Given "Dana" has an account
    And I am signed in as "Dana"
    When I view the watchlist for "Friday Night"
    Then the group is not available to me
    And the page contains no watchlist details

  @US37
  Scenario: The watchlist can be filtered to titles everyone can watch
    Given I am signed in as "Alice"
    When I save the streaming services "Netflix"
    And I am signed in as "Bob"
    When I save the streaming services "Netflix"
    And I add catalogue movie 329865 to the watchlist for "Friday Night"
    And I add catalogue movie 424242 to the watchlist for "Friday Night"
    And I add "Our home movie" to the watchlist for "Friday Night"
    And I filter the watchlist for "Friday Night" to what everyone can watch
    Then the watchlist for "Friday Night" contains:
      | Arrival | Not watched |
    When I show the full watchlist for "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Arrival       | Not watched |
      | Paper Moons   | Not watched |
      | Our home movie | Not watched |

  @US37
  Scenario: Ranked picks can be filtered the same way
    Given I am signed in as "Alice"
    When I save the streaming services "Netflix"
    And I am signed in as "Bob"
    When I save the streaming services "Netflix"
    And I add catalogue movie 329865 to the suggestions for "Friday Night"
    And I add catalogue movie 424242 to the suggestions for "Friday Night"
    And I filter the picks for "Friday Night" to what everyone can watch
    Then the suggestions for "Friday Night" are ranked:
      | Arrival | 0 |
    When I show every pick for "Friday Night"
    Then the suggestions for "Friday Night" are ranked:
      | Arrival     | 0 |
      | Paper Moons | 0 |

  @US37
  Scenario: A title is hidden by the filter when its availability cannot be loaded
    Given I am signed in as "Alice"
    When I save the streaming services "Netflix"
    And I am signed in as "Bob"
    When I save the streaming services "Netflix"
    And I add catalogue movie 329865 to the watchlist for "Friday Night"
    Given the TMDB catalogue is unavailable
    When I view the watchlist for "Friday Night"
    Then the watchability of "Arrival" on the watchlist is "Streaming information is temporarily unavailable. Try again later."
    When I filter the watchlist for "Friday Night" to what everyone can watch
    Then the filtered watchlist for "Friday Night" is empty
