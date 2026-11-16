@tmdb
Feature: Find movies and TV shows and keep their details
  Members search the shared catalogue, choose the correct movie or TV show,
  and keep its details with their suggestions and watchlist.

  Background:
    Given "Alice" has an account
    And "Bob" has an account
    And "Alice" owns a group named "Friday Night"
    And "Bob" joined "Friday Night" using an invitation
    And the TMDB catalogue is available
    And I am signed in as "Bob"

  @US19 @US20
  Scenario: Search and select a movie for voting with canonical metadata
    When I search the catalogue for "Arrival" in "Friday Night"
    Then the catalogue includes the movie "Arrival" from 2016
    And the catalogue response contains no API credentials
    When I preview catalogue movie 329865 in "Friday Night"
    Then the catalogue preview has age rating "PG-13"
    When I add catalogue movie 329865 to the suggestions for "Friday Night" with forged details
    Then the suggestion "Arrival" shows its catalogue details
    And "Friday Night" has exactly one suggestion titled "Arrival"
    When I add catalogue movie 329865 to the suggestions for "Friday Night"
    Then I see an error for "title"
    And "Friday Night" has exactly one suggestion titled "Arrival"

  @US19 @US20
  Scenario: Select a television show directly for the watchlist
    When I search the catalogue for "The Expanse" in "Friday Night"
    Then the catalogue includes the TV show "The Expanse" from 2015
    When I preview catalogue TV show 63639 in "Friday Night"
    Then the catalogue preview has age rating "TV-14"
    When I add catalogue TV show 63639 to the watchlist for "Friday Night" with forged details
    Then the watchlist item "The Expanse" shows its catalogue details
    And the watchlist for "Friday Night" contains:
      | The Expanse | Not watched |
    When I add catalogue TV show 63639 to the watchlist for "Friday Night"
    Then "Friday Night" has exactly one watchlist item for catalogue TV show 63639
    When I am signed in as "Alice"
    And I view the watchlist for "Friday Night"
    Then the watchlist item "The Expanse" shows its catalogue details

  @US20 @US21 @US22
  Scenario: A member sends a suggestion to the watchlist without losing votes
    When I add catalogue movie 329865 to the suggestions for "Friday Night"
    And I rate "Arrival" in "Friday Night" as "Love it"
    Given the TMDB catalogue is unavailable
    When I send the suggestion "Arrival" from "Friday Night" to its watchlist
    Then the suggestion "Arrival" is marked as on the watchlist
    And my rating for "Arrival" is "Love it"
    And "Arrival" shows 1 of 2 members rated
    When I send the suggestion "Arrival" from "Friday Night" to its watchlist
    Then "Friday Night" has exactly one watchlist item for catalogue movie 329865
    When I view the watchlist for "Friday Night"
    Then the watchlist item "Arrival" shows its catalogue details

  @US21
  Scenario: A manual suggestion can also be added to the watchlist only once
    Given "Alice" suggested "Our home movie" to "Friday Night"
    When I send the suggestion "Our home movie" from "Friday Night" to its watchlist
    Then the suggestion "Our home movie" is marked as on the watchlist
    When I send the suggestion "Our home movie" from "Friday Night" to its watchlist
    Then "Friday Night" has exactly one watchlist item titled "Our home movie"
    When I view the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Our home movie | Not watched |

  @US19
  Scenario: Separate remakes with the same name can both be suggested
    When I add catalogue movie 329865 to the suggestions for "Friday Night"
    And I add catalogue movie 999001 to the suggestions for "Friday Night"
    Then "Friday Night" has catalogue suggestions:
      | 329865 | movie | Arrival | 2016 |
      | 999001 | movie | Arrival | 1996 |

  @US20
  Scenario: Titles without posters or age certifications remain usable
    When I add catalogue TV show 999002 to the watchlist for "Friday Night"
    Then the watchlist item "Unannounced Series" has no invented catalogue details

  @US19
  Scenario: Short text and unmatched text return no catalogue suggestions
    When I search the catalogue for "A" in "Friday Night"
    Then the catalogue search has no results
    When I search the catalogue for "No matching title" in "Friday Night"
    Then the catalogue search has no results

  @US22
  Scenario: Unavailable TMDB gives a safe error and does not create partial titles
    Given the TMDB catalogue is unavailable
    When I search the catalogue for "Arrival" in "Friday Night"
    Then the catalogue request fails safely with status 503
    When I add catalogue movie 329865 to the suggestions for "Friday Night"
    Then I see an error for "title"
    And "Friday Night" has no suggestions
    When I add catalogue TV show 63639 to the watchlist for "Friday Night"
    Then I see an error for "title"
    And "Friday Night" has no watchlist items

  @US19
  Scenario: Invalid catalogue selections are rejected before creating records
    When I request unsupported catalogue type "person" with ID "42" in "Friday Night"
    Then the catalogue request fails safely with status 422
    When I request unsupported catalogue type "movie" with ID "invalid" in "Friday Night"
    Then the catalogue request fails safely with status 422
    When I submit an incomplete catalogue selection to the suggestions for "Friday Night"
    Then I see an error for "title"
    And "Friday Night" has no suggestions
    When I submit an incomplete catalogue selection to the watchlist for "Friday Night"
    Then I see an error for "title"
    And "Friday Night" has no watchlist items
    When I add catalogue movie 404 to the suggestions for "Friday Night"
    Then I see an error for "title"
    And "Friday Night" has no suggestions

  @US19 @US21 @US08
  Scenario: Outsiders cannot search another group's catalogue or copy its suggestions
    Given "Alice" suggested "Arrival" to "Friday Night"
    And "Carol" has an account
    And I am signed in as "Carol"
    When I search the catalogue for "Arrival" in "Friday Night"
    Then the catalogue request fails safely with status 404
    When I preview catalogue movie 329865 in "Friday Night"
    Then the catalogue request fails safely with status 404
    When I send the suggestion "Arrival" from "Friday Night" to its watchlist
    Then the group is not available to me
    And "Friday Night" has no watchlist items
    Given I am signed out
    When I send the suggestion "Arrival" from "Friday Night" to its watchlist
    Then I am asked to sign in
    And "Friday Night" has no watchlist items

  @US21 @US08
  Scenario: A suggestion cannot be copied through another group's URL
    Given "Alice" suggested "Arrival" to "Friday Night"
    And "Bob" owns a group named "Film Club"
    When I send the suggestion "Arrival" from "Friday Night" through "Film Club" to its watchlist
    Then the group is not available to me
    And "Friday Night" has no watchlist items
    And "Film Club" has no watchlist items

  @US20 @US21 @US15
  Scenario: Removing a copied suggestion preserves its watched watchlist item
    When I add catalogue movie 329865 to the suggestions for "Friday Night"
    And I rate "Arrival" in "Friday Night" as "Love it"
    And I send the suggestion "Arrival" from "Friday Night" to its watchlist
    And I change the watched status of "Arrival" in "Friday Night"
    And I remove the suggestion "Arrival" from "Friday Night"
    Then the suggestion "Arrival" was removed from "Friday Night" with its ratings
    When I view the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Arrival | Watched |
    And the watchlist item "Arrival" shows its catalogue details

  @US21 @US18
  Scenario: Removing a copied watchlist item allows the suggestion to be added again
    When I add catalogue movie 329865 to the suggestions for "Friday Night"
    And I send the suggestion "Arrival" from "Friday Night" to its watchlist
    And I remove "Arrival" from the watchlist for "Friday Night"
    Then the watchlist item "Arrival" has been removed from "Friday Night"
    When I view the suggestions for "Friday Night"
    Then the suggestion "Arrival" is available to add to the watchlist
    When I send the suggestion "Arrival" from "Friday Night" to its watchlist
    Then the suggestion "Arrival" is marked as on the watchlist
    And "Friday Night" has exactly one watchlist item for catalogue movie 329865
    When I view the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Arrival | Not watched |

  @US22
  Scenario: Members can still add manual titles during a catalogue outage
    Given the TMDB catalogue is unavailable
    When I search the catalogue for "Home movie" in "Friday Night"
    Then the catalogue request fails safely with status 503
    When I suggest "Our vacation video" to "Friday Night"
    Then I am told "Our vacation video" was added
    And "Friday Night" has exactly one suggestion titled "Our vacation video"
    When I add "Our wedding video" to the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Our wedding video | Not watched |

  @US19 @US21 @US08 @US11
  Scenario: Removed members lose catalogue access and cannot add or copy titles
    Given "Alice" suggested "Arrival" to "Friday Night"
    When I search the catalogue for "Arrival" in "Friday Night"
    Then the catalogue includes the movie "Arrival" from 2016
    Given I am signed in as "Alice"
    When I remove "Bob" from "Friday Night"
    And I am signed in as "Bob"
    And I search the catalogue for "Arrival" in "Friday Night"
    Then the catalogue request fails safely with status 404
    When I preview catalogue movie 329865 in "Friday Night"
    Then the catalogue request fails safely with status 404
    When I add catalogue movie 329865 to the suggestions for "Friday Night"
    Then the group is not available to me
    And "Friday Night" has exactly one suggestion titled "Arrival"
    When I add catalogue TV show 63639 to the watchlist for "Friday Night"
    Then the group is not available to me
    When I send the suggestion "Arrival" from "Friday Night" to its watchlist
    Then the group is not available to me
    And "Friday Night" has no watchlist items

  @US19
  Scenario: Movie and TV identifiers are separate even when the numeric IDs match
    When I add catalogue movie 329865 to the suggestions for "Friday Night"
    And I add catalogue TV show 329865 to the suggestions for "Friday Night"
    Then "Friday Night" has catalogue suggestions:
      | 329865 | movie | Arrival             | 2016 |
      | 329865 | tv    | Arrival: The Series | 2018 |
    When I add catalogue movie 329865 to the watchlist for "Friday Night"
    And I add catalogue TV show 329865 to the watchlist for "Friday Night"
    Then "Friday Night" has exactly one watchlist item for catalogue movie 329865
    And "Friday Night" has exactly one watchlist item for catalogue TV show 329865
    And the watchlist for "Friday Night" contains:
      | Arrival             | Not watched |
      | Arrival: The Series | Not watched |
