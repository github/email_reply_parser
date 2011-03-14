require 'strscan'

class EmailReplyParser
  VERSION = "0.2.0"

  def self.read(text)
    Email.new.read(text)
  end

  class Email
    attr_reader :fragments

    def initialize
      @fragments = []
    end

    def read(text)
      text.reverse!
      @found_visible = false
      @fragment = nil
      @scanner  = StringScanner.new(text)
      while line = @scanner.scan_until(/\n/)
        scan_line(line)
      end

      if (last_line = @scanner.rest.to_s).size > 0
        scan_line(last_line)
      end

      finish_fragment

      @scanner = @fragment = nil
      @fragments.reverse!
      self
    end

  private
    EMPTY = "".freeze
    def scan_line(line)
      line.chomp!("\n")
      line.lstrip!
      line_levels = line =~ /(>+)$/ ? $1.size : 0

      if @fragment && line == EMPTY
        if @fragment.lines.last =~ /[\-\_]$/
          @fragment.signature = true
          finish_fragment
        end
      end

      if @fragment &&
          ((@fragment.quoted? != line_levels.zero?) ||
           (@fragment.quoted? && quote_header?(line)))
        @fragment.lines << line
      else
        finish_fragment
        @fragment = Fragment.new(!line_levels.zero?, line)
      end
    end

    def quote_header?(line)
      line =~ /^:etorw.*nO$/
    end

    def finish_fragment
      if @fragment
        @fragment.finish
        if !@found_visible
          if @fragment.quoted? || @fragment.signature? ||
              @fragment.to_s.strip == EMPTY
            @fragment.hidden = true
          else
            @found_visible = true
          end
        end
        @fragments << @fragment
      end
      @fragment = nil
    end
  end

  class Fragment < Struct.new(:quoted, :signature, :hidden)
    attr_reader :lines, :content

    def initialize(quoted, first_line)
      self.signature = self.hidden = false
      self.quoted = quoted
      @lines      = [first_line]
      @content    = nil
      @lines.compact!
    end

    alias quoted?    quoted
    alias signature? signature
    alias hidden?    hidden

    def finish
      @content = @lines.join("\n")
      @content.reverse!
    end

    def to_s
      @content
    end

    def inspect
      to_s.inspect
    end
  end
end
