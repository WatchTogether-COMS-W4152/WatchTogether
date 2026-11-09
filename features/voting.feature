Feature: Decide what to watch together
  As a group member, I want to suggest titles and privately rate them
  so the group can see what everyone is reasonably happy to watch.

  Ratings: Love it adds 2, Maybe adds 1, and Not interested subtracts 2.
  Titles are ranked by total score, then by the number of Love it ratings,
  then by the oldest suggestion.

  Background:
    Given "Alice" has an account
    And "Bob" has an account
    And "Alice" owns a group named "Friday Night"
    And "Bob" joined "Friday Night" using an invitation

  @US12
  Scenario: A member suggests a title for the group
    Given I am signed in as "Bob"
    When I suggest "  Spirited   Away " to "Friday Night"
    Then I am told "Spirited Away" was added
    And the suggestions for "Friday Night" are ranked:
      | Spirited Away | 0 |
    And "Spirited Away" is shown as suggested by "Bob"
    And "Spirited Away" shows 0 of 2 members rated
    And I have not rated "Spirited Away"

  @US12
  Scenario: Blank titles and differently cased duplicates are rejected
    Given I am signed in as "Bob"
    When I suggest "   " to "Friday Night"
    Then I see an error for "title"
    And "Friday Night" has no suggestions
    Given "Alice" suggested "Spirited Away" to "Friday Night"
    When I suggest "  spirited AWAY " to "Friday Night"
    Then I see an error for "title"
    And "Friday Night" has exactly one suggestion titled "Spirited Away"

  @US12 @US08
  Scenario: Outsiders and visitors cannot see or add suggestions
    Given "Alice" suggested "Spirited Away" to "Friday Night"
    And "Carol" has an account
    And I am signed in as "Carol"
    When I view the suggestions for "Friday Night"
    Then the group is not available to me
    And the page contains no group details
    When I suggest "Heat" to "Friday Night"
    Then the group is not available to me
    And "Friday Night" has exactly one suggestion titled "Spirited Away"
    Given I am signed out
    When I view the suggestions for "Friday Night"
    Then I am asked to sign in

  @US13
  Scenario: Changing my rating keeps a single private rating
    Given "Alice" suggested "Spirited Away" to "Friday Night"
    And I am signed in as "Bob"
    When I rate "Spirited Away" in "Friday Night" as "Love it"
    Then my rating for "Spirited Away" is "Love it"
    And the suggestions for "Friday Night" are ranked:
      | Spirited Away | 2 |
    When I rate "Spirited Away" in "Friday Night" as "Maybe"
    Then my rating for "Spirited Away" is "Maybe"
    When I rate "Spirited Away" in "Friday Night" as "Not interested"
    Then my rating for "Spirited Away" is "Not interested"
    And the suggestions for "Friday Night" are ranked:
      | Spirited Away | -2 |
    And "Bob" has exactly one rating for "Spirited Away" in "Friday Night"

  @US13
  Scenario: Only the three rating options are accepted
    Given "Alice" suggested "Spirited Away" to "Friday Night"
    And "Bob" rated "Spirited Away" in "Friday Night" as "Maybe"
    And I am signed in as "Bob"
    When I rate "Spirited Away" in "Friday Night" with the unsupported rating "veto"
    Then I see an error for "rating"
    And my rating for "Spirited Away" is "Maybe"
    When I rate "Spirited Away" in "Friday Night" with the unsupported rating ""
    Then I see an error for "rating"
    And "Bob" has exactly one rating for "Spirited Away" in "Friday Night"

  @US13 @US08
  Scenario: Other members see totals but not who rated what
    Given "Alice" suggested "Spirited Away" to "Friday Night"
    And "Bob" rated "Spirited Away" in "Friday Night" as "Not interested"
    And I am signed in as "Alice"
    When I view the suggestions for "Friday Night"
    Then "Spirited Away" shows 1 of 2 members rated
    And I have not rated "Spirited Away"
    And the suggestions show no individual ratings or emails

  @US13 @US08
  Scenario: Outsiders and visitors cannot rate a group's suggestions
    Given "Alice" suggested "Spirited Away" to "Friday Night"
    And "Carol" has an account
    And I am signed in as "Carol"
    When I rate "Spirited Away" in "Friday Night" as "Love it"
    Then the group is not available to me
    And nobody has rated "Spirited Away" in "Friday Night"
    Given I am signed out
    When I rate "Spirited Away" in "Friday Night" as "Love it"
    Then I am asked to sign in
    And nobody has rated "Spirited Away" in "Friday Night"

  @US14
  Scenario: The group sees titles ranked by total score with Love it breaking ties
    Given "Carol" has an account
    And "Carol" joined "Friday Night" using an invitation
    And "Alice" suggested "Inception" to "Friday Night"
    And "Alice" suggested "Paddington" to "Friday Night"
    And "Bob" suggested "Heat" to "Friday Night"
    And "Bob" suggested "Arrival" to "Friday Night"
    And "Carol" suggested "Up" to "Friday Night"
    And "Carol" suggested "Cats" to "Friday Night"
    And "Alice" rated "Inception" in "Friday Night" as "Love it"
    And "Bob" rated "Inception" in "Friday Night" as "Love it"
    And "Carol" rated "Inception" in "Friday Night" as "Not interested"
    And "Alice" rated "Paddington" in "Friday Night" as "Maybe"
    And "Bob" rated "Paddington" in "Friday Night" as "Maybe"
    And "Carol" rated "Paddington" in "Friday Night" as "Maybe"
    And "Alice" rated "Heat" in "Friday Night" as "Maybe"
    And "Bob" rated "Heat" in "Friday Night" as "Maybe"
    And "Carol" rated "Arrival" in "Friday Night" as "Love it"
    And "Bob" rated "Cats" in "Friday Night" as "Not interested"
    And I am signed in as "Alice"
    When I view the suggestions for "Friday Night"
    Then the suggestions for "Friday Night" are ranked:
      | Paddington | 3  |
      | Inception  | 2  |
      | Arrival    | 2  |
      | Heat       | 2  |
      | Up         | 0  |
      | Cats       | -2 |
    And "Inception" shows 3 of 3 members rated

  @US14 @US11
  Scenario: Ratings from a removed member no longer count
    Given "Carol" has an account
    And "Carol" joined "Friday Night" using an invitation
    And "Alice" suggested "Up" to "Friday Night"
    And "Alice" suggested "Cats" to "Friday Night"
    And "Alice" rated "Up" in "Friday Night" as "Maybe"
    And "Carol" rated "Cats" in "Friday Night" as "Love it"
    And I am signed in as "Alice"
    When I view the suggestions for "Friday Night"
    Then the suggestions for "Friday Night" are ranked:
      | Cats | 2 |
      | Up   | 1 |
    When I remove "Carol" from "Friday Night"
    And I view the suggestions for "Friday Night"
    Then the suggestions for "Friday Night" are ranked:
      | Up   | 1 |
      | Cats | 0 |
    And "Cats" shows 0 of 2 members rated

  @US15
  Scenario: The person who suggested a title can remove it along with its ratings
    Given "Bob" suggested "Cats" to "Friday Night"
    And "Alice" rated "Cats" in "Friday Night" as "Love it"
    And I am signed in as "Bob"
    When I view the suggestions for "Friday Night"
    Then I can remove "Cats"
    When I remove the suggestion "Cats" from "Friday Night"
    Then the suggestion "Cats" was removed from "Friday Night" with its ratings
    And "Friday Night" has no suggestions

  @US15 @US10
  Scenario: Owners can remove any suggestion, but other members can remove only their own
    Given "Alice" suggested "Up" to "Friday Night"
    And "Bob" suggested "Heat" to "Friday Night"
    And I am signed in as "Bob"
    When I view the suggestions for "Friday Night"
    Then I cannot remove "Up"
    And I can remove "Heat"
    When I remove the suggestion "Up" from "Friday Night"
    Then only the suggester or an owner is allowed to do that
    And the suggestion "Up" is still in "Friday Night"
    Given I am signed in as "Alice"
    When I view the suggestions for "Friday Night"
    Then I can remove "Heat"
    When I remove the suggestion "Heat" from "Friday Night"
    Then the suggestion "Heat" was removed from "Friday Night" with its ratings
    And the suggestions for "Friday Night" are ranked:
      | Up | 0 |

  @US15 @US08
  Scenario: Outsiders and visitors cannot remove suggestions
    Given "Alice" suggested "Up" to "Friday Night"
    And "Carol" has an account
    And I am signed in as "Carol"
    When I remove the suggestion "Up" from "Friday Night"
    Then the group is not available to me
    And the suggestion "Up" is still in "Friday Night"
    Given I am signed out
    When I remove the suggestion "Up" from "Friday Night"
    Then I am asked to sign in
    And the suggestion "Up" is still in "Friday Night"
