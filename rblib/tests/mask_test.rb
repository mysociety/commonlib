# -*- encoding : utf-8 -*-
$:.push(File.join(File.dirname(__FILE__), '..'))
require 'mask'
require 'test/unit'

class TestMask < Test::Unit::TestCase

  def test_masks_email
    text = "and another@foo.com"
    expected_text = "and [email address]"
    assert(MySociety::Mask.mask_emails(text) == expected_text)
  end

  def test_masks_mobile
    text = "Telephone 98765 432109 Mobile 87654 321098"
    expected_text = "Telephone 98765 432109 [mobile number]"
    assert(MySociety::Mask::mask_mobiles(text) == expected_text)

    text = "Mob Tel: 123456 789 012"
    expected_text = "[mobile number]"
    assert(MySociety::Mask::mask_mobiles(text) == expected_text)

    text = "Mob/Fax: 01234 567890"
    expected_text = "[mobile number]"
    assert(MySociety::Mask::mask_mobiles(text) == expected_text)
  end

end

