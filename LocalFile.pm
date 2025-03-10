package LocalFile;

our $VERSION = '0.01';

use Moo;
use namespace::autoclean;
use 5.012;
use Email::Valid;
use Scalar::Util qw(reftype);
use Data::Dumper::Concise;
use Types::Standard qw(ArrayRef HashRef Str);

# Class attributes with type constraints

has 'warning' => (
    is      => 'rw',
    isa     => ArrayRef,
    default => sub { [] },
);

has 'aliases' => (
    is       => 'ro',
    isa      => HashRef,
    required => 1,
);

has 'expanded_addresses' => (
    is      => 'rw',
    isa     => ArrayRef,
    default => sub { [] },
);

has 'addresses_and_aliases' => (
    is      => 'rw',
    isa     => ArrayRef,
    default => sub { [] },
);

has 'original_input' => (
    is      => 'rw',
    isa     => ArrayRef,
    default => sub { [] },
);

has 'processed_aliases' => (
    is      => 'rw',
    isa     => HashRef,
    default => sub { {} },
);

has 'uniq_email_addresses' => (
    is      => 'rw',
    isa     => ArrayRef,
    default => sub { [] },
);

has 'mta_aliases' => (
    is      => 'rw',
    isa     => ArrayRef,
    default => sub { [] },
);

# Methods
sub resolve_recipients {
    my ( $self, $addresses_and_aliases_ref ) = @_;

    # Initialize all data structures
    $self->addresses_and_aliases($addresses_and_aliases_ref);
    my @values = @{$addresses_and_aliases_ref};
    $self->original_input( \@values );
    $self->expanded_addresses( [] );
    $self->processed_aliases( {} );
    $self->mta_aliases( [] );

    # Process all addresses and aliases
    while ( @{ $self->addresses_and_aliases } ) {
        my $item = shift @{ $self->addresses_and_aliases };
        $self->extract_addresses_from_list($item);
    }

    # Remove duplicates and build the final comma-separated list
    my $uniq_email_recipients = $self->remove_duplicate_email_addresses();

    # Combine email recipients with MTA aliases
    my @all_recipients = ( @{$uniq_email_recipients}, @{$self->mta_aliases} );
    my $recipients = join( ',', @all_recipients );

    my %result;
    $result{expanded_addresses}   = $self->expanded_addresses;
    $result{uniq_email_addresses} = $self->uniq_email_addresses;
    $result{recipients}           = $recipients;
    $result{original_input}       = $self->original_input;
    $result{warning}              = $self->warning;
    $result{aliases}              = $self->aliases;
    $result{processed_aliases}    = $self->processed_aliases;
    $result{mta_aliases}          = $self->mta_aliases;

    return \%result;
}

sub extract_addresses_from_list {
    my ( $self, $element ) = @_;

    # Skip empty elements
    return unless defined $element && length $element;

    # Handle elements that contain multiple items (comma or space separated)
    if ( ( $element =~ /,/ ) || ( $element =~ / / ) ) {

        # Normalize spaces and commas
        my $multi_spaces = qr/\s+/x;    # one or more consecutive spaces
        my $multi_commas = qr/,+/x;     # one or more consecutive commas
        my $single_comma = ',';         # a single comma

        $element =~ s{$multi_spaces}{$single_comma}g;
        $element =~ s{$multi_commas}{$single_comma}g;

        # Split the element into individual items
        my @items = split( /,/x, $element );
        foreach my $single_item (@items) {
            $single_item =~ s/^\s+|\s+$//g;    # Trim whitespace
                # Process each individual item if it's not empty
            if ( length $single_item ) {
                $self->process_single_item($single_item);
            }
        }
    }
    else {
        # Process a simple element (not comma/space separated)
        $element =~ s/^\s+|\s+$//g;    # Trim whitespace
        if ( length $element ) {
            $self->process_single_item($element);
        }
    }
    return;
}

