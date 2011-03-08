require 'strscan'
require 'digest/sha1'
require 'set'

class EmailReplyParser
  VERSION = "0.1.0"

  # Parses an email body, pulling out quoted regions and finding paragraphs
  # that should be hidden.  This is designed to be called on a sequence of
  # emails.
  #
  # body - String body of the email.
  # shas - Optional Set of SHA1 hex values that match the content of
  #        paragraphs.  This is used to check if any paragraphs in this
  #        reply are repeated from earlier emails in this thread.
  #
  # Returns a Reply instance.
  def self.read(body, shas = nil)
    Reply.new(body, shas)
  end

  # Represents a parsed email body.  Each email is broken up into Block
  # instances, according to the quote level.
  class Reply
    attr_reader :blocks, :shas

    def initialize(text, shas = nil)
      @blocks = []
      @block  = nil

      # add this reply's shas to the given shas Set
      @shas = shas || Set.new

      # check if this reply's blocks are hidden with with the unmodified
      # sha Set.  This reply's own repeat blocks can't mark itself as hidden.
      @current_shas = @shas.dup

      @scanner = StringScanner.new(text)
      while line = @scanner.scan_until(/\n/)
        scan_line(line)
      end

      if (last_line = @scanner.rest.to_s).size > 0
        scan_line(last_line)
      end

      @blocks.last.finish if @blocks.size > 0

      scan_for_hidden
      @block = @scanner = @current_shas = nil
    end

  private
    # Scans each incoming line.  If the quote level changes, create a new
    # instance.  The quote level is determined by counting the number of '>'
    # characters at the beginning of a string.
    #
    # line - String line of text from the email.
    #
    # Returns nothing.
    def scan_line(line)
      line.rstrip!
      line_levels = 0
      if line =~ /^(>+)/
        line_levels = $1.size
      end
      if !@block || @block.levels != line_levels
        @block.finish if @block
        @blocks << (@block = Block.new(
          :levels => line_levels,
          :shas   => @shas))
      end
      @block << line
    end

    # Determines which blocks should be hidden.  We want to hide any quoted
    # regions or signatures at the bottom.  Quick checking as soon as visible
    # text is found.
    def scan_for_hidden
      @blocks.reverse.each do |block|
        if block.paragraphs.empty?
          block.is_hidden = true
        else
          block.paragraphs.reverse.each do |para|
            if !(para.is_hidden = (
                  block.quoted? ||
                  (para.signature? && @current_shas.include?(para.sha))
                ))
              return
            end
          end
        end
      end
    end
  end

  # Represents a quoted portion of the email.  A Block has 0 or more Paragraph
  # instances.
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

    # Sets this Block to be hidden.  Any blocks with no actual content are 
    # marked as hidden.
    #
    # bool - Either a true or false.
    #
    # Returns nothing.
    def is_hidden=(bool)
      @hidden = !!bool
    end

    # Public: Gets whether this Block should be hidden or not.
    #
    # Returns true if this Block should be hidden, or false.
    def hidden?
      if @hidden.nil?
        @hidden = (p = @paras.first and p.hidden?) || false
      end
      @hidden
    end

    # Public: Gets whether this Block has been quoted at least once.
    #
    # Returns true if the Block has been quoted, or false.
    def quoted?
      @levels > 0
    end

    # Public: Gets paragraphs for this Block.
    #
    # Returns an Array of Paragraph instances.
    def paragraphs
      @paras
    end

    # Public: Adds the given line to this block.
    #
    # line - String line of text from the email.
    #
    # Returns nothing.
    def <<(line)
      update_paragraph(line)
      @lines << line
    end

    # Public: Checks whether the SHA1 hex occurs in this Block.
    #
    # sha - String SHA1 hex value.
    #
    # Returns true if the SHA1 occurs, or false.
    def include?(sha)
      @shas.include?(sha)
    end

    # Public: Gets the full content for this Block.
    #
    # Returns a String.
    def to_s
      @joined ||= @lines.join("\n")
    end

    # Public: Gets the content of this Block for inspection.
    #
    # Returns a String.
    def inspect
      to_s.inspect
    end

    # Finishes up any loose ends after adding the last line of text to this
    # Block.
    #
    # Returns nothing.
    def finish
      end_para
    end

  private
    # Updates the current Paragraph for this Block during the parsing.
    #
    # line - String line of text from the email.
    #
    # Returns nothing
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

    # Starts a new Paragraph during the parsing.
    #
    # Returns nothing.
    def start_para
      @paras << (@para = Paragraph.new(@line))
    end

    # Finishes the current Paragraph and adds its SHA1 hash to this Block's
    # Set of SHAs.
    #
    # ending_line - String line of text from the email.
    #
    # Returns nothing.
    def end_para(ending_line = @line)
      return if !@para
      @shas << @para.finish(ending_line).sha
      @para = nil
    end
  end

  # Tracks each paragraph of content in the email and builds up a SHA1 hash of
  # the contents.  This SHA1 hash is used to determine if this paragraph is
  # repeated in further emails in the current thread.  Paragraphs don't store
  # the actual content, but contain start/end line numbers that match lines in
  # the Paragraph's Block instance.
  class Paragraph < Struct.new(:start, :end, :sha, :is_signature, :is_hidden)
    def initialize(s = 0)
      super
      self.sha = Digest::SHA1.new
      self.is_signature = false
      self.is_hidden    = false
    end

    # Public: Gets whether this Paragraph is considered an email signature.
    # Email signatures are just paragraphs that start with a leading dash or
    # underscore.
    #
    # Returns true if this Paragraph is a signature, or false.
    def signature?
      is_signature
    end

    # Public: Gets whether this Paragraph is thought to be hidden.  This is
    # determined after each line of text in the email has been processed.
    #
    # Returns true if this Paragraph is hidden, or false.
    def hidden?
      is_hidden
    end

    # Updates the SHA1 hash of this paragraph.
    #
    # s - String line of text from the email.
    #
    # Returns nothing.
    def update(s)
      self.sha.update(s)
    end

    # Sets the ending line of this Paragraph, and finalizes the SHA1 hash.
    #
    # ending_line - Fixnum representing which line in the Block this paragraph
    #               ended on.
    #
    # Returns nothing.
    def finish(ending_line)
      self.end = ending_line
      self.sha = self.sha.to_s
      self
    end
  end
end
