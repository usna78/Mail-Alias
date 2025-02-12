# Mail-Aliases
Resolve email aliases from a local aliases file

This module is useful when your script or application is unable to use the
system email aliases file provided by your email server. The restriction would
generally be encountered when, by policy, a the aliases file is reserved
for use by only a single group, such as just the system administrators.

The restrictive policy has sometimes been justified by concerns over the fragile
nature of the /etc/mail/aliases file (on a sendmail system). It breaks easily
when minor configuration errors are made. If undetected the errors, can render
portions of the file inoperable. In a multi-application environment, this
allows mistakes made by one group to interfere with emails being sent by 
other groups. In addition, when multiple applications share a common aliases file
the email recipients can be inadvertently co-mingled.

This module copes with this restriction by taking the input from an 
application maintained local aliases file and recursively converting aliases
individual email addresses.

The type of local file holding the alias definitions is up to the application. File
ypes such as INI, JSON, YAML, XML and many others could be used.

This module expects to be presented with a string of values consisting of a combination
of email addresses and aliases