sub process_single_item {
    my ( $self, $single_item ) = @_;

    # Check if this is an MTA-delegated alias (starts with mta_)
    if ( $single_item =~ /^mta_(.+)$/x ) {
        $self->process_mta_alias($1);
    }
    # Process based on whether it looks like an email address
    elsif ( $single_item =~ /@/x ) {
        $self->process_potential_email($single_item);
    }
    else {
        $self->process_potential_alias($single_item);
    }
    return;
}

sub process_mta_alias {
    my ( $self, $alias ) = @_;
    
    # Add the alias to the list of MTA aliases (without the mta_ prefix)
    push @{ $self->mta_aliases }, $alias;
    return;
}

sub process_potential_email {
    my ( $self, $item ) = @_;

    my @warning = @{ $self->warning };

    # Check if it has exactly one @ symbol
    my @count = $item =~ /@/xg;
    if ( scalar @count == 1 ) {

        # Normalize and validate the email address
        $item = lc($item);
        my $address = Email::Valid->address($item);
        if ($address) {
            push @{ $self->expanded_addresses }, $address;
        }
        else {
            push @warning,
"ERROR: $item is not a correctly formatted email address, skipping";
        }
    }
    else {
        push @warning,
          "ERROR $item is not a correctly formatted email address, skipping";
    }
    $self->warning( \@warning );
    return;
}

sub process_potential_alias {
    my ( $self, $alias ) = @_;

    my @warning           = @{ $self->warning };
    my $processed_aliases = $self->processed_aliases;

    # Check if the alias has the mta_ prefix (not allowed as a key)
    if ( $alias =~ /^mta_/x ) {
        push @warning, "ERROR: Alias keys with 'mta_' prefix are not allowed, skipping alias '$alias'";
        $self->warning( \@warning );
        return;
    }

    # Check if this alias exists
    if ( !exists $self->aliases->{$alias} ) {
        push @warning, "ERROR: The alias $alias was not found, skipping.";
        $self->warning( \@warning );
        return;
    }

    # Check if we've already processed this alias
    if ( $processed_aliases->{$alias} ) {

        # Skip it - we've already processed it completely
        # prevents duplicate inclusion of and alias
        return;
    }

    if (   ( defined reftype( $self->aliases->{$alias} ) )
        && ( reftype( $self->aliases->{$alias} ) eq 'ARRAY' ) )
    {
        # Handle array of values, convert to string of values
        my @values = @{ $self->aliases->{$alias} };
        my $string = join( ",", @values );

        #  $processed_aliases->{$alias} = $string;
        $processed_aliases->{$alias} = 'Processed';
    }
    else {
        # already a string, just use it as the value
        #  $processed_aliases->{$alias} = $self->aliases->{$alias};
        $processed_aliases->{$alias} = 'Processed';
    }

    $self->processed_aliases($processed_aliases);

    # Expand the alias
    $self->expand_alias($alias);

    $self->warning( \@warning );
    return;
}

sub expand_alias {
    my ( $self, $alias ) = @_;

    my $alias_items = $self->aliases->{$alias};

    # Handle different types of alias values
    if (   ( defined reftype($alias_items) )
        && ( reftype($alias_items) eq 'ARRAY' ) )
    {
        # Handle array of values
        foreach my $element (@$alias_items) {

            # Process each element directly to avoid re-adding to the queue
            $self->extract_addresses_from_list($element);
        }
    }
    else {
        # Handle scalar value
        if ( ( $alias_items =~ /,/x ) || ( $alias_items =~ / /x ) ) {

            # Multiple items in the scalar value
            $self->extract_addresses_from_list($alias_items);
        }
        elsif ( $alias_items =~ /@/x ) {

            # Looks like an email address, validate it
            $self->process_potential_email($alias_items);
        }
        else {
            # Probably an alias, process directly
            $self->process_potential_alias($alias_items);
        }
    }
    return;
}

sub remove_duplicate_email_addresses {
    my ($self) = @_;

    # Use a hash to track unique addresses
    my @uniq_email_addresses;
    my %found_once;

    foreach my $recipient ( @{ $self->expanded_addresses } ) {
        if ( !exists $found_once{$recipient} ) {
            push @uniq_email_addresses, $recipient;
            $found_once{$recipient} = 'true';
        }
    }

    $self->uniq_email_addresses( \@uniq_email_addresses );
    return \@uniq_email_addresses;
}

