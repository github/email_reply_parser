# Email Reply Parser

EmailReplyParser is a small library to parse plain text email content.
See the rocco-documented source code for specifics on how it works.

This was forked from what GitHub uses to display comments that were created from
email replies.  

The parsing of replies and signatures is much more robust in this version (outlook, hotmail, yahoo, gmail, iPhone, Andriod).

See githubs docs at the [Rocco docs][rocco].

[rocco]: http://help.github.com/code/email_reply_parser/

## Problem?

If you have a specific issue regarding this library, then hit up the [Issues][issues].

[support]: http://support.github.com/
[issues]: https://github.com/drewB/email_reply_parser/issues

## Installation

Get it from [GitHub][github] or in your Rails 3 bundler file:


`gem 'email_reply_parser', :git => 'git://github.com/drewB/email_reply_parser.git'`

[github]: https://github.com/drewB/email_reply_parser.git'

## Known Issues

### Quoted Headers

Quoted headers aren't picked up if there's an extra line break:

    On <date>, <author> wrote:

    > blah

Also, they're not picked up if the email client breaks it up into
multiple lines.  GMail breaks up any lines over 80 characters for you.

    On <date>, <author>
    wrote:
    > blah

Not to mention that we're search for "on" and "wrote".  It won't work
with other languages.

Possible solution: Remove "reply@reply.github.com" lines...

### Weird Signatures

Lines starting with `-` or `_` sometimes mark the beginning of
signatures:

    Hello

    -- 
    Rick

Not everyone follows this convention:

    Hello

    Mr Rick Olson
    Galactic President Superstar Mc Awesomeville
    GitHub

    **********************DISCLAIMER***********************************
    * Note: blah blah blah                                            *
    **********************DISCLAIMER***********************************




