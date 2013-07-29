# encoding: UTF-8
$:.push(File.join(File.dirname(__FILE__), '..'))
require 'format'
require 'test/unit'

class TestFormat < Test::Unit::TestCase

  def expect_clickable(text, expected)
    text = CGI.escapeHTML(text)
    formatted = MySociety::Format.make_clickable(text)
    assert(formatted == expected)
  end

  def test_make_clickable
    text = "Hello http://www.flourish.org goodbye"
    expected = "Hello <a href='http://www.flourish.org'>http://www.flourish.org</a> goodbye"
    expect_clickable(text, expected)
  end

  def test_make_wrapped_urls_in_angle_brackets_clickable
    text = """<http://www.flou
rish.org/bl
og>

More stuff and then another angle bracket >"""
    expected = "&lt;<a href='http://www.flourish.org/blog'>http://www.flourish.org/blog</a>&gt;\n\nMore stuff and then another angle bracket &gt;"
    expect_clickable(text, expected)

    text = """<https://web.nhs.net/owa/redir.aspx?C=25a8af7e66054d62a435313f7f3d4694&URL=h
ttp%3a%2f%2fwww.ico.gov.uk%2fupload%2fdocuments%2flibrary%2ffreedom_of_infor
mation%2fdetailed_specialist_guides%2fname_of_applicant_fop083_v1.pdf> Valid
request - name and address for correspondence

If we can be of any further assistance please contact our Helpline on 08456
30 60 60 or 01625 545745 if you would prefer to call a national rate number,
quoting your case reference number. You may also find some useful
information on our website at
<https://web.nhs.net/owa/redir.aspx?C=25a8af7e66054d62a435313f7f3d4694&URL=h
ttp%3a%2f%2fwww.ico.gov.uk%2f> www.ico.gov.uk."""

    expected = """&lt;<a href='https://web.nhs.net/owa/redir.aspx?C=25a8af7e66054d62a435313f7f3d4694&amp;URL=http%3a%2f%2fwww.ico.gov.uk%2fupload%2fdocuments%2flibrary%2ffreedom_of_information%2fdetailed_specialist_guides%2fname_of_applicant_fop083_v1.pdf'>https://web.nhs.net/owa/redir.aspx?C=25a8af7e66054d62a435313f7f3d4694&amp;URL=http%3a%2f%2fwww.ico.gov.uk%2fupload%2fdocuments%2flibrary%2ffreedom_of_information%2fdetailed_specialist_guides%2fname_of_applicant_fop083_v1.pdf</a>&gt; Valid
request - name and address for correspondence

If we can be of any further assistance please contact our Helpline on 08456
30 60 60 or 01625 545745 if you would prefer to call a national rate number,
quoting your case reference number. You may also find some useful
information on our website at
&lt;<a href='https://web.nhs.net/owa/redir.aspx?C=25a8af7e66054d62a435313f7f3d4694&amp;URL=http%3a%2f%2fwww.ico.gov.uk%2f'>https://web.nhs.net/owa/redir.aspx?C=25a8af7e66054d62a435313f7f3d4694&amp;URL=http%3a%2f%2fwww.ico.gov.uk%2f</a>&gt; <a href='http://www.ico.gov.uk'>www.ico.gov.uk</a>."""
    expect_clickable(text, expected)

  end

  def test_unicode_transliteration
    default_name = 'body'
    text = 'Državno sodišče'
    expected = 'drzavno_sodisce'
    assert MySociety::Format.simplify_url_part(text, default_name) == expected

    text = 'Реактор Большой Мощности Канальный'
    expected = 'rieaktor_bolshoi_moshchnosti_kanalnyi'
    assert MySociety::Format.simplify_url_part(text, default_name) == expected

    text = 'Prefeitura de Curuçá - PA '
    expected = 'prefeitura_de_curuca_pa'
    assert MySociety::Format.simplify_url_part(text, default_name) == expected

    text = 'Prefeitura de Curuá - PA '
    expected = 'prefeitura_de_curua_pa'
    assert MySociety::Format.simplify_url_part(text, default_name) == expected

    text = 'Prefeitura de Pirajuí - SP'
    expected = 'prefeitura_de_pirajui_sp'
    assert MySociety::Format.simplify_url_part(text, default_name) == expected

    text = 'Siméon'
    expected = 'simeon'
    assert MySociety::Format.simplify_url_part(text, default_name) == expected
  end

end
