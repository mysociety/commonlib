# encoding: UTF-8
$:.push(File.join(File.dirname(__FILE__), '..'))
require 'validate'
require 'test/unit'
class TestValidate < Test::Unit::TestCase

  def test_is_valid_postcode
    # examples from
    # http://www.cabinetoffice.gov.uk/govtalk/schemasstandards/e-gif/datastandards/address/postcode.aspx
    assert(MySociety::Validate::is_valid_postcode("M1 1AA"))
    assert(MySociety::Validate::is_valid_postcode("M60 1NW"))
    assert(MySociety::Validate::is_valid_postcode("CR2 6XH"))
    assert(MySociety::Validate::is_valid_postcode("DN55 1PT"))
    assert(MySociety::Validate::is_valid_postcode("W1A 1HQ"))
    assert(MySociety::Validate::is_valid_postcode("EC1A 1BB"))

    # mySociety test postcodes
    assert(MySociety::Validate::is_valid_postcode("ZZ9 9ZZ"))
    assert(MySociety::Validate::is_valid_postcode("ZZ9 9ZY"))

    # negative examples
    assert(!MySociety::Validate::is_valid_postcode("EC1A 1CB"))
  end

  def test_is_valid_partial_postcode
    # examples from
    # http://www.cabinetoffice.gov.uk/govtalk/schemasstandards/e-gif/datastandards/address/postcode.aspxassert(MySociety::Validate::is_valid_partial_postcode("M1"))
    assert(MySociety::Validate::is_valid_partial_postcode("M60"))
    assert(MySociety::Validate::is_valid_partial_postcode("CR2"))
    assert(MySociety::Validate::is_valid_partial_postcode("DN55"))
    assert(MySociety::Validate::is_valid_partial_postcode("W1A"))
    assert(MySociety::Validate::is_valid_partial_postcode("EC1A"))

    # mySociety test postcodes
    assert(MySociety::Validate::is_valid_partial_postcode("ZZ9"))
  end

  def test_all_upper_case
    uppercase_text = "I LIKE TO SHOUT, IT IS FUN. I ESPECIALLY LIKE TO DO SO FOR QUITE A LONG TIME, AND WHEN I DISABLED MY CAPS LOCK KEY."
    assert(MySociety::Validate.uses_mixed_capitals(uppercase_text) == false)
  end

  def test_all_lower_case
    lowercase_text = "(i who have died am alive again today,
                      and this is the sun's birthday;this is the birth
                      day of life and love and wings:and of the gay
                      great happening illimitably earth)"
    assert(MySociety::Validate.uses_mixed_capitals(lowercase_text) == false)
  end

  def test_mixed_case
    mixed_case_text = "This is a normal sentence. It is followed by another, and overall it is quite a long chunk of text so it exceeds the minimum limit."
    assert(MySociety::Validate.uses_mixed_capitals(mixed_case_text) == true)
  end

  def test_mixed_case_without_urls
    mixed_case_with_urls = "
    The public authority appears to have aggregated this request with the following requests on this site:

    http://www.whatdotheyknow.com/request/financial_value_of_post_dismissa_2

    http://www.whatdotheyknow.com/request/number_of_post_dismissal_compens_2

    http://www.whatdotheyknow.com/request/number_of_post_dismissal_compens_3

    ...and has given one response to all four of these requests, available here:

    http://www.whatdotheyknow.com/request/financial_value_of_post_dismissa_2#incoming-105717

    The information requested in this request was not provided, however the information requested in the following request was provided:

    http://www.whatdotheyknow.com/request/number_of_post_dismissal_compens_3"
    assert(MySociety::Validate.uses_mixed_capitals(mixed_case_with_urls) == true)
  end

  def test_is_valid_email
    assert(MySociety::Validate.is_valid_email("mr.example@example.com") != nil)
  end

  def test_unicode_localpart_is_not_valid_email
    assert(MySociety::Validate.is_valid_email("Pelé@example.com") == nil)
  end

  def test_localpart_with_unquoted_space_is_not_valid_email
    assert(MySociety::Validate.is_valid_email("thisis .myname@example.com") == nil)
  end

  def test_domain_part_with_unquoted_space_is_not_valid_email
    assert(MySociety::Validate.is_valid_email("thisis.myname@ example.com") == nil)
  end

  def test_subdomain_part_with_unquoted_space_is_not_valid_email
    assert(MySociety::Validate.is_valid_email("thisis.myname@example .com") == nil)
  end

end
