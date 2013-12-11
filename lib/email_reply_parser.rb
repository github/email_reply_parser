require 'strscan'

# EmailReplyParser is a small library to parse plain text email content.  The
# goal is to identify which fragments are quoted, part of a signature, or
# original body content.  We want to support both top and bottom posters, so
# no simple "REPLY ABOVE HERE" content is used.
#
# Beyond RFC 5322 (which is handled by the [Ruby mail gem][mail]), there aren't
# any real standards for how emails are created.  This attempts to parse out
# common conventions for things like replies:
#
#     this is some text
#
#     On <date>, <author> wrote:
#     > blah blah
#     > blah blah
#
# ... and signatures:
#
#     this is some text
#
#     --
#     Bob
#     http://homepage.com/~bob
#
# Each of these are parsed into Fragment objects.
#
# EmailReplyParser also attempts to figure out which of these blocks should
# be hidden from users.
#
# [mail]: https://github.com/mikel/mail
class EmailReplyParser
  VERSION = "0.5.5"

  # Public: Splits an email body into a list of Fragments.
  #
  # text         - A String email body.
  # from_address - A String From address of the email (optional)
  #
  # Returns an Email instance.
  def self.read(text, from_address = nil)
    Email.new.read(text, from_address)
  end

  # Public: Get the text of the visible portions of the given email body.
  #
  # text         - A String email body.
  # from_address - A String From address of the email (optional)
  #
  # Returns a String.
  def self.parse_reply(text, from_address = nil)
    self.read(text, from_address).visible_text
  end

  ### Emails

  # An Email instance represents a parsed body String.
  class Email
    # Emails have an Array of Fragments.
    attr_reader :fragments

    def initialize
      @fragments = []
    end

    # Public: Gets the combined text of the visible fragments of the email body.
    #
    # Returns a String.
    def visible_text
      fragments.select{|f| !f.hidden?}.map{|f| f.to_s}.join("\n").rstrip
    end

    # Splits the given text into a list of Fragments.  This is roughly done by
    # reversing the text and parsing from the bottom to the top.  This way we
    # can check for 'On <date>, <author> wrote:' lines above quoted blocks.
    #
    # text         - A String email body.
    # from_address - A String From address of the email (optional)
    #
    # Returns this same Email instance.
    def read(text, from_address = nil)
      from_address ||= ""

      # parse out the from name if one exists and save for use later
      @from_name_raw = parse_raw_name_from_address(from_address)
      @from_name_normalized = normalize_name(@from_name_raw)
      @from_email = parse_email_from_address(from_address)

      text = normalize_text(text)

      # The text is reversed initially due to the way we check for hidden
      # fragments.
      text = text.reverse

      # This determines if any 'visible' Fragment has been found.  Once any
      # visible Fragment is found, stop looking for hidden ones.
      @found_visible = false

      # This instance variable points to the current Fragment.  If the matched
      # line fits, it should be added to this Fragment.  Otherwise, finish it
      # and start a new Fragment.
      @fragment = nil

      # Use the StringScanner to pull out each line of the email content.
      @scanner = StringScanner.new(text)
      while line = @scanner.scan_until(/\n/n)
        scan_line(line)
      end

      # Be sure to parse the last line of the email.
      if (last_line = @scanner.rest.to_s).size > 0
        scan_line(last_line)
      end

      # Finish up the final fragment.  Finishing a fragment will detect any
      # attributes (hidden, signature, reply), and join each line into a
      # string.
      finish_fragment

      @scanner = @fragment = nil

      # Now that parsing is done, reverse the order.
      @fragments.reverse!
      self
    end

  private
    EMPTY = "".freeze
    SIGNATURE = '(?m)(--|__|\w-$)|(^(\w+\s*){1,3} ym morf tneS$)'

    begin
      require 're2'
      SIG_REGEX = RE2::Regexp.new(SIGNATURE)
    rescue LoadError
      SIG_REGEX = Regexp.new(SIGNATURE)
    end

    # normalize text so it is easier to parse
    #
    # text - String text to normalize
    #
    # Returns a String
    #
    def normalize_text(text)
      # in 1.9 we want to operate on the raw bytes
      text = text.dup.force_encoding("binary") if text.respond_to?(:force_encoding)

      # Normalize line endings.
      text.gsub!("\r\n", "\n")

      # Check for multi-line reply headers. Some clients break up
      # the "On DATE, NAME <EMAIL> wrote:" line into multiple lines.
      if match = text.match(/^(On\s(.+)wrote:)$/m)
        # Remove all new lines from the reply header. as long as we don't have any double newline
        # if we do they we have grabbed something that is not actually a reply header
        text.gsub! match[1], match[1].gsub("\n", " ") unless match[1] =~ /\n\n/
      end

      # Some users may reply directly above a line of underscores.
      # In order to ensure that these fragments are split correctly,
      # make sure that all lines of underscores are preceded by
      # at least two newline characters.
      text.gsub!(/([^\n])(?=\n_{7}_+)$/m, "\\1\n")
      text
    end

    # Parse a person's name from an e-mail address
    #
    # email - String email address.
    #
    # Returns a String.
    def parse_name_from_address(address)
      raw_name = parse_raw_name_from_address(address)
      normalize_name(raw_name)
    end

    def parse_raw_name_from_address(address)
      match = address.match(/^["']*([\w\s,]+)["']*\s*</)
      unless match.nil?
        match[1].strip.to_s
      else
        ""
      end
    end

    def parse_email_from_address(address)
      match = address.match /<(.*)>/
      if match.nil?
        address
      else
        match[1]
      end
    end

    # Normalize a name to First Last
    #
    # name - name to normailze.
    #
    # Returns a String.

    def normalize_name(name)
      if name.include?(',')
        make_name_first_then_last(name)
       else
        name
      end
    end

    def make_name_first_then_last(name)
      split_name = name.split(',')
      if split_name[0].include?(" ")
        split_name[0].to_s
      else
        split_name[1].strip + " " + split_name[0].strip
      end
    end

    ### Line-by-Line Parsing

    # Scans the given line of text and figures out which fragment it belongs
    # to.
    #
    # line - A String line of text from the email.
    #
    # Returns nothing.
    def scan_line(line)
      line.chomp!("\n")
      line.lstrip! unless signature_line?(line)

      # We're looking for leading `>`'s to see if this line is part of a
      # quoted Fragment.
      is_quoted = !!(line =~ /(>+)$/n)

      # Mark the current Fragment as a signature if the current line is empty
      # and the Fragment starts with a common signature indicator.
      if @fragment && line == EMPTY
        last_line = @fragment.lines.last
        is_signature = signature_line?(last_line)
        is_multiline_quote_header = multiline_quote_header_in_fragment?(@fragment)
        if is_signature || is_multiline_quote_header
          if is_signature
            @fragment.signature = true
          else
            @fragment.quoted = true
          end
          finish_fragment
        end
      end

      # If the line matches the current fragment, add it.  Note that a common
      # reply header also counts as part of the quoted Fragment, even though
      # it doesn't start with `>`.
      if @fragment &&
          ((@fragment.quoted? == is_quoted) ||
           (@fragment.quoted? && (quote_header?(line) || line == EMPTY)))
        @fragment.lines << line

      # Otherwise, finish the fragment and start a new one.
      else
        finish_fragment
        @fragment = Fragment.new(is_quoted, line)
      end
    end

    # Detects if a given line is a header above a quoted area.
    #
    # line - A String line of text from the email.
    #
    # Returns true if the line is a valid header, or false.
    def quote_header?(line)
      standard_header_regexp = reverse_regexp("On\s.+wrote:$")
      line =~ standard_header_regexp
    end

    # Detects if a fragment has a multiline quote header
    #
    # fragment - fragment to look in
    #
    # Returns true if the fragment has header, or false.

    def multiline_quote_header_in_fragment?(fragment)
      fragment_text = @fragment.lines.join("\n")

      from_labels = ["From", "De"]
      to_labels = ["To", "Para"]
      date_labels = ["Date", "Sent", "Enviada em"]
      subject_labels = ["Subject", "Assunto"]
      reply_to_labels = ["Reply-To"]

      quoted_header_regexp =
        multiline_quoted_header_regexps(
          :from => create_regexp_for_labels(from_labels),
          :to => create_regexp_for_labels(to_labels),
          :date => create_regexp_for_labels(date_labels),
          :subject => create_regexp_for_labels(subject_labels),
          :reply_to => create_regexp_for_labels(reply_to_labels)
        )

      fragment_text =~ quoted_header_regexp
    end

    # create regexp for multiline quote headers
    #
    # labels - hash of labels
    #
    # Returns Regexp
    def multiline_quoted_header_regexps(labels)
      quoted_header_regexps = []

      quoted_header_regexps <<  "#{labels[:date]}:.*\n#{labels[:from]}:.*\n#{labels[:to]}:.*\n#{labels[:subject]}:.*"
      quoted_header_regexps << "#{labels[:from]}:.*\n#{labels[:date]}:.*\n#{labels[:to]}:.*\n#{labels[:subject]}:.*"
      quoted_header_regexps << "#{labels[:from]}:.*\n#{labels[:to]}:.*\n#{labels[:date]}:.*\n#{labels[:subject]}:.*"
      quoted_header_regexps << "#{labels[:from]}:.*\n#{labels[:reply_to]}:.*\n#{labels[:date]}:.*\n#{labels[:to]}:.*\n#{labels[:subject]}:.*"

      reverse_regexp("(#{quoted_header_regexps.join("|")})")
    end

    # create regexp that will search for any from a list of labels
    #
    # labels - Array of text strings
    #
    # Returns regexp string
    def create_regexp_for_labels(labels)
      "(#{labels.join("|")})"
    end

    # reverses a regular expression
    #
    # regexp      - String or Regexp that you want to reverse
    # ignore_case - where to the returned Regexp should be case insensitive
    #
    # Returns Regexp
    def reverse_regexp(regexp, ignore_case = true)
      regexp_text = regexp.to_s.reverse
      regexp_text.gsub!("*.", ".*")
      regexp_text.gsub!("+.", ".+")
      regexp_text.gsub!("$", "^")
      regexp_text = reverse_parentheses(regexp_text)

      regexp_options = []
      regexp_options << Regexp::IGNORECASE if ignore_case
      Regexp.new(regexp_text, *regexp_options)
    end

    # reverses parentheses in a string
    #
    # text - String or Regexp that you want to reverse
    #
    # Returns String
    def reverse_parentheses(text)
      text.gsub!(/\)(.*)\(/m, '(\1)')  # reverses outter parentheses
      text.gsub!(/\)(.*?)\(/m, '(\1)') # reverses nested parentheses
      text
    end

    # Detects if a given line is the beginning of a signature
    #
    # line - A String line of text from the email.
    #
    # Returns true if the line is the beginning of a signature, or false.
    def signature_line?(line)
      return true if SIG_REGEX.match(line)
      line_is_signature_name?(line)
    end

    # Detects if the @from name is a big part of a given line and therefore the beginning of a signature
    #
    # line - A String line of text from the email.
    #
    # Returns true if @from_name is a big part of the line, or false.
    def line_is_signature_name?(line)
      regexp = generate_regexp_for_name
      @from_name_normalized != "" && (line =~ regexp) && ((@from_name_normalized.size.to_f / line.size) > 0.25)
    end

    # generates regexp which always for additional words or initials between
    # first and last names
    def generate_regexp_for_name
      name_parts = @from_name_normalized.reverse.split(" ")
      seperator = '[\w.\s]*'
      regexp = Regexp.new(name_parts.join(seperator), Regexp::IGNORECASE)
    end

    # Builds the fragment string and reverses it, after all lines have been
    # added.  It also checks to see if this Fragment is hidden.  The hidden
    # Fragment check reads from the bottom to the top.
    #
    # Any quoted Fragments or signature Fragments are marked hidden if they
    # are below any visible Fragments.  Visible Fragments are expected to
    # contain original content by the author.  If they are below a quoted
    # Fragment, then the Fragment should be visible to give context to the
    # reply.
    #
    #     some original text (visible)
    #
    #     > do you have any two's? (quoted, visible)
    #
    #     Go fish! (visible)
    #
    #     > --
    #     > Player 1 (quoted, hidden)
    #
    #     --
    #     Player 2 (signature, hidden)
    #
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

  ### Fragments

  # Represents a group of paragraphs in the email sharing common attributes.
  # Paragraphs should get their own fragment if they are a quoted area or a
  # signature.
  class Fragment < Struct.new(:quoted, :signature, :hidden)
    # This is an Array of String lines of content.  Since the content is
    # reversed, this array is backwards, and contains reversed strings.
    attr_reader :lines,

    # This is reserved for the joined String that is build when this Fragment
    # is finished.
      :content

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
