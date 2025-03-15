#!/usr/bin/env perl

use 5.010;
# use 5.36.0;
# use strict (automatic since 5.12.0) 
# use warnings (automatic since 5.16.0) 
# use feature 'say' (automatic since 5.36.0)
use YAML::XS qw(LoadFile); 
use Data::Dumper::Concise;
use lib '/home/russ/lib';
use Mail::Alias::LocalFile;


# select the desired file for demonstration purposes
  my $alias_file_path = '/home/russ/lib/Mail/Alias/samples/aliases.yml';
# my $alias_file_path = '/home/russ/lib/Mail/Alias/samples/aliases.json';
# my $alias_file_path = '/home/russ/lib/Mail/Alias/samples/good_aliases.yml';
my $aliases = load_aliases_file();


# Create a new resolver object - using Moo-style named parameters
my $resolver = LocalFile->new(aliases => $aliases);

# Resolve email addresses
my @recipients = ();
if (@ARGV) {
    @recipients = @ARGV;
}
else {
    say '';
    say "ERROR: No email recipients and/or aliases were provided";
    say '';
}

# Returns a hash_ref holding ivarious useful keys and values
my $result = $resolver->resolve_recipients(\@recipients);

my $recipients           = $result->{recipients};
my $warning              = $result->{warning};
my $alias_file_contents  = $result->{aliases};
my $original_input       = $result->{original_input};
my $processed_aliases    = $result->{processed_aliases};
my $uniq_email_addresses = $result->{uniq_email_addresses};
my $expanded_addresses   = $result->{expanded_addresses};
my $circular_references   = $result->{circular_references};


say '';
say "recipients: $recipients";

if ( @$circular_references ) {
    say 'Warning: the aliases file contains circular references';
    foreach my $item ( @{$circular_references} ) {
        say "    $item";
    }

}

  if ( @$warning ) {
    say '';
    say 'warning';
    foreach my $item ( @{$warning} ) {
        say "    $item";
    }
    say '';
    say "Alias File Contents";
    say Dumper( $alias_file_contents );
    say '';
    say 'Original Input';
    foreach my $item ( @{$original_input} ) {
        say "    $item";
    }
    say '';
}

# uncomment for troubleshooting
  say "=============== START ===============================";
  say "result";
  say Dumper( $result );
  say "================ END  ===============================";



sub load_aliases_file {

    # say "Loading aliases file from $alias_file_path";

    # load the aliases.yml file

    # will become a hashref with an alias as a key
    # and values that can be more aliases or actual
    # email addresses

    eval { $aliases = LoadFile($alias_file_path); };

    if ($@) {
        say '';
        say "The aliases.yml file did not load";
        say "ERROR: $@";
        say "ERROR: $!";
        say '';
        exit;
    }
    return ($aliases);
}
