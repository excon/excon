@requests
Feature: Basic HTTP requests
  In order have confidence in Excon and it's more advanced featurees
  As a user actor
  I want to ensure the basic functionality works

  Scenario: Basic Request
    Given a basic web server
    And a basic excon client
    When a user gets "/content-length/100"
    Then the user should receive a response
    And the status is "200"
    And the Content-Length header field is "100"
    And the Content-Type header field is "text/html;charset=utf-8"
    And the Date header field is a valid date
    And the Server header field matches "WEBrick"
    And the remote ip is "127.0.0.1"
