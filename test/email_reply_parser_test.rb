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

  def email(name)
    body = IO.read EMAIL_FIXTURE_PATH.join("#{name}.txt").to_s
    EmailReplyParser.read body
  end
end
