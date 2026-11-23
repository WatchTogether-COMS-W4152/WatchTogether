Feature: Spoiler-safe episode discussion
  As a member watching a show at my own pace, I want every comment tied to an
  episode and to see only comments on episodes I have watched, so I can join the
  conversation without spoilers from friends who are further ahead.

  Background:
    Given "David" has an account
    And "Larissa" has an account
    And "Sam" has an account
    And "David" owns a group named "Roommates"
    And "Larissa" joined "Roommates" using an invitation
    And "Sam" joined "Roommates" using an invitation
    And "David" added "Severance" to the watchlist for "Roommates"

  @US32
  Scenario: Members discuss an episode they have all watched
    Given "David" has watched up to season 1 episode 3 of "Severance" in "Roommates"
    And "Larissa" has watched up to season 1 episode 3 of "Severance" in "Roommates"
    And "David" commented "The goats!" on season 1 episode 2 of "Severance" in "Roommates"
    And I am signed in as "Larissa"
    When I comment "  Wait, the goats?  " on season 1 episode 2 of "Severance" in "Roommates"
    Then I am told my comment was posted on "S1 E2"
    And the discussion shows:
      | S1 E2 | David   | The goats!       |
      | S1 E2 | Larissa | Wait, the goats? |
    When I am signed in as "David"
    And I view "Severance" in "Roommates"
    Then the discussion shows:
      | S1 E2 | David   | The goats!       |
      | S1 E2 | Larissa | Wait, the goats? |

  @US33
  Scenario: Larissa on episode 4 can't see David's episode 8 reaction until she catches up
    Given "David" has watched up to season 1 episode 8 of "Severance" in "Roommates"
    And "David" commented "Office supplies, nice" on season 1 episode 4 of "Severance" in "Roommates"
    And "David" commented "Helly is an Eagan!" on season 1 episode 8 of "Severance" in "Roommates"
    And "Larissa" has watched up to season 1 episode 4 of "Severance" in "Roommates"
    And I am signed in as "Larissa"
    When I view "Severance" in "Roommates"
    Then the discussion shows:
      | S1 E4 | David | Office supplies, nice |
    And the discussion hides 1 comment on "S1 E8"
    And the page does not reveal "Helly is an Eagan!"
    Given "Larissa" has watched up to season 1 episode 8 of "Severance" in "Roommates"
    When I view "Severance" in "Roommates"
    Then the discussion shows:
      | S1 E4 | David | Office supplies, nice |
      | S1 E8 | David | Helly is an Eagan!    |
    And nothing is hidden from me in the discussion

  @US33
  Scenario: A member who hasn't started sees only counts, and season order is respected
    Given "David" has watched up to season 2 episode 1 of "Severance" in "Roommates"
    And "David" commented "What a finale" on season 1 episode 10 of "Severance" in "Roommates"
    And "David" commented "Season two already?" on season 2 episode 1 of "Severance" in "Roommates"
    And I am signed in as "Sam"
    When I view "Severance" in "Roommates"
    Then the discussion shows no comments
    And the discussion hides 1 comment on "S1 E10"
    And the discussion hides 1 comment on "S2 E1"
    And the page does not reveal "What a finale"
    Given "Sam" has watched up to season 1 episode 10 of "Severance" in "Roommates"
    When I view "Severance" in "Roommates"
    Then the discussion shows:
      | S1 E10 | David | What a finale |
    And the discussion hides 1 comment on "S2 E1"
    And the page does not reveal "Season two already?"

  @US34
  Scenario: A member cannot post about episodes they haven't watched yet
    Given "Larissa" has watched up to season 1 episode 4 of "Severance" in "Roommates"
    And I am signed in as "Larissa"
    When I comment "I bet Mark is..." on season 1 episode 5 of "Severance" in "Roommates"
    Then I see an error for "episode"
    When I comment "" on season 1 episode 4 of "Severance" in "Roommates"
    Then I see an error for "body"
    And "Severance" has no comments
    When I am signed in as "Sam"
    And I comment "Hi all" on season 1 episode 1 of "Severance" in "Roommates"
    Then I see an error for "episode"
    And "Severance" has no comments

  @US35
  Scenario: Authors and owners can delete comments; other members cannot
    Given "Larissa" has watched up to season 1 episode 2 of "Severance" in "Roommates"
    And "Sam" has watched up to season 1 episode 2 of "Severance" in "Roommates"
    And "Larissa" commented "Too slow for me" on season 1 episode 1 of "Severance" in "Roommates"
    And "Larissa" commented "Okay I'm hooked" on season 1 episode 2 of "Severance" in "Roommates"
    And I am signed in as "Sam"
    When I delete the comment "Too slow for me" on "Severance" in "Roommates"
    Then only the author or an owner is allowed to do that
    And the comment "Too slow for me" on "Severance" in "Roommates" still exists
    When I am signed in as "Larissa"
    And I delete the comment "Too slow for me" on "Severance" in "Roommates"
    Then the comment "Too slow for me" on "Severance" in "Roommates" was deleted
    When I am signed in as "David"
    And I delete the comment "Okay I'm hooked" on "Severance" in "Roommates"
    Then the comment "Okay I'm hooked" on "Severance" in "Roommates" was deleted
    And "Severance" has no comments

  @US32 @US33 @US08
  Scenario: Outsiders, removed members, and signed-out visitors cannot read or post comments
    Given "David" has watched up to season 1 episode 1 of "Severance" in "Roommates"
    And "David" commented "Private thoughts" on season 1 episode 1 of "Severance" in "Roommates"
    And "Carol" has an account
    And I am signed in as "Carol"
    When I view "Severance" in "Roommates"
    Then the group is not available to me
    And the page does not reveal "Private thoughts"
    When I comment "Hello" on season 1 episode 1 of "Severance" in "Roommates"
    Then the group is not available to me
    When I am signed in as "David"
    And I remove "Sam" from "Roommates"
    And I am signed in as "Sam"
    And I view "Severance" in "Roommates"
    Then the group is not available to me
    When I am signed out
    And I view "Severance" in "Roommates"
    Then I am asked to sign in
    When I comment "Hello" on season 1 episode 1 of "Severance" in "Roommates"
    Then I am asked to sign in
    And the comment "Private thoughts" on "Severance" in "Roommates" still exists
