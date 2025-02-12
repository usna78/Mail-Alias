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
to individual email addresses.

The type of local file holding the alias definitions is up to the application. File
types such as INI, JSON, YAML, XML and many others could be used.

This module expects to be presented with a string of values consisting of a combination
of email addresses and aliases

I'll explain how this Perl code works. It's a module designed to handle email alias expansion - essentially converting shorthand names (aliases) into full email addresses.

# Assumptions:
- The application can load a locally maintained aliases configuration file consisting of key/value pairs
- The aliases file can be maintained in any practical format such as YAML, Json, XML, INI or similar
- When the entire file is loaded, the data is held in a hash reference 
- The hash keys are the names of aliases and the values are combinations of email addresses (and quite possibly other aliases) belonging to the alias
- When preparing outbound email, the application provides a space or comma separated list of recipients as a combination of email addresses and/or aliases

# Sample Configuration File:
Note: This example assumes the configuration file is in YAML format. However, your application may be using any format
that can be loaded as a hash reference. The format your script or application
uses is up to you. YAML is one excellent choice because it is easy to read and edit.

# Sample YAML aliases file
...

bill: Bill.Williams@somecompany.com

mary: Mary@example.com

tech_team:
  - john@company.com, Joe@example.com, mary
  - dev_leads

dev_leads:
  - sarah@company.com
  - mike@company.com, Mary@example.com

# Functionality:

2. Module Tasks
- The code is a Perl module named `Mail::Aliases`
- It requires two inputs: 1) the list of addressess and 2) the hash reference of the entire aliases file
- It relies on the Email::Valid module to validate whether an addreess is a correctly formated email address
- It relies on the Scalar::Utils module to differentiate between aliaes defined as a single line  value and aliases with multiple lines of values
- It interprets non-email addresses as aliases and recursively converts them to individual email addresses
- It produces a lower case, comma separated list of individual email addresses as its output
- It is the applications responsibilty to process the list of email receipients through its mail sending client code

2. Main Function: resolve_email_aliases
- Loads email aliases from a YAML file specified in the configuration
- Processes four types of email lists:
  - admin_notification_list
  - customer_notification_list
  - copy_distribution_list
  - sms_notification_list
- If the YAML file fails to load, it falls back to a failsafe notification list

3. Email List Processing
- Handles multiple formats of email lists:
  - Comma-separated values
  - Space-separated values
  - Single entries
- For each entry, it determines if it's:
  - A direct email address (contains @)
  - An alias that needs expansion

4. Alias Expansion (expand_alias subroutine)
- Takes an entry from the aliases file
- Handles two types of alias definitions:
  - Array-based (multiple lines in YAML)
  - Scalar (single line)
- Recursively expands nested aliases
- Converts all email addresses to lowercase
- Handles both single values and comma-separated lists within aliases

5. Duplicate Removal
- The `remove_duplicate_email_addresses` subroutine ensures each email address appears only once in the final list
- Uses a hash to track seen addresses

# Here's a practical example of how it works:

If the configuration specifies `admin_notification_list: tech_team`, the code would:
1. Mail::Aliases::expand_alias($aliases, $addressees);
2. Where $aliases is a hash reference holding the contents of the locally maintained aliases file
3. Where $addressees holds the alias 'tech_team' as the intended recipient
4. The tech_team alias is expanded to include:
    - the email addresses john@company.com and Joe@example.com
    - the mary alias is expanded to Mary@example.com
    - the dev_leads alias is expanded to sarah@company.com and mike@company.com and Mary@example.com
5. The initial expansion becomes: john@company.com,Joe@example.com,Mary@example.com,sarah@company.com,mike@company.com,Mary@example.com
6. Remove any duplicates (in this case Mary's email is included only once)
7. Convert all email addresses to lower case lettering
8. Return: "john@company.com,joe@example.com,mary@example.com,sarah@company.com,mike@company.com"

