$LOAD_PATH.unshift '.'
require 'lib/email_reply_parser'

## This is the rakegem gemspec template. Make sure you read and understand
## all of the comments. Some sections require modification, and others can
## be deleted if you don't need them. Once you understand the contents of
## this file, feel free to delete any comments that begin with two hash marks.
## You can find comprehensive Gem::Specification documentation, at
## http://docs.rubygems.org/read/chapter/20
Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.rubygems_version = '1.3.5'
  s.license = 'MIT'

  ## Leave these as is they will be modified for you by the rake gemspec task.
  ## If your rubyforge_project name is different, then edit it and comment out
  ## the sub! line in the Rakefile
  s.name              = 'email_reply_parser'
  s.version           = EmailReplyParser::VERSION
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.rubyforge_project = 'email_reply_parser'

  ## Make sure your summary is short. The description may be as long
  ## as you like.
  s.summary     = "Short description used in Gem listings."
  s.description = "Long description. Maybe copied from the README."

  ## List the primary authors. If there are a bunch of authors, it's probably
  ## better to set the email to an email list or something. If you don't have
  ## a custom homepage, consider using your GitHub URL or the like.
  s.authors  = ["Rick Olson"]
  s.email    = 'technoweenie@gmail.com'
  s.homepage = 'http://github.com/github/email_reply_parser'

  ## This gets added to the $LOAD_PATH so that 'lib/NAME.rb' can be required as
  ## require 'NAME.rb' or'/lib/NAME/file.rb' can be as require 'NAME/file.rb'
  s.require_paths = %w[lib]

  ## This sections is only necessary if you have C extensions.
  #s.require_paths << 'ext'
  #s.extensions = %w[ext/extconf.rb]

  ## If your gem includes any executables, list them here.
  #s.executables = ["name"]
  #s.default_executable = 'name'

  ## Specify any RDoc options here. You'll want to add your README and
  ## LICENSE files to the extra_rdoc_files list.
  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = %w[README.md LICENSE]

  ## List your runtime dependencies here. Runtime dependencies are those
  ## that are needed for an end user to actually USE your code.
  #s.add_dependency('DEPNAME', [">= 1.1.0", "< 2.0.0"])

  ## List your development dependencies here. Development dependencies are
  ## those that are only needed during development
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
    test/emails/email_1_9.txt
    test/emails/email_2_1.txt
    test/emails/email_2_2.txt
    test/emails/email_BlackBerry.txt
    test/emails/email_bullets.txt
    test/emails/email_iPhone.txt
    test/emails/email_multi_word_sent_from_my_mobile_device.txt
    test/emails/email_one_is_not_on.txt
    test/emails/email_sent_from_my_not_signature.txt
    test/emails/email_sig_delimiter_in_middle_of_line.txt
    test/emails/greedy_on.txt
    test/emails/pathological.txt
  ]
  # = MANIFEST =

  ## Test files will be grabbed from the file list. Make sure the path glob
  ## matches what you actually use.
  s.test_files = s.files.select { |path| path =~ /^test\/.*_test\.rb/ }
end
