package Finnigan::GenericDataHeader;

use strict;
use warnings;

use Finnigan;
use base 'Finnigan::Decoder';

sub decode {
  my ($class, $stream) = @_;

  my $self = Finnigan::Decoder->read($stream, [n => ['V', 'UInt32']]);
  bless $self, $class;

  if ( $self->n ) {
    $self->iterate_object($stream, $self->n, field => 'Finnigan::GenericDataDescriptor');
  }

  return $self;
}

sub n {
  # the number of data descriptors
  shift->{data}->{"n"}->{value};
}

sub fields {
  my @list;
  foreach my $f ( @{shift->{data}->{"field"}->{value}} ) {
    push @list, $f->definition;
  }
  return \@list;
}

1;
__END__

=head1 NAME

Finnigan::GenericDataHeader -- a decoder for GenericDataHeader, a decoder key for GenericRecord types

=head1 SYNOPSIS

  use Finnigan;
  my $h = Finnigan::GenericDataHeader->decode(\*INPUT);
  say $h->n;
  say $h->dump;

=head1 DESCRIPTION


=head2 EXPORT

None

=head1 SEE ALSO

Finnigan::ScanEventPreamble
Finnigan::FractionCollector
Finnigan::Reaction

=head1 AUTHOR

Gene Selkov, E<lt>selkovjr@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Gene Selkov

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut