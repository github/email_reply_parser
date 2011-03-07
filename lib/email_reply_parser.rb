require 'strscan'
require 'digest/sha1'
require 'set'

class EmailReplyParser
  VERSION = "0.1.0"

  def self.read(bodies, shas = nil)
    bodies.map do |text|
      r = Reply.new(text, shas)
      shas = r.shas
      r
    end
  end

  class Reply
    attr_reader :blocks, :shas

    def initialize(text, shas = nil)
      @blocks  = []
      block    = nil
      @shas    = shas || Set.new
      scanner  = StringScanner.new(text)
      while line = scanner.scan_until(/\n/)
        line.rstrip!
        line_levels = 0
        if line =~ /^(>+)/
          line_levels = $1.size
        end
        if !block || block.levels != line_levels
          block.finish if block
          @blocks << (block = Block.new(
            :levels => line_levels,
            :shas   => shas))
        end
        block << line
      end
      @blocks.last.finish if @blocks.size > 0
      scan_for_hidden
    end

  private
    def scan_for_hidden
      @blocks.reverse.each do |block|
        block.paragraphs.reverse.each do |para|
          if !(para.is_hidden = (
                block.reply? ||
                (para.signature? && @shas.include?(para.sha))
              ))
            return
          end
        end
      end
    end
  end

  class Block
    attr_reader :levels

    def initialize(options = {})
      @levels = options[:levels].to_i
      @lines  = []
      @shas   = options[:shas] || Set.new
      @paras  = []
      @line   = -1  # current line number
      @para   = nil # current paragraph
      @joined = nil
      @hidden = nil
    end

    def hidden?
      if @hidden.nil?
        @hidden = (p = @paras.first and p.hidden?) || false
      end
      @hidden
    end

    def reply?
      @levels > 0
    end

    def paragraphs
      @paras
    end

    def <<(line)
      update_paragraph(line)
      @lines << line
    end

    def include?(sha)
      @shas.include?(sha)
    end

    def to_s
      @joined ||= @lines.join("\n")
    end

    def finish
      end_para
    end

    def inspect
      to_s.inspect
    end

  private
    def update_paragraph(line)
      @line   += 1
      stripped = line.sub(/^(\s|>)+/, '')
      if stripped.size.zero?
        end_para(@line-1)
      else
        if !@para
          start_para
          @para.is_signature = !!(stripped =~ /^[\-|_]/)
        end
        stripped.gsub! /\s[^\w\s]+\s/, ' '
        stripped.gsub! /\s+/, ' '
        stripped.downcase!
        @para.update stripped
      end
    end

    def start_para
      @paras << (@para = Paragraph.new(@line))
    end

    def end_para(ending_line = @line)
      return if !@para
      @shas << @para.finish(ending_line).sha
      @para = nil
    end
  end

  class Paragraph < Struct.new(:start, :end, :sha, :is_signature, :is_hidden)
    def initialize(s = 0)
      super
      self.sha = Digest::SHA1.new
      self.is_signature = false
      self.is_hidden    = false
    end

    def signature?
      is_signature
    end

    def hidden?
      is_hidden
    end

    def update(s)
      self.sha.update(s)
    end

    def finish(ending_line)
      self.end = ending_line
      self.sha = self.sha.to_s
      self
    end
  end
end
