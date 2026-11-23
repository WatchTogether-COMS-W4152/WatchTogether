Feature: Tracking episode progress together
  As a member of a group watching a show together, I want to record the last
  episode I watched and see where everyone else is, so that we know who is
  caught up and which episode the whole group can watch next.

  Background:
    Given "Alice" has an account
    And "Bob" has an account
    And "Alice" owns a group named "Friday Night"
    And "Bob" joined "Friday Night" using an invitation
    And "Alice" added "Severance" to the watchlist for "Friday Night"

  @US23
  Scenario: A member records where they are and moves on one episode at a time
    Given I am signed in as "Bob"
    When I view "Severance" in "Friday Night"
    Then my progress for "Severance" in "Friday Night" is "Not started"
    When I record that I watched "Severance" up to season "1" episode "3" in "Friday Night"
    Then I am told I've watched up to "S1 E3"
    And my progress for "Severance" in "Friday Night" is "S1 E3"
    When I mark the next episode of "Severance" as watched in "Friday Night"
    Then I am told I've watched up to "S1 E4"
    When I view the watchlist for "Friday Night"
    And I view "Severance" in "Friday Night"
    Then my progress for "Severance" in "Friday Night" is "S1 E4"
    When I am signed in as "Alice"
    And I view "Severance" in "Friday Night"
    Then the progress for "Severance" in "Friday Night" shows:
      | Bob   | S1 E4       | Caught up |
      | Alice | Not started |           |
    And progress details contain no emails or invitation codes

  @US23
  Scenario: Season and episode numbers must be whole numbers of at least 1
    Given "Bob" has watched "Severance" up to season 1 episode 2 in "Friday Night"
    And I am signed in as "Bob"
    When I record that I watched "Severance" up to season "0" episode "3" in "Friday Night"
    Then I see an error for "season"
    And my progress for "Severance" in "Friday Night" is "S1 E2"
    When I record that I watched "Severance" up to season "2" episode "" in "Friday Night"
    Then I see an error for "episode"
    And my progress for "Severance" in "Friday Night" is "S1 E2"
    When I record that I watched "Severance" up to season "2" episode "1.5" in "Friday Night"
    Then I see an error for "episode"
    And my progress for "Severance" in "Friday Night" is "S1 E2"

  @US24 @US25
  Scenario: Members see who is caught up and the next episode everyone can watch
    Given "Carol" has an account
    And "Carol" joined "Friday Night" using an invitation
    And I am signed in as "Alice"
    When I view "Severance" in "Friday Night"
    Then the next episode for everyone is "S1 E1"
    And not everyone is caught up
    Given "Alice" has watched "Severance" up to season 2 episode 1 in "Friday Night"
    And "Bob" has watched "Severance" up to season 1 episode 9 in "Friday Night"
    When I view "Severance" in "Friday Night"
    Then the progress for "Severance" in "Friday Night" shows:
      | Alice | S2 E1       | Caught up |
      | Bob   | S1 E9       |           |
      | Carol | Not started |           |
    And the next episode for everyone is "S1 E1"
    Given "Carol" has watched "Severance" up to season 2 episode 1 in "Friday Night"
    When I view "Severance" in "Friday Night"
    Then the progress for "Severance" in "Friday Night" shows:
      | Alice | S2 E1 | Caught up |
      | Carol | S2 E1 | Caught up |
      | Bob   | S1 E9 |           |
    And the next episode for everyone is "S1 E10"
    When I view the watchlist for "Friday Night"
    Then the watchlist for "Friday Night" suggests "S1 E10" next for "Severance"
    Given "Bob" has watched "Severance" up to season 2 episode 1 in "Friday Night"
    When I view "Severance" in "Friday Night"
    Then everyone is caught up
    And the next episode for everyone is "S2 E2"

  @US25 @US11
  Scenario: A member who leaves the group no longer holds everyone back
    Given "Alice" has watched "Severance" up to season 1 episode 6 in "Friday Night"
    And "Bob" has watched "Severance" up to season 1 episode 2 in "Friday Night"
    And I am signed in as "Alice"
    When I view "Severance" in "Friday Night"
    Then the next episode for everyone is "S1 E3"
    When I remove "Bob" from "Friday Night"
    And I view "Severance" in "Friday Night"
    Then the progress for "Severance" in "Friday Night" shows:
      | Alice | S1 E6 | Caught up |
    And everyone is caught up
    And the next episode for everyone is "S1 E7"

  @US26
  Scenario: A member clears their own progress without affecting anyone else
    Given "Alice" has watched "Severance" up to season 1 episode 5 in "Friday Night"
    And "Bob" has watched "Severance" up to season 1 episode 3 in "Friday Night"
    And I am signed in as "Bob"
    When I clear my progress for "Severance" in "Friday Night"
    Then my progress for "Severance" in "Friday Night" is "Not started"
    And the progress for "Severance" in "Friday Night" shows:
      | Alice | S1 E5       | Caught up |
      | Bob   | Not started |           |
    And the next episode for everyone is "S1 E1"

  @US23 @US26 @US08
  Scenario: Only current members can track progress, and only within their own group
    Given "Carol" has an account
    And "Carol" owns a group named "Film Club"
    And "Carol" added "Dark" to the watchlist for "Film Club"
    And I am signed in as "Carol"
    When I view "Severance" in "Friday Night"
    Then the group is not available to me
    When I record that I watched "Severance" up to season "1" episode "1" in "Friday Night"
    Then the group is not available to me
    When I clear my progress for "Severance" in "Friday Night"
    Then the group is not available to me
    Given I am signed in as "Bob"
    When I try to record progress for "Dark" from "Film Club" through "Friday Night"
    Then the group is not available to me
    Given I am signed out
    When I record that I watched "Severance" up to season "1" episode "1" in "Friday Night"
    Then I am asked to sign in
    When I am signed in as "Alice"
    And I view "Severance" in "Friday Night"
    Then the progress for "Severance" in "Friday Night" shows:
      | Alice | Not started |  |
      | Bob   | Not started |  |