# Function to detect circular references
sub detect_circular_references {
    my ($self, $aliases)    = @_;
    my %seen_paths          = ();
    my @circular_references = ();

    foreach my $key ( keys %$aliases ) {
        # Skip checking aliases with mta_ prefix
        next if $key =~ /^mta_/x;
        
        my @path = ($key);
        check_circular( $key, $aliases, \@path, \%seen_paths,
            \@circular_references );
    }

    return @circular_references;
}

# Recursive function to check for circular references
sub check_circular {
    my ( $current_key, $aliases, $path, $seen_paths, $circular_references ) = @_;
    my $value = $aliases->{$current_key};

    # If value is a reference to an array, process each element
    if ( ref($value) eq 'ARRAY' ) {
        foreach my $item (@$value) {
            process_item( $item, $aliases, $path, $seen_paths,
                $circular_references );
        }
    }

    # If value is a scalar (string), process it directly
    elsif ( !ref($value) ) {
        process_item( $value, $aliases, $path, $seen_paths,
            $circular_references );
    }
}

# Process individual items and check for circular references
sub process_item {
    my ( $item, $aliases, $path, $seen_paths, $circular_references ) = @_;

    # Split comma-separated values and trim whitespace
    my @items = split( /,/, $item );
    foreach my $subitem (@items) {
        $subitem =~ s/^\s+|\s+$//g;    # Trim whitespace
        next unless $subitem;          # Skip empty items
        
        # Skip items with mta_ prefix
        next if $subitem =~ /^mta_/x;

        # Check if this is a reference to another alias
        if ( exists $aliases->{$subitem} ) {

            # Check for circular reference
            if ( grep { $_ eq $subitem } @$path ) {

                # Found a circular reference
                my @circular_path = ( @$path, $subitem );
                my $path_str      = join( " -> ", @circular_path );
                push @$circular_references, $path_str;
            }
            else {
                # Continue tracing the path
                my @new_path = ( @$path, $subitem );
                check_circular( $subitem, $aliases, \@new_path, $seen_paths,
                    $circular_references );
            }
        }
    }
}

# Clean up with namespace::autoclean
__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

LocalFile - A module for resolving email aliases and building recipient lists
without reliance on the MTA shared aliases file

=head1 SYNOPSIS

    use Mail::Alias::LocalFile;

    $resolver = LocalFile->new(aliases => $alias_file_href);
    $result = $resolver->resolve_recipients($intended_recipients_aref);

    # Get the final comma-separated list of recipients
    my $recipients = $result->{recipients};

    # Check for any warnings
    if (@{$result->{warning}}) {
        print "Warnings: ", join("\n", @{$result->{warning}}), "\n";
    }


    # You can also detect all circular references in  the entire aliases file
    $resolver = LocalFile->new(aliases => $alias_file_href);
    @circular = $resolver->detect_circular_references($alias_file_ref);
    if ( $circular[0] ) {
        print "Circular references detected: ", join("\n", @circular), "\n";
    }

=head1 DESCRIPTION

The C<LocalFile> module provides functionality to resolve email addresses and aliases into a
unique list of email recipients. It handles nested aliases, validates email addresses, and
detects circular references in alias definitions.

This module is particularly useful for applications that need to expand distribution lists
or group aliases into actual email addresses while ensuring uniqueness and validity.

Values with the prefix 'mta_' will not be expanded locally but will be passed to the MTA for
expansion. The 'mta_' prefix will be stripped before passing to the MTA. Alias keys with
the 'mta_' prefix are not allowed and will be skipped with a warning.

=head1 Return Value output ( $result )
Returns a hash_ref:

    $result{expanded_addresses}
    $result{uniq_email_addresses}
    $result{recipients} 
    $result{original_input}
    $result{warning}
    $result{aliases}
    $result{processed_aliases}
    $result{mta_aliases}

