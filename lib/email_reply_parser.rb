require 'strscan'

class EmailReplyParser
  class Block
    attr_reader :levels

    def initialize(levels = 0)
      @levels = levels
      @lines  = []
      @joined = nil
    end

    def <<(line)
      @lines << line
    end

    def reply?
      @levels > 0
    end

    def to_s
      @joined ||= @lines.join("\n")
    end

    def inspect
      to_s.inspect
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
        blocks << (block = Block.new(line_levels))
      end
      block << line
    end
    blocks
  end
end
