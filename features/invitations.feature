Feature: Invite friends to a private group
  As an owner, I want to share and replace a reusable invitation code.
  As a friend, I want to paste that code to join the right group.

  Background:
    Given "Alice" has an account
    And "Bob" has an account
    And "Alice" owns a group named "Friday Night"

  @US06 @US07 @US05
  Scenario: Two friends use the same invitation
    Given "Carol" has an account
    And "Alice" has shared an invitation to "Friday Night"
    And I am signed in as "Bob"
    When I join "Friday Night" using its shared invitation
    Then the group has these members:
      | Alice |
      | Bob   |
    And member details contain names but no emails or invitation code
    When I view my groups
    Then my group list contains only:
      | Friday Night |
    And my group list reports 2 members for "Friday Night"
    Given I am signed in as "Carol"
    When I join "Friday Night" using its shared invitation
    Then the group has these members:
      | Alice |
      | Bob   |
      | Carol |

  @US07
  Scenario: A pasted code tolerates spaces and different letter case
    Given "Alice" has shared an invitation to "Friday Night"
    And I am signed in as "Bob"
    When I join "Friday Night" using a lowercase invitation with surrounding spaces
    Then the group has these members:
      | Alice |
      | Bob   |

  @US07
  Scenario: Accepting the same invitation twice does not duplicate membership
    Given "Bob" joined "Friday Night" using an invitation
    And I am signed in as "Bob"
    When I join "Friday Night" using its shared invitation
    Then the group has these members:
      | Alice |
      | Bob   |
    And "Bob" has exactly one membership in "Friday Night"

  @US07
  Scenario: An owner can use their own invitation without adding another membership
    Given "Alice" has shared an invitation to "Friday Night"
    And I am signed in as "Alice"
    When I join "Friday Night" using its shared invitation
    Then the group has these members:
      | Alice |
    And "Alice" has exactly one membership in "Friday Night"

  @US06 @US08
  Scenario: Ordinary members cannot see or replace the invitation
    Given "Bob" joined "Friday Night" using an invitation
    And I am signed in as "Bob"
    When I view the group "Friday Night"
    Then member details contain names but no emails or invitation code
    When I reset the invitation for "Friday Night"
    Then only the owner is allowed to do that
    And the invitation code for "Friday Night" is unchanged

  @US06 @US08
  Scenario: An outsider cannot replace the invitation
    Given I am signed in as "Bob"
    When I reset the invitation for "Friday Night"
    Then the group is not available to me
    And the invitation code for "Friday Night" is unchanged

  @US06 @US07
  Scenario: Replacing a code rejects old invitations and keeps existing members
    Given "Carol" has an account
    And "Bob" joined "Friday Night" using an invitation
    And I am signed in as "Alice"
    When I reset the invitation for "Friday Night"
    Then the invitation code for "Friday Night" has changed
    And the group has these members:
      | Alice |
      | Bob   |
    Given I am signed in as "Carol"
    When I join "Friday Night" using its previous invitation
    Then I see an error for "code"
    When I view my groups
    Then my group list is empty
    When I join "Friday Night" using its shared invitation
    Then the group has these members:
      | Alice |
      | Bob   |
      | Carol |

  @US07
  Scenario: An invalid invitation does not grant membership
    Given I am signed in as "Bob"
    When I join using invitation code "NOT-A-VALID-CODE"
    Then I see an error for "code"
    When I view my groups
    Then my group list is empty

  @US07
  Scenario: An invitation still requires signing in
    Given "Alice" has shared an invitation to "Friday Night"
    And I am signed out
    When I join "Friday Night" using its shared invitation
    Then I am asked to sign in
    And "Bob" has no membership in "Friday Night"
