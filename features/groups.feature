Feature: Private watch groups
  As a viewer, I want a private space for my friends
  so that we can organize watching together.

  @US04
  Scenario: Create a group and become its owner and first member
    Given "Alice" has an account
    And I am signed in as "Alice"
    When I create a group named "Friday Night"
    Then the group is named "Friday Night" and owned by "Alice"
    And the group has these members:
      | Alice |
    When I view my groups
    Then my group list contains only:
      | Friday Night |
    And my group list reports 1 members for "Friday Night"

  @US04
  Scenario: A group needs a name
    Given "Alice" has an account
    And I am signed in as "Alice"
    When I create a group named ""
    Then I see an error for "name"
    When I view my groups
    Then my group list is empty
    And no group or membership was created

  @US05
  Scenario: My list contains only groups I belong to
    Given "Alice" has an account
    And "Bob" has an account
    And "Alice" owns a group named "Friday Night"
    And "Bob" owns a group named "Film Club"
    And I am signed in as "Alice"
    When I view my groups
    Then my group list contains only:
      | Friday Night |
    And group summaries contain no invitation codes or email addresses

  @US05 @US08
  Scenario: Knowing a private group's URL does not grant access
    Given "Alice" has an account
    And "Bob" has an account
    And "Alice" owns a group named "Friday Night"
    And I am signed in as "Bob"
    When I view the group "Friday Night"
    Then the group is not available to me
    And the page contains no group details

  @US04 @US05
  Scenario: A visitor must sign in before viewing or creating groups
    Given I am signed out
    When I view my groups
    Then I am asked to sign in
    When I create a group named "Friday Night"
    Then I am asked to sign in
    And no group or membership was created

  @US09
  Scenario: An owner deletes a group for everyone while keeping accounts and other groups
    Given "Alice" has an account
    And "Bob" has an account
    And "Alice" owns a group named "Friday Night"
    And "Bob" joined "Friday Night" using an invitation
    And "Alice" owns a group named "Film Club"
    And I am signed in as "Alice"
    When I delete the group "Friday Night"
    Then I am told the group was deleted
    And the group "Friday Night" has been deleted
    And the viewer accounts still exist:
      | Alice |
      | Bob   |
    And my group list contains only:
      | Film Club |
    When I am signed in as "Bob"
    And I view my groups
    Then my group list is empty
    When I view the group "Friday Night"
    Then the group is not available to me
    When I join "Friday Night" using its shared invitation
    Then I see an error for "code"
    And "Bob" has no membership in "Friday Night"

  @US09 @US08
  Scenario: Being a member does not allow deleting a group
    Given "Alice" has an account
    And "Bob" has an account
    And "Alice" owns a group named "Friday Night"
    And "Bob" joined "Friday Night" using an invitation
    And I am signed in as "Bob"
    When I delete the group "Friday Night"
    Then only an owner is allowed to do that
    When I view the group "Friday Night"
    Then the group has these members:
      | Alice |
      | Bob   |

  @US09 @US08
  Scenario: Knowing a group's URL does not allow deleting it
    Given "Alice" has an account
    And "Bob" has an account
    And "Alice" owns a group named "Friday Night"
    And I am signed in as "Bob"
    When I delete the group "Friday Night"
    Then the group is not available to me
    And the page contains no group details
    When I am signed in as "Alice"
    And I view the group "Friday Night"
    Then the group has these members:
      | Alice |

  @US09
  Scenario: A visitor must sign in before deleting a group
    Given "Alice" has an account
    And "Alice" owns a group named "Friday Night"
    And I am signed out
    When I delete the group "Friday Night"
    Then I am asked to sign in
    When I am signed in as "Alice"
    And I view the group "Friday Night"
    Then the group has these members:
      | Alice |
