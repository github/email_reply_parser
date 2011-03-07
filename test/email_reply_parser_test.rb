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
    # check for the repeated mailing list footer
    blocks[6].shas.each do |sha, hash|
      assert hash[:signature], "only para of block 6 is not a signature"
      assert blocks[4].shas[sha][:signature],
        "matching sha in para 4 is not a signature"
    end
  end

  def test_tracks_signature_blocks
    body  = email :email_1_1
    block = EmailReplyParser.scan(body).first
    assert_equal 4, block.shas.size
    block.shas.each do |sha, hash|
      if hash[:start] == 6
        assert_equal 6, hash[:end]
        assert hash[:signature], "para on line 6 is not a signature"
      elsif hash[:start] == 9
        assert_equal 12, hash[:end]
        assert hash[:signature], "para on line 9 is not a signature"
      else
        assert !hash[:signature], "para on line #{hash[:start]} is a signature"
      end
    end
  end

  def email(name)
    IO.read EMAIL_FIXTURE_PATH.join("#{name}.txt").to_s
  end
end
