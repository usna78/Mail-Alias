# Mail-Aliases
Resolve email aliases from a locally maintained application specific aliases file
in addition to the system-wide aliases file used by the Mail Transfer Agent (MTA).

# Rational
This module allows the use of a locally maintained aliases file in addition to using the 
aliases file used by the MTA. This is beneficial for several reasons:
- The MTA aliases file may not be available to you because editing it is restricted by corporate policy
- The MTA aliases file is shared  and you want to avoid conflicting alias names already in use others
- The MTA is being edited by persons not affliated with you application and their errors affect your emails
- You want control of your own aliases in a file not availble to others  still use entries in the system aliases file needed

This module is useful when your script or application is not using the
system email aliases file provided by your server's Mail Transfer Agent (MTA). 
The restriction would generally be encountered when, by policy, the MTA aliases 
file is reserved for use by only a single group, such as just the server's system 
administrators.

This module reduces the dependence your script or application has on your system 
wide MTA aliases file. You can avoid the use of the system aliases entirely or you 
can use some system aliases to supplement your local aliases. This is not to imply 
that your MTA aliases file should not be used if it is available to you. This module 
provides an option for using locally defined aliases when when desired and using 
system wide aliases only when desired.

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
- This module focuses to converting aliasesto email addresses and does not attempt to duplicate
  the more complex capabilities of a MTA aliases file.

# Regular aliases and aliases with the mta_ prefix
  - Regular aliases:
    
    Each value in the local alias file is assumed to consist of one or more email addresses and may also include locally
    defined aliases representing email addresses. Locally defined aliases listed as values are expanded
    without the use of the system aliases file. For example, an alias named 'sales' is expanded to the email addresses
    assigned to the 'sales' alias defined in the local aliases file. If there is also a sales alias defined on the system
    aliases file, it is not used.  The local alias definition supercedes the system file definition.

  - mta_ prefixes

    The 'mta_' prefix is used to allow aliases to be expanded by the MTA instead of being expanded locally. 
    For example, assume a value in the local aliases file hold alias 'mta_sales'. This module recognizes the 'mta_' prefix,
    removes the prefix, and allows the remainder (in this case sales) to pass through for eventual expansion by the MTA using
    the system aliases file.

    'mta_' prefixed aliases can be used to supplement system file aliases. Assume the sales alias in the system file includes two
    email addresses for senior managers joe and mary:

    sales: joe@hq.company.com, mary@hq.company.com  (In the system aliases file)

    The local alias file could hold this entry:

    sales: billy@local.company.com, mta_sales  (In the local aliases file)

    This module would expand the local alias (picking up billy@local.company.com as a recipient) and strip the prefix from mta_sales.
    The To: section of your email header would receive billy@local.company.com,sales.  When the email is
    processed by the MTA, sales is expanded using the system aliases file to include joe and mary's email addresses.
    The three recipients become billy@local.company.com,joe@hq.company.com,mary@hq.company.com

    The 'mta_' prefix can also be used to take advantage of advanced aliasing features not supported by the local aliases file, such as
    appending email to files, or using pipes to execute commands. As long as the alias is defined in the system aliases file, the local
    alias file can use a corresponding mta_ prefix to incorporate it.

    The 'mta_' prefix cannot be used as prefix to a local aliases file key.  Its use is restricted to inclusion as a value.

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
