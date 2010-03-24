package Finnigan::PacketHeader;

use strict;
use warnings;

use Finnigan;
use base 'Finnigan::Decoder';


sub decode {
  my ($class, $stream) = @_;

  my $fields = [
		"unknown long[1]"         => ['V',      'UInt32'],
		"profile size"            => ['V',      'UInt32'],
		"peak list size"          => ['V',      'UInt32'],
		"layout"                  => ['V',      'UInt32'],
		"descriptor list size"    => ['V',      'UInt32'],
		"size of unknown stream"  => ['V',      'UInt32'],
		"size of triplet stream"  => ['V',      'UInt32'],
		"unknown long[2]"         => ['V',      'UInt32'],
		"low mz"                  => ['f',      'Float32'],
		"high mz"                 => ['f',      'Float32'],
	       ];

  my $self = Finnigan::Decoder->read($stream, $fields);

  return bless $self, $class;
}

sub profile_size {
  shift->{data}->{"profile size"}->{value};
}

sub peak_list_size {
  shift->{data}->{"peak list size"}->{value};
}

sub layout {
  shift->{data}->{"layout"}->{value};
}

sub descriptor_list_size {
  shift->{data}->{"descriptor list size"}->{value};
}

sub size_of_unknown_stream {
  shift->{data}->{"size of unknown stream"}->{value};
}

sub size_of_triplet_stream {
  shift->{data}->{"size of triplet stream"}->{value};
}

sub low_mz {
  shift->{data}->{"low mz"}->{value};
}

sub high_mz {
  shift->{data}->{"high mz"}->{value};
}


1;
__END__

=head1 NAME

Finnigan::ScanIndexEntry -- decoder for ScanIndexEntry, a linked list item pointing to scan data

=head1 SYNOPSIS

  use Finnigan;
  my $entry = Finnigan::ScanIndexEntry->decode(\*INPUT);
  say $entry->offset; # returns an offset from the start of scan data stream 
  say $entry->data_size;
  $entry->dump;

=head1 DESCRIPTION

ScanIndexEntry is a static (fixed-size) structure containing the
pointer to a scan, the scan's data size and some auxiliary information
about the scan.

ScanIndexEntry elements seem to form a linked list. Each
ScanIndexEntry contains the index of the next entry.

Although in all observed instances the scans were sequential and their
indices could be ignored, it may not always be the case.

It is not clear whether scan index numbers start at 0 or at 1. If they
start at 0, the list link index must point to the next item. If they
start at 1, then "index" will become "previous" and "next" becomes
"index" -- the list will be linked from tail to head. Although
observations are lacking, I am inclined to interpret it as a
forward-linked list, simply from common sense.


=head2 EXPORT

None

=head1 SEE ALSO

Finnigan::RunHeader

=head1 AUTHOR

Gene Selkov, E<lt>selkovjr@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Gene Selkov

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut