Feature: A shared group watchlist
  As a group member, I want to keep a shared list of movies and shows
  so that we remember what to watch and what we have already watched.

  Background:
    Given "Alice" has an account
    And "Bob" has an account
    And "Alice" owns a group named "Friday Night"
    And "Bob" joined "Friday Night" using an invitation

  @US16
  Scenario: An ordinary member adds a title that every member can see after returning
    Given I am signed in as "Bob"
    When I view the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" is empty
    When I add "Spirited Away" to the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Spirited Away | Not watched |
    When I view my groups
    And I view the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Spirited Away | Not watched |
    When I am signed in as "Alice"
    And I view the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Spirited Away | Not watched |
    And watchlist details contain no emails or invitation codes

  @US16
  Scenario: Blank titles explain the error without changing the watchlist
    Given I am signed in as "Bob"
    When I add "" to the watchlist for "Friday Night"
    Then I see an error for "title"
    And "Friday Night" has no watchlist items
    When I add a whitespace-only title to the watchlist for "Friday Night"
    Then I see an error for "title"
    And "Friday Night" has no watchlist items
    When I view the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" is empty

  @US16
  Scenario: A title must fit the 120-character limit
    Given I am signed in as "Bob"
    When I add a watchlist title of 121 characters to "Friday Night"
    Then I see an error for "title"
    And "Friday Night" has no watchlist items
    When I add a watchlist title of 120 characters to "Friday Night"
    Then the watchlist for "Friday Night" contains the 120-character title

  @US17
  Scenario: Any member can mark another member's title watched and reverse it
    Given "Alice" added "Spirited Away" to the watchlist for "Friday Night"
    And I am signed in as "Bob"
    When I change the watched status of "Spirited Away" in "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Spirited Away | Watched |
    When I am signed in as "Alice"
    And I view the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Spirited Away | Watched |
    When I change the watched status of "Spirited Away" in "Friday Night"
    And I view the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Spirited Away | Not watched |
    When I am signed in as "Bob"
    And I view the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Spirited Away | Not watched |

  @US18
  Scenario: An ordinary member removes a title for the whole group
    Given "Alice" added "Cats" to the watchlist for "Friday Night"
    And "Bob" added "Paddington" to the watchlist for "Friday Night"
    And I am signed in as "Bob"
    When I remove "Cats" from the watchlist for "Friday Night"
    Then the watchlist item "Cats" has been removed from "Friday Night"
    And the watchlist for "Friday Night" contains:
      | Paddington | Not watched |
    When I am signed in as "Alice"
    And I view the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Paddington | Not watched |

  @US16 @US17 @US18 @US08
  Scenario: Outsiders cannot view or change a private watchlist
    Given "Alice" added "Spirited Away" to the watchlist for "Friday Night"
    And "Carol" has an account
    And I am signed in as "Carol"
    When I view the watchlist for "Friday Night"
    Then the group is not available to me
    And the page contains no watchlist details
    When I add "Cats" to the watchlist for "Friday Night"
    Then the group is not available to me
    When I change the watched status of "Spirited Away" in "Friday Night"
    Then the group is not available to me
    When I remove "Spirited Away" from the watchlist for "Friday Night"
    Then the group is not available to me
    When I am signed in as "Alice"
    And I view the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Spirited Away | Not watched |

  @US16 @US17 @US18
  Scenario: A signed-out visitor must sign in before viewing or changing a watchlist
    Given "Alice" added "Spirited Away" to the watchlist for "Friday Night"
    And I am signed out
    When I view the watchlist for "Friday Night"
    Then I am asked to sign in
    When I add "Cats" to the watchlist for "Friday Night"
    Then I am asked to sign in
    When I change the watched status of "Spirited Away" in "Friday Night"
    Then I am asked to sign in
    When I remove "Spirited Away" from the watchlist for "Friday Night"
    Then I am asked to sign in
    When I am signed in as "Alice"
    And I view the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Spirited Away | Not watched |

  @US17 @US18 @US08
  Scenario: A title from one group cannot be changed through another group's watchlist
    Given "Alice" added "Spirited Away" to the watchlist for "Friday Night"
    And "Bob" owns a group named "Film Club"
    And "Bob" added "Paddington" to the watchlist for "Film Club"
    And I am signed in as "Bob"
    When I try to change "Spirited Away" from "Friday Night" through the watchlist for "Film Club"
    Then the group is not available to me
    When I try to remove "Spirited Away" from "Friday Night" through the watchlist for "Film Club"
    Then the group is not available to me
    When I view the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Spirited Away | Not watched |
    When I view the watchlist for "Film Club"
    Then the watchlist for "Film Club" contains:
      | Paddington | Not watched |

  @US16 @US17 @US18 @US11
  Scenario: Removed members immediately lose watchlist access
    Given "Alice" added "Spirited Away" to the watchlist for "Friday Night"
    And I am signed in as "Alice"
    When I remove "Bob" from "Friday Night"
    And I am signed in as "Bob"
    And I view the watchlist for "Friday Night"
    Then the group is not available to me
    When I add "Cats" to the watchlist for "Friday Night"
    Then the group is not available to me
    When I change the watched status of "Spirited Away" in "Friday Night"
    Then the group is not available to me
    When I remove "Spirited Away" from the watchlist for "Friday Night"
    Then the group is not available to me
    When I am signed in as "Alice"
    And I view the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" contains:
      | Spirited Away | Not watched |

  @US18 @US09
  Scenario: Deleting a group deletes its watchlist and preserves other groups' lists
    Given "Alice" added "Spirited Away" to the watchlist for "Friday Night"
    And "Bob" owns a group named "Film Club"
    And "Bob" added "Paddington" to the watchlist for "Film Club"
    And I am signed in as "Alice"
    When I delete the group "Friday Night"
    Then the group "Friday Night" has been deleted
    And "Friday Night" has no watchlist items
    When I view the watchlist for "Friday Night"
    Then the group is not available to me
    When I am signed in as "Bob"
    And I view the watchlist for "Film Club"
    Then the watchlist for "Film Club" contains:
      | Paddington | Not watched |
