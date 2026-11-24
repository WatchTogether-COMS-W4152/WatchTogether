@tmdb @US31
Feature: Find where to watch a title

  As a group member,
  I want to see where a movie or TV show is available to watch,
  so that my group can plan our next watch session.

  Background:
    Given "Alice" has an account
    And "Bob" has an account
    And "Alice" owns a group named "Friday Night"
    And "Bob" joined "Friday Night" using an invitation
    And the TMDB catalogue is available
    And I am signed in as "Bob"

  Scenario: A member sees US watch providers for a movie
    When I add catalogue movie 329865 to the watchlist for "Friday Night"
    And I open the streaming details for "Arrival" in "Friday Night"
    Then the watch provider status is "available"
    And the US watch providers are:
      | streaming | Netflix        |
      | rent      | Amazon Video   |
      | buy       | Apple TV Store |

  Scenario: A title has no listed US watch providers
    When I add catalogue TV show 63639 to the watchlist for "Friday Night"
    And I open the streaming details for "The Expanse" in "Friday Night"
    Then the watch provider status is "available"
    And no US watch providers are listed

  Scenario: A manually added title has no catalogue link
    When I add "Our home movie" to the watchlist for "Friday Night"
    And I open the streaming details for "Our home movie" in "Friday Night"
    Then the watch provider status is "not_linked"

  Scenario: A title remains accessible during a TMDB outage
    When I add catalogue movie 329865 to the watchlist for "Friday Night"
    Given the TMDB catalogue is unavailable
    When I open the streaming details for "Arrival" in "Friday Night"
    Then the watch provider status is "unavailable"