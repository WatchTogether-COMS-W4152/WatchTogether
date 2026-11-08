Feature: Personal accounts and profiles
  As a viewer, I want an identifiable account and a private session
  so that my friends recognize me in our watch groups.

  @US01
  Scenario: Register and immediately start using my account
    When I register with:
      | display_name          | Alice             |
      | email                 | Alice@Example.com |
      | password              | CourseProject123! |
      | password_confirmation | CourseProject123! |
    Then I am signed in with display name "Alice" and email "alice@example.com"
    And my session expires in 30 days
    And the page contains no password or session credentials
    When I visit my profile
    Then I am signed in with display name "Alice" and email "alice@example.com"

  @US01
  Scenario Outline: Explain invalid registration without creating an account
    When I register with:
      | display_name          | <name>         |
      | email                 | <email>        |
      | password              | <password>     |
      | password_confirmation | <confirmation> |
    Then I see an error for "<field>"
    And no account or authenticated session was created

    Examples:
      | name  | email             | password          | confirmation       | field                 |
      |       | alice@example.com | CourseProject123! | CourseProject123!  | display_name          |
      | Alice | not-an-email      | CourseProject123! | CourseProject123!  | email                 |
      | Alice | alice@example.com | short             | short              | password              |
      | Alice | alice@example.com | CourseProject123! | DifferentPassword! | password_confirmation |

  @US01
  Scenario: An email address identifies one account regardless of case
    Given "Alice" has an account
    When I register with:
      | display_name          | Another Alice     |
      | email                 | ALICE@EXAMPLE.COM |
      | password              | CourseProject123! |
      | password_confirmation | CourseProject123! |
    Then I see an error for "email"
    And there is still only one account

  @US02
  Scenario: Sign in to my existing account
    Given "Alice" has an account
    When I sign in with email "ALICE@EXAMPLE.COM" and password "CourseProject123!"
    Then I am signed in with display name "Alice" and email "alice@example.com"
    And my session expires in 30 days
    And the page contains no password or session credentials

  @US02
  Scenario Outline: Reject an incorrect email or password
    Given "Alice" has an account
    When I sign in with email "<email>" and password "<password>"
    Then I remain signed out and see a sign-in error

    Examples:
      | email               | password          |
      | alice@example.com   | IncorrectPassword |
      | unknown@example.com | CourseProject123! |

  @US02
  Scenario: Signing out invalidates the old browser session
    Given "Alice" has an account
    And I am signed in as "Alice"
    When I sign out
    Then I am asked to sign in
    And that session has been revoked on the server
    When I reuse the previous session cookie and visit my profile
    Then I am asked to sign in

  @US02
  Scenario: An expired session returns me to sign-in
    Given "Alice" has an account
    And I am signed in as "Alice"
    And my session has expired
    When I visit my profile
    Then I am asked to sign in

  @US02
  Scenario: A signed-out visitor cannot open a profile
    Given I am signed out
    When I visit my profile
    Then I am asked to sign in

  @US03
  Scenario: Update the name my friends see
    Given "Alice" has an account
    And "Alice" owns a group named "Friday Night"
    And I am signed in as "Alice"
    When I change my display name to "Ali"
    Then I am signed in with display name "Ali" and email "alice@example.com"
    When I visit my profile
    Then I am signed in with display name "Ali" and email "alice@example.com"
    When I view the group "Friday Night"
    Then the group has these members:
      | Ali |

  @US03
  Scenario: A rejected name change preserves my previous name
    Given "Alice" has an account
    And I am signed in as "Alice"
    When I change my display name to ""
    Then I see an error for "display_name"
    When I visit my profile
    Then I am signed in with display name "Alice" and email "alice@example.com"
