require 'rubygems'
require 'test/unit'
require 'pathname'
require 'pp'

dir = Pathname.new File.expand_path(File.dirname(__FILE__))
require dir + '..' + 'lib' + 'email_reply_parser'

EMAIL_FIXTURE_PATH = dir + 'emails'

class EmailReplyParserTest < Test::Unit::TestCase
  def test_reads_simple_body
    reply = email(:email_1_1)
    assert_equal 3, reply.fragments.size

    assert reply.fragments.none? { |f| f.quoted? }
    assert_equal [false, true, true],
      reply.fragments.map { |f| f.signature? }
    assert_equal [false, true, true],
      reply.fragments.map { |f| f.hidden? }

    assert_equal "Hi folks

What is the best way to clear a Riak bucket of all key, values after
running a test?
I am currently using the Java HTTP API.\n", reply.fragments[0].to_s

    assert_equal "-Abhishek Kona\n\n", reply.fragments[1].to_s
  end

  def test_reads_top_post
    reply = email(:email_1_3)
    assert_equal 5, reply.fragments.size

    assert_equal [false, false, true, false, false],
      reply.fragments.map { |f| f.quoted? }
    assert_equal [false, true, true, true, true],
      reply.fragments.map { |f| f.hidden? }
    assert_equal [false, true, false, false, true],
      reply.fragments.map { |f| f.signature? }

    assert_match /^Oh thanks.\n\nHaving/, reply.fragments[0].to_s
    assert_match /^-A/, reply.fragments[1].to_s
    assert_match /^On [^\:]+\:/, reply.fragments[2].to_s
    assert_match /^_/, reply.fragments[4].to_s
  end

  def test_reads_bottom_post
    reply = email(:email_1_2)
    assert_equal 6, reply.fragments.size

    assert_equal [false, true, false, true, false, false],
      reply.fragments.map { |f| f.quoted? }
    assert_equal [false, false, false, false, false, true],
      reply.fragments.map { |f| f.signature? }
    assert_equal [false, false, false, true, true, true],
      reply.fragments.map { |f| f.hidden? }

    assert_equal "Hi,", reply.fragments[0].to_s
    assert_match /^On [^\:]+\:/, reply.fragments[1].to_s
    assert_match /^You can list/, reply.fragments[2].to_s
    assert_match /^> /, reply.fragments[3].to_s
    assert_match /^_/, reply.fragments[5].to_s
  end

  def test_reads_inline_replies
    reply = email(:email_1_8)
    assert_equal 7, reply.fragments.size

    assert_equal [true, false, true, false, true, false, false],
      reply.fragments.map { |f| f.quoted? }
    assert_equal [false, false, false, false, false, false, true],
      reply.fragments.map { |f| f.signature? }
    assert_equal [false, false, false, false, true, true, true],
      reply.fragments.map { |f| f.hidden? }

    assert_match /^On [^\:]+\:/, reply.fragments[0].to_s
    assert_match /^I will reply/, reply.fragments[1].to_s
    assert_match "okay?", reply.fragments[2].to_s
    assert_match /^and under this./, reply.fragments[3].to_s
    assert_match /inline/, reply.fragments[4].to_s
    assert_equal "\n", reply.fragments[5].to_s
    assert_equal "--\nHey there, this is my signature\n", reply.fragments[6].to_s
  end

  def test_recognizes_date_string_above_quote
    reply = email :email_1_4

    assert_match /^Awesome/, reply.fragments[0].to_s
    assert_match /^On/,      reply.fragments[1].to_s
    assert_match /Loader/,   reply.fragments[1].to_s
  end

  def test_a_complex_body_with_only_one_fragment
    reply = email :email_1_5

    assert_equal 1, reply.fragments.size
  end

  def test_reads_email_with_correct_signature
    reply = email :correct_sig

    assert_equal 2, reply.fragments.size
    assert_equal [false, false], reply.fragments.map { |f| f.quoted? }
    assert_equal [false, true], reply.fragments.map { |f| f.signature? }
    assert_equal [false, true], reply.fragments.map { |f| f.hidden? }
    assert_match /^-- \nrick/, reply.fragments[1].to_s
  end

  def test_deals_with_multiline_reply_headers
    reply = email :email_1_6

    assert_match /^I get/,   reply.fragments[0].to_s
    assert_match /^On/,      reply.fragments[1].to_s
    assert_match /Was this/, reply.fragments[1].to_s
  end

  def test_deals_with_windows_line_endings
    reply = email :email_1_7

    assert_match /:\+1:/,     reply.fragments[0].to_s
    assert_match /^On/,       reply.fragments[1].to_s
    assert_match /Steps 0-2/, reply.fragments[1].to_s
  end

  def test_does_not_modify_input_string
    original = "The Quick Brown Fox Jumps Over The Lazy Dog"
    EmailReplyParser.read original
    assert_equal "The Quick Brown Fox Jumps Over The Lazy Dog", original
  end

  def test_returns_only_the_visible_fragments_as_a_string
    reply = email(:email_2_1)
    assert_equal reply.fragments.select{|r| !r.hidden?}.map{|r| r.to_s}.join("\n").rstrip, reply.visible_text
  end

  def test_parse_out_just_top_for_outlook_reply
    body = IO.read EMAIL_FIXTURE_PATH.join("email_2_1.txt").to_s
    assert_equal "Outlook with a reply", EmailReplyParser.parse_reply(body)
  end

  def test_parse_out_just_top_for_outlook_with_reply_directly_above_line
    body = IO.read EMAIL_FIXTURE_PATH.join("email_2_2.txt").to_s
    assert_equal "Outlook with a reply directly above line", EmailReplyParser.parse_reply(body)
  end

  def test_parse_out_sent_from_iPhone
    body = IO.read EMAIL_FIXTURE_PATH.join("email_iPhone.txt").to_s
    assert_equal "Here is another email", EmailReplyParser.parse_reply(body)
  end

  def test_parse_out_sent_from_BlackBerry
    body = IO.read EMAIL_FIXTURE_PATH.join("email_BlackBerry.txt").to_s
    assert_equal "Here is another email", EmailReplyParser.parse_reply(body)
  end

  def test_parse_out_send_from_multiword_mobile_device
    body = IO.read EMAIL_FIXTURE_PATH.join("email_multi_word_sent_from_my_mobile_device.txt").to_s
    assert_equal "Here is another email", EmailReplyParser.parse_reply(body)
  end

  def test_do_not_parse_out_send_from_in_regular_sentence
    body = IO.read EMAIL_FIXTURE_PATH.join("email_sent_from_my_not_signature.txt").to_s
    assert_equal "Here is another email\n\nSent from my desk, is much easier then my mobile phone.", EmailReplyParser.parse_reply(body)
  end

  def test_retains_bullets
    body = IO.read EMAIL_FIXTURE_PATH.join("email_bullets.txt").to_s
    assert_equal "test 2 this should list second\n\nand have spaces\n\nand retain this formatting\n\n\n   - how about bullets\n   - and another",
      EmailReplyParser.parse_reply(body)
  end

  def test_parse_reply
    body = IO.read EMAIL_FIXTURE_PATH.join("email_1_2.txt").to_s
    assert_equal EmailReplyParser.read(body).visible_text, EmailReplyParser.parse_reply(body)
  end

  def test_one_is_not_on
    reply = email("email_one_is_not_on")
    assert_match /One outstanding question/, reply.fragments[0].to_s
    assert_match /^On Oct 1, 2012/, reply.fragments[1].to_s
  end

  def test_pathological_emails
    t0 = Time.now
    reply = email("pathological")
    assert (Time.now - t0) < 1, "Took too long, upgrade to re2 gem."
  end

  def test_doesnt_remove_signature_delimiter_in_mid_line
    reply = email(:email_sig_delimiter_in_middle_of_line)
    assert_equal 1, reply.fragments.size
  end

  def email(name)
    body = IO.read EMAIL_FIXTURE_PATH.join("#{name}.txt").to_s
    EmailReplyParser.read body
  end
end
