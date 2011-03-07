require 'strscan'
require 'digest/sha1'
require 'set'

class EmailReplyParser
  class Reply
    attr_reader :blocks, :shas

    def initialize(text)
      @blocks = []
      block   = nil
      @shas   = Set.new
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
    end
  end

  class Block
    attr_reader :levels

    def initialize(options = {})
      @levels = options[:levels].to_i
      @lines  = []
      @shas   = options[:shas] ||Set.new
      @paras  = []
      @line   = -1  # current line number
      @para   = nil # current paragraph
      @joined = nil
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
        @para.update(stripped)
      end
    end

    def start_para
      @paras << (@para = Paragraph.new(@line))
    end

    def end_para(ending_line = @line)
      return if !@para
      @shas << @para.finish(ending_line)
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
      self.is_signature
    end

    def update(s)
      self.sha.update(s)
    end

    def finish(ending_line)
      self.end = ending_line
      self.sha = @sha.to_s
      self
    end
  end
end
