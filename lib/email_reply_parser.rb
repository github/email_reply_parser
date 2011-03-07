require 'strscan'
require 'digest/sha1'

class EmailReplyParser
  class Block
    attr_reader :levels, :shas

    def initialize(levels = 0)
      @levels = levels
      @lines  = []
      @joined = nil
      @shas   = {}  # sha => {:start => 0, :end => 1}
      @sha    = nil # current sha
      @line   = -1  # current line number
    end

    def <<(line)
      update_paragraph_sha(line)
      @lines << line
    end

    def reply?
      @levels > 0
    end

    def to_s
      @joined ||= @lines.join("\n")
    end

    def finish
      end_sha
    end

    def inspect
      to_s.inspect
    end

  private
    def update_paragraph_sha(line)
      @line   += 1
      stripped = line.sub(/^(\s|>)+/, '')
      if stripped.size.zero?
        end_sha(@line-1)
      else
        start_sha
        if stripped =~ /^[\-|_]/
          @shas[:current][:signature] = true
        end
        @sha.update(stripped)
      end
    end

    def start_sha
      if @sha.nil?
        @shas[:current] = {:start => @line}
      end
      @sha ||= Digest::SHA1.new
    end

    def end_sha(ending_line = @line)
      if @sha
        @shas[@sha.hexdigest] = @shas.delete(:current).
          update(:end => ending_line)
      end
      @sha = nil
    end
  end

public
  def self.scan(text)
    blocks = []
    block  = nil
    scanner = StringScanner.new(text)
    while line = scanner.scan_until(/\n/)
      line.rstrip!
      line_levels = 0
      if line =~ /^(>+)/
        line_levels = $1.size
      end
      if !block || block.levels != line_levels
        block.finish if block
        blocks << (block = Block.new(line_levels))
      end
      block << line
    end
    blocks.last.finish if blocks.size > 0
    blocks
  end
end
