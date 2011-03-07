require 'rubygems'
require 'test/unit'
require 'pathname'
require 'pp'

dir = Pathname.new File.expand_path(File.dirname(__FILE__))
require dir + '..' + 'lib' + 'email_reply_parser'

EMAIL_FIXTURE_PATH = dir + 'emails'

class EmailReplyParserTest < Test::Unit::TestCase
  def test_reads_simple_body
    body   = email :email_1_1
    blocks = EmailReplyParser.scan(body)
    assert_equal 1, blocks.size
    assert_match /Hi folks/, blocks.first.to_s
  end

  def test_reads_bottom_poster
    body   = email :email_1_2
    blocks = EmailReplyParser.scan(body)
    assert_equal 5, blocks.size
    assert_equal [0,1,0,1,0], blocks.map { |b| b.levels }
  end

  def test_reads_multi_level_replies
    body   = email :email_1_3
    blocks = EmailReplyParser.scan(body)
    assert_equal 7, blocks.size
    assert_equal [0,1,2,1,2,1,0], blocks.map { |b| b.levels }
  end

  def test_stores_shas_of_blocks
    body   = email :email_1_3
    blocks = EmailReplyParser.scan(body)
    assert_equal 19, blocks.inject(0) { |n, b| n + b.shas.size }
    assert_equal 1,  blocks[6].shas.size
    blocks[6].shas.each do |sha, hash|
      assert blocks[4].shas.key?(sha)
    end
  end

  def email(name)
    IO.read EMAIL_FIXTURE_PATH.join("#{name}.txt").to_s
  end
end
