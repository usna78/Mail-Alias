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

# Methods
sub resolve_recipients {
    my ( $self, $addresses_and_aliases_ref ) = @_;

    # Initialize all data structures
    $self->addresses_and_aliases($addresses_and_aliases_ref);
    my @values = @{$addresses_and_aliases_ref};
    $self->original_input( \@values );
    $self->expanded_addresses( [] );
    $self->processed_aliases( {} );

    # Process all addresses and aliases
    while ( @{ $self->addresses_and_aliases } ) {
        my $item = shift @{ $self->addresses_and_aliases };
        $self->extract_addresses_from_list($item);
    }

    # Remove duplicates and build the final comma-separated list
    my $uniq_email_recipients = $self->remove_duplicate_email_addresses();

    my $recipients = join( ',', @{$uniq_email_recipients} );

    my %result;
    $result{expanded_addresses}   = $self->expanded_addresses;
    $result{uniq_email_addresses} = $self->uniq_email_addresses;
    $result{recipients}           = $recipients;
    $result{original_input}       = $self->original_input;
    $result{warning}              = $self->warning;
    $result{aliases}              = $self->aliases;
    $result{processed_aliases}    = $self->processed_aliases;

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

    # Process based on whether it looks like an email address
    if ( $single_item =~ /@/x ) {
        $self->process_potential_email($single_item);
    }
    else {
        $self->process_potential_alias($single_item);
    }
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
