$LOAD_PATH.unshift '.'
require 'lib/email_reply_parser'

Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.rubygems_version = '1.3.5'
  s.license = 'MIT'

  s.name              = 'email_reply_parser'
  s.version           = EmailReplyParser::VERSION
  s.date              = Time.now.strftime('%Y-%m-%d')

  s.summary     = "EmailReplyParser is a small library to parse plain text " \
                  "email content."
  s.description = "EmailReplyParser is a small library to parse plain text " \
                  "email content. This is what GitHub uses to display comments " \
                  "that were created from email replies."

  s.authors  = ["Rick Olson"]
  s.email    = 'technoweenie@gmail.com'
  s.homepage = 'http://github.com/github/email_reply_parser'

  s.require_paths = %w[lib]

  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = %w[README.md LICENSE]

  #s.add_dependency('DEPNAME', [">= 1.1.0", "< 2.0.0"])

  #s.add_development_dependency('DEVDEPNAME', [">= 1.1.0", "< 2.0.0"])

  ## Leave this section as-is. It will be automatically generated from the
  ## contents of your Git repository via the gemspec task. DO NOT REMOVE
  ## THE MANIFEST COMMENTS, they are used as delimiters by the task.
  # = MANIFEST =
  s.files = %w[
    LICENSE
    README.md
    Rakefile
    email_reply_parser.gemspec
    lib/email_reply_parser.rb
    script/release
    script/test
    test/email_reply_parser_test.rb
    test/emails/correct_sig.txt
    test/emails/email_1_1.txt
    test/emails/email_1_2.txt
    test/emails/email_1_3.txt
    test/emails/email_1_4.txt
    test/emails/email_1_5.txt
    test/emails/email_1_6.txt
    test/emails/email_1_7.txt
    test/emails/email_1_8.txt
    test/emails/email_2_1.txt
    test/emails/email_2_2.txt
    test/emails/email_2_3.txt
    test/emails/email_BlackBerry.txt
    test/emails/email_bullets.txt
    test/emails/email_iPhone.txt
    test/emails/email_long_quote.txt
    test/emails/email_multi_word_sent_from_my_mobile_device.txt
    test/emails/email_one_is_not_on.txt
    test/emails/email_sent_from_my_not_signature.txt
    test/emails/email_sig_delimiter_in_middle_of_line.txt
    test/emails/greedy_on.txt
    test/emails/pathological.txt
  ]
  # = MANIFEST =

  s.test_files = s.files.select { |path| path =~ /^test\/.*_test\.rb/ }
end
