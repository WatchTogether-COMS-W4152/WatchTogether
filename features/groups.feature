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
