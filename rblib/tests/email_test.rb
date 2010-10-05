$:.push(File.join(File.dirname(__FILE__), '..'))
require 'email'
require 'test/unit'
# Use rspec if loadable 
begin 
  require 'spec/test/unit'
rescue LoadError
  puts "Not using rspec"
end

def load_example(filename)
  filepath = File.join(File.dirname(__FILE__), 'email_examples', "#{filename}.txt")
  content = File.read(filepath)
end

def example_mail(filename)
  mail_body = load_example(filename)
  mail = MySociety::Email::Mail.parse(mail_body)
  mail.base64_decode
  mail  
end

class TestEmailAttachments < Test::Unit::TestCase
  
  def setup
    @mail = example_mail('attachments')
  end

  def test_attachments_flattened      
    attachments = MySociety::Email.get_display_attachments(@mail)
    assert_equal(3, attachments.size)
  end
  
  def test_attachment_display_filenames
    attachments = MySociety::Email.get_display_attachments(@mail)
    assert_equal('Same attachment twice.txt', attachments[0].display_filename)
    assert_equal('hello.txt', attachments[1].display_filename)
    assert_equal('hello.txt', attachments[2].display_filename)
  end
  
  def test_attachment_custom_display_filenames
    attachments = MySociety::Email.get_display_attachments(@mail) do |filename|
      return nil unless filename
      return "custom_#{filename}"
    end
    assert_equal('Same attachment twice.txt', attachments[0].display_filename)
    assert_equal('custom_hello.txt', attachments[1].display_filename)
    assert_equal('custom_hello.txt', attachments[2].display_filename)    
  end
  
  def test_attachment_display_filenames_with_slashes
    attributes = {:filename => "FOI/09/066 RESPONSE TO FOI REQUEST RECEIVED 21st JANUARY 2009.txt"}
    attachment = MySociety::Email::Attachment.new(attributes)
    expected_display_filename = "FOI 09 066 RESPONSE TO FOI REQUEST RECEIVED 21st JANUARY 2009.txt"
    assert_equal(expected_display_filename, attachment.display_filename)
  end
  
  def test_attachment_display_subject_filenames_with_slashes
    attachment = MySociety::Email::Attachment.new({:content_type => 'text/plain'})
    attachment.is_email = true
    attachment.subject = "FOI/09/066 RESPONSE TO FOI REQUEST RECEIVED 21st JANUARY 2009"
    expected_display_filename = "FOI 09 066 RESPONSE TO FOI REQUEST RECEIVED 21st JANUARY 2009.txt"
    assert_equal(expected_display_filename, attachment.display_filename)
  end
  
  def test_attachment_zip_failure
    mock_entry = mock('ZipFile entry', :file? => true)
    mock_entry.stub!(:get_input_stream).and_raise("invalid distance too far back")
    Zip::ZipFile.stub!(:open).and_return([mock_entry])
    MySociety::Email._get_attachment_text_internal_one_file('application/zip', "some string")
  end
    
end

class TestAttachmentHeaders < Test::Unit::TestCase
  
  def setup 
    @mail = example_mail('attachment_headers')
  end
  
  def test_attachment_headers_added
    attachments = MySociety::Email.get_display_attachments(@mail)
    attachment = attachments.first.body
    assert_match('From: Sender <sender@example.com>', attachment)
    assert_match('To: Recipient <recipient@example.com>', attachment)
    assert_match('Cc: CC Recipient <cc@example.com>, CC Recipient 2 <cc2@example.com>, CC Recipient 3 <cc3@example.com>', attachment)
  end
  
  def test_blank_header_not_added
    attachments = MySociety::Email.get_display_attachments(@mail)
    attachment = attachments.first.body
    assert_no_match(/Date:/, attachment)
  end
  
end

class TestOftAttachments < Test::Unit::TestCase
  
  def setup
    @mail = example_mail('oft_attachments')
  end
  
  def test_oft_attachments_flattened
    attachments = MySociety::Email.get_display_attachments(@mail)
    assert_equal(2,attachments.size)
  end
  
  def test_oft_attachment_display_filenames
    attachments = MySociety::Email.get_display_attachments(@mail)
    # picks HTML rather than text by default, as likely to render better
    assert_equal('test.html', attachments[0].display_filename)
    assert_equal('attach.txt', attachments[1].display_filename)
  end
  
end

class TestTnefAttachments < Test::Unit::TestCase
  
  def setup
    @mail = example_mail('tnef')
  end
  
  def test_tnef_attachments_flattened
    attachments = MySociety::Email.get_display_attachments(@mail)
    assert_equal(2, attachments.size)
  end
  
  def test_tnef_attachment_display_filenames
    attachments = MySociety::Email.get_display_attachments(@mail)
    assert_equal('FOI 09 02976i.doc', attachments[0].display_filename)
    assert_equal('FOI 09 02976iii.doc', attachments[1].display_filename)
  end

end

class TestFolding < Test::Unit::TestCase

  def test_handles_left_square_bracket_in_names
    text = MySociety::Email.remove_lotus_quoting("Sir [ Bobble \nSent by: \n", "Sir [ Bobble")
    assert_equal("\n\nFOLDED_QUOTED_SECTION", text)
  end
  
  def test_handles_lotus_quoting_in_html
    text = "Jennifer James <request@example.com>
Sent by: Jennifer James <request@example.com>
06/03/08 10:00
Please respond to
Jennifer James <request@example.com>"
    text = text.gsub(/ +/, " ")
    text = MySociety::Email.remove_lotus_quoting(text, 'Jennifer James')
    assert_equal("\n\nFOLDED_QUOTED_SECTION", text)
  end

end

class TestAttachmentText < Test::Unit::TestCase
  
  def test_extracts_text_from_html
    html_text = "some <b>HTML</b> for decoding"
    text = MySociety::Email._get_attachment_text_internal_one_file("text/html", html_text)
    assert_equal("   some HTML for decoding\n\n\n", text)
  end
  
  
end