Where $result{recipients} is the comma separated expanded email addresses and MTA aliases
suitable for use in to To: field of your email generation code

Other available result keys are useful for troubleshooting

=head1 ATTRIBUTES

=head2 warning

An array reference storing warning messages generated during processing.

    $resolver->warning(["Warning message"]);
    my $warnings = $resolver->warning;

=head2 aliases

A hash reference mapping alias names to their values (either strings or array references).
This attribute is required when creating a new instance.

    my $aliases = $resolver->aliases;

=head2 expanded_addresses

An array reference containing all expanded email addresses (including duplicates).

    my $all_addresses = $resolver->expanded_addresses;

=head2 addresses_and_aliases

An array reference containing the current working list of addresses and aliases
being processed.

    $resolver->addresses_and_aliases(['team', 'support@example.com']);

=head2 original_input

An array reference containing the original input provided to C<resolve_recipients>.

    my $original = $resolver->original_input;

=head2 processed_aliases

A hash reference tracking which aliases have been processed to avoid duplicate
processing.

    my $processed = $resolver->processed_aliases;

=head2 uniq_email_addresses

An array reference containing the final list of unique email addresses after
expansion and deduplication.

    my $unique = $resolver->uniq_email_addresses;

=head2 mta_aliases

An array reference containing aliases that should be passed to the MTA for expansion
after the 'mta_' prefix has been removed.

    my $mta_aliases = $resolver->mta_aliases;

=head1 METHODS

=head2 resolve_recipients

Expands a list of addresses and aliases into a unique list of email addresses.

    my $result = $resolver->resolve_recipients(['team', 'john@example.com']);

Returns a hash reference with the following keys:

=over 4

=item * C<expanded_addresses>: All expanded addresses (including duplicates)

=item * C<uniq_email_addresses>: Unique email addresses after deduplication

=item * C<recipients>: Comma-separated string of unique addresses and MTA aliases

=item * C<original_input>: Original input provided

=item * C<warning>: Any warnings generated during processing

=item * C<aliases>: Reference to the original aliases hash

=item * C<processed_aliases>: Aliases that were processed

=item * C<mta_aliases>: Aliases designated to be processed by the MTA

=back

=head2 extract_addresses_from_list

Processes a single element that might contain multiple addresses or aliases.

    $resolver->extract_addresses_from_list('john@example.com, team');

=head2 process_single_item

Processes a single item, determining if it's an email address, an alias, or an MTA-delegated alias.

    $resolver->process_single_item('john@example.com');

=head2 process_mta_alias

Processes an MTA-delegated alias (with 'mta_' prefix).

    $resolver->process_mta_alias('postmaster');

=head2 process_potential_email

Validates and normalizes a potential email address.

    $resolver->process_potential_email('John@Example.COM');

=head2 process_potential_alias

Processes an alias name, expanding it if found.

    $resolver->process_potential_alias('team');

=head2 expand_alias

Expands an alias into its constituent addresses and/or other aliases.

    $resolver->expand_alias('team');

=head2 remove_duplicate_email_addresses

Removes duplicate email addresses from the expanded list.

    my $unique_addresses = $resolver->remove_duplicate_email_addresses();

=head2 detect_circular_references

Detects circular references in the alias definitions.

    my @circular = $resolver->detect_circular_references($aliases);

Returns an array of strings describing any circular references found, with each string
showing the path of the circular reference (e.g., "team -> dev-team -> team").

=head2 check_circular

Internal recursive function to check for circular references.

=head2 process_item

Internal function to process individual items when checking for circular references.

=head1 DEPENDENCIES

=over 4

=item * Moo

=item * namespace::autoclean

=item * Email::Valid

=item * Scalar::Util

=item * Data::Dumper::Concise

=item * Types::Standard

=back

=head1 AUTHOR

Russ Brewer (RBREW)

=head1 VERSION

0.01

=head1 SEE ALSO

=over 4

=item * Email::Valid

=item * Moo

=back

=cut
