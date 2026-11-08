Feature: Share ownership and manage the crew
  As an owner, I want to share responsibility with trusted members
  and remove people who should no longer have access to the group.

  Background:
    Given "Alice" has an account
    And "Bob" has an account
    And "Alice" owns a group named "Friday Night"
    And "Bob" joined "Friday Night" using an invitation

  @US10 @US06
  Scenario: Sharing ownership keeps the original owner and gives the new owner management access
    Given "Carol" has an account
    And "Carol" joined "Friday Night" using an invitation
    And I am signed in as "Alice"
    When I make "Bob" an owner of "Friday Night"
    Then the group has these owners:
      | Alice |
      | Bob   |
    And "Bob" has exactly one membership in "Friday Night"
    When I make "Bob" an owner of "Friday Night"
    Then "Bob" has exactly one membership in "Friday Night"
    When I am signed in as "Bob"
    And I view the group "Friday Night"
    Then I have owner access to the group
    When I reset the invitation for "Friday Night"
    Then the invitation code for "Friday Night" has changed
    When I make "Carol" an owner of "Friday Night"
    Then the group has these owners:
      | Alice |
      | Bob   |
      | Carol |

  @US10 @US09
  Scenario: A promoted owner can delete the shared group
    Given I am signed in as "Alice"
    When I make "Bob" an owner of "Friday Night"
    And I am signed in as "Bob"
    And I delete the group "Friday Night"
    Then I am told the group was deleted
    And the group "Friday Night" has been deleted
    And the viewer accounts still exist:
      | Alice |
      | Bob   |

  @US10 @US11 @US08
  Scenario: Ordinary members cannot promote themselves or remove other members
    Given I am signed in as "Bob"
    When I make "Bob" an owner of "Friday Night"
    Then only an owner is allowed to do that
    And "Bob" is an ordinary member of "Friday Night"
    When I remove "Alice" from "Friday Night"
    Then only an owner is allowed to do that
    And the invitation code for "Friday Night" is unchanged
    When I view the group "Friday Night"
    Then the group has these owners:
      | Alice |
    And member details contain names but no emails or invitation code

  @US10 @US11 @US08
  Scenario: Outsiders cannot change membership even if they know the group URL
    Given "Carol" has an account
    And I am signed in as "Carol"
    When I make "Bob" an owner of "Friday Night"
    Then the group is not available to me
    And the page contains no group details
    When I remove "Bob" from "Friday Night"
    Then the group is not available to me
    And the page contains no group details
    And "Bob" has exactly one membership in "Friday Night"
    And the invitation code for "Friday Night" is unchanged

  @US10 @US11
  Scenario: A person must belong to this group before an owner can manage them
    Given "Carol" has an account
    And "Carol" owns a group named "Film Club"
    And I am signed in as "Alice"
    When I make "Carol" an owner of "Friday Night"
    Then the group is not available to me
    When I remove "Carol" from "Friday Night"
    Then the group is not available to me
    And "Carol" has no membership in "Friday Night"
    And "Carol" has exactly one membership in "Film Club"
    And the invitation code for "Friday Night" is unchanged

  @US11 @US07 @US05
  Scenario: Removing a member ends access and replaces the saved invitation without deleting their account
    Given "Bob" owns a group named "Film Club"
    And I am signed in as "Alice"
    When I remove "Bob" from "Friday Night"
    Then the group has these members:
      | Alice |
    And "Bob" has no membership in "Friday Night"
    And the invitation code for "Friday Night" has changed
    And the viewer accounts still exist:
      | Alice |
      | Bob   |
    When I am signed in as "Bob"
    And I view my groups
    Then my group list contains only:
      | Film Club |
    When I view the group "Friday Night"
    Then the group is not available to me
    When I join "Friday Night" using its previous invitation
    Then I see an error for "code"
    And "Bob" has no membership in "Friday Night"
    When I join "Friday Night" using its shared invitation
    Then "Bob" is an ordinary member of "Friday Night"

  @US11 @US10 @US08
  Scenario: Removing another owner revokes that owner's management access immediately
    Given I am signed in as "Alice"
    When I make "Bob" an owner of "Friday Night"
    And I am signed in as "Bob"
    And I remove "Alice" from "Friday Night"
    Then the group has these owners:
      | Bob |
    And "Alice" has no membership in "Friday Night"
    And the invitation code for "Friday Night" has changed
    When I am signed in as "Alice"
    And I reset the invitation for "Friday Night"
    Then the group is not available to me
    When I make "Bob" an owner of "Friday Night"
    Then the group is not available to me
    When I delete the group "Friday Night"
    Then the group is not available to me
    When I am signed in as "Bob"
    And I view the group "Friday Night"
    Then I have owner access to the group

  @US11
  Scenario: An owner cannot remove themselves and leave the group without an owner
    Given I am signed in as "Alice"
    When I remove "Alice" from "Friday Night"
    Then I am told I cannot remove myself
    And the group has these owners:
      | Alice |
    And "Alice" has exactly one membership in "Friday Night"
    And the invitation code for "Friday Night" is unchanged

  @US10 @US11
  Scenario: Visitors must sign in before managing members
    Given I am signed out
    When I make "Bob" an owner of "Friday Night"
    Then I am asked to sign in
    When I remove "Bob" from "Friday Night"
    Then I am asked to sign in
    And "Bob" has exactly one membership in "Friday Night"
    And "Bob" is an ordinary member of "Friday Night"
