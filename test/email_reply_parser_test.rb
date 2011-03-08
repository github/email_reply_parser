require 'rubygems'
require 'test/unit'
require 'pathname'
require 'pp'

dir = Pathname.new File.expand_path(File.dirname(__FILE__))
require dir + '..' + 'lib' + 'email_reply_parser'

EMAIL_FIXTURE_PATH = dir + 'emails'

class EmailReplyParserTest < Test::Unit::TestCase
  def test_marks_nothing_hidden_on_a_single_reply_thread
    reply = EmailReplyParser.read(email(:email_1_2))
    assert reply.blocks.none? { |b|
      b.paragraphs.any? { |para| para.hidden? } }
  end

  def test_marks_common_reply_portions_hidden_on_thread
    reply1 = EmailReplyParser.read(email(:email_1_1))
    reply2 = EmailReplyParser.read(email(:email_1_2), reply1.shas)
    assert reply1.blocks.none? { |b|
      b.paragraphs.any? { |para| para.hidden? } }
    assert  reply2.blocks[4].hidden?
    assert  reply2.blocks[3].hidden?
    assert !reply2.blocks[2].hidden?
  end

  def test_reads_simple_body
    body   = email :email_1_1
    blocks = EmailReplyParser::Reply.new(body).blocks
    assert_equal 1, blocks.size
    assert_match /Hi folks/, blocks.first.to_s
  end

  def test_reads_bottom_poster
    body   = email :email_1_2
    blocks = EmailReplyParser::Reply.new(body).blocks
    assert_equal 5, blocks.size
    assert_equal [0,1,0,1,0], blocks.map { |b| b.levels }
  end

  def test_reads_multi_level_replies
    body   = email :email_1_3
    blocks = EmailReplyParser::Reply.new(body).blocks
    assert_equal 7, blocks.size
    assert_equal [0,1,2,1,2,1,0], blocks.map { |b| b.levels }
  end

  def test_stores_shas_of_blocks
    body   = email :email_1_3
    blocks = EmailReplyParser::Reply.new(body).blocks
    assert_equal 19, blocks.inject(0) { |n, b| n + b.paragraphs.size }
    assert_equal 1,  blocks[6].paragraphs.size
    # check for the repeated mailing list footer
    blocks[6].paragraphs.each do |para|
      last = blocks[4].paragraphs.last
      assert_equal para.sha, last.sha
      assert last.include?(para.sha)
      assert para.signature?, "only para of block 6 is not a signature"
      assert last.signature?,
        "matching sha in para 4 is not a signature"
    end
  end

  def test_tracks_signature_blocks
    body  = email :email_1_1
    block = EmailReplyParser::Reply.new(body).blocks.first
    assert_equal 4, block.paragraphs.size
    block.paragraphs.each do |para|
      if para.start == 6
        assert_equal 6, para.end
        assert para.signature?, "para on line 6 is not a signature"
      elsif para.start == 9
        assert_equal 12, para.end
        assert para.signature?, "para on line 9 is not a signature"
      else
        assert !para.signature?, "para on line #{para.start} is a signature"
      end
    end
    assert block.paragraphs.last.signature?
  end

  def email(name)
    IO.read EMAIL_FIXTURE_PATH.join("#{name}.txt").to_s
  end
end
