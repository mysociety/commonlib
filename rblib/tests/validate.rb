$:.push(File.join(File.dirname(__FILE__), '..'))
require 'validate'
require 'test/unit'

class TestPostcode < Test::Unit::TestCase

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
  
end