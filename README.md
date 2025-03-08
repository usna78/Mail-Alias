# Mail-Aliases
Resolve email aliases from a locally maintained application specific aliases file

# Rational
This module is useful when your script or application is not using the
system email aliases file provided by your server's Mail Transfer Agent (MTA). 
The restriction would generally be encountered when, by policy, the MTA aliases 
file is reserved for use by only a single group, such as just the server's system 
administrators.

The restrictive policy has sometimes been justified by concerns over the fragile
nature of the system wide MTA /etc/mail/aliases file. It breaks easily
when minor configuration errors are made. If uncorrected, the errors, can render
portions of the file inoperable. In a multi-application environment, this
allows mistakes made by one group when editing the aliases file to interfere with 
emails being sent by other groups. In addition, when multiple applications share a 
common aliases filethe email recipients can be inadvertently co-mingled.

This module removes any dependence your script or application has on your system 
wide MTA aliases file. This is not to imply that your MTA aliases file should 
not be used if it is available to you. The module provides an option for using 
aliases when it is not.

The type of local file holding the alias definitions is up to the application. File
types such as INI, JSON, YAML, XML and many others could be used.

# Assumptions:
- The application can load a locally maintained aliases configuration file
- The aliases file can use any practical format such as YAML, Json, XML, INI or similar
- When the entire aliases file is loaded, the data is held in a Perl hash reference 
- Each hash key is the name of an alias
- The value is a string or an array. (Hashes are not supported as values)
- Values are combinations of email addresses and alias names, as is coustomary in the MTA system aliases file
- The script or application, when sending outbound email, expects recipients to be a comma separated list of email addresses
  
# Sample Aliases Files:
Two sample configuration files (YAML and JSON formated) are provided as examples of locally maintained aliases files
that load as a hash_ref containing acceptable keys and values. They intentionally hold various types of comma and space separation to
demonstate the flexibility allowed in value formatting. 

# Limitations
- This module does not currently duplicate the more complex capabilities of a MTA aliases file.  The module is limited to converting aliases
  to email addresses. Each item in a value is assumed to be either an email address or an alias representing email addresses. A value
  entry may not have any other purpose. For example, a value entry cannot represent a pipe to a command or append a message to a file.

# Functionality:
Functionality is explained within the Perl POD.  (perldoc LocalFile.pm)

Basic functionality includes:
- Malformed email addresses are skipped
- References to non-existent aliases are skipped
- Each alias is only expanded once, so circular references are tolerated and suppressed.
- Warnings when encountering any of the above issues are captured 
- Duplicated email recipients are removed
- Basic email address format validity is determined through Email::Valid->address
- Converts all email addresses to lower case lettering


# Input
In your application, create a new resolver object - using Moo style named parameters

- my $resolver = LocalFile->new(aliases => $aliases);
- my $result = $resolver->resolve_recipients($intended_recipients);
  
Where inputs are:
- $aliases is a hash_ref of key/value pairs holding the entire contents of your locally maintained aliases file
- $intended_recipients is an array_ref holding the email addressses and aliases of the intended email recipients

# Output
- my $result = $resolver->resolve_recipients($recipients);
Where $result is a hash_ref as shown below:

my $recipients           = $result->{recipients};
my $warning              = $result->{warning};
my $alias_file_contents  = $result->{aliases};
my $original_input       = $result->{original_input};
my $processed_aliases    = $result->{processed_aliases};
my $uniq_email_addresses = $result->{uniq_email_addresses};
my $expanded_addresses   = $result->{expanded_addresses};

Where output includes all of the following to use as desired:
- $recipients is the desired email aliases expansion like "john@company.com,joe@example.com,mary@example.com"
- $warnings is an array_ref holding issues encountered, like a malformed email address or mispelled alias
- $alias_file_contents is the entire contents of the local alias file, possibly for troubleshooting
- $original_input is an array_ref holding the $intended_recipients, for troubleshooting
- $processed_aliases is a hash_ref identifying each alias that was expanded to email addresses, for troubleshooting
- $expanded_addresses is an array_ref built as each alias is expanded, which can include duplicate email addresses
- $uniq_email_addresses is an array_ref like $expanded_addresses but with the duplicates (if any) removed
  
$recipients is the same content as $uniq_email_addresses, except it is held as the comma separated string most 
likely desired by your email code
