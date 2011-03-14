require 'strscan'

class EmailReplyParser
  VERSION = "0.2.0"

  # Splits an email body into a list of Fragments.
  #
  # text - A String email body.
  #
  # Returns an Email instance.
  def self.read(text)
    Email.new.read(text)
  end

  class Email
    attr_reader :fragments

    def initialize
      @fragments = []
    end

    # Splits the given text into a list of Fragments.  This is roughly done by
    # reversing the text and parsing from the bottom to the top.  This way we
    # can check for 'On <date>, <author> wrote:' lines above quoted blocks.
    #
    # text - A String email body.
    #
    # Returns this same Email instance.
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

    # Scans the given line of text and figures out which fragment it belongs
    # to.
    #
    # line - A String line of text from the email.
    #
    # Returns nothing.
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

    # Detects if a given line is a header above a quoted area.  It is only
    # checked for lines preceding quoted regions.
    #
    # line - A String line of text from the email.
    #
    # Returns true if the line is a valid header, or false.
    def quote_header?(line)
      line =~ /^:etorw.*nO$/
    end

    # Builds the fragment string and reverses it, after all lines have been
    # added.  It also checks to see if this fragment is hidden.
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

  # Represents a group of paragraphs in the email sharing common attributes.
  # Paragraphs should get their own fragment if they are a quoted area or a
  # signature.
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

    # Builds the string content by joining the lines and reversing them.
    #
    # Returns nothing.
    def finish
      @content = @lines.join("\n")
      @lines = nil
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
