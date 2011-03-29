# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Finnigan.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 106;
BEGIN { use_ok('Finnigan') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# set-up
my $file = "t/100225.raw";
open INPUT, "<$file" or die "can't open '$file': $!";
binmode INPUT;

# The following objects will be tested in the order they occur
# in the input file, unless a look-ahead is necessary.

# FileHeader
my $header = Finnigan::FileHeader->decode(\*INPUT);
is( $header->version, 63, "FileHeader->version" );
is( $header->size, 1356, "FileHeader->size" );
is( $header->audit_start->time, "2010-02-25 09:02:27", "AuditTag->time" );

# SeqRow / InjectionData -- sample data
my $seq_row = Finnigan::SeqRow->decode(\*INPUT, $header->version);
is( $seq_row->size, 260, "SeqRow->size" );
is( $seq_row->file_name, 'C:\Xcalibur\calsolution\100225.raw', "SeqRow->file_name" );
is( $seq_row->injection->size, 64, "InjectionData->size" );
is( $seq_row->injection->n, 1, "InjectionData->n" );
# untested in SeqRow::InjectionData: volume, injected volume, internal standard amount, dilution factor, the unknowns

# CASInfo / CASInfoPreamble -- autosampler data
my $cas_info = Finnigan::CASInfo->decode(\*INPUT);
is( $cas_info->size, 28, "CasInfo->size" );
is( $cas_info->preamble->size, 24, "CasInfoPreamble->size" );
# untested in CASInfo: text
# untested in CASInfo::Preamble: number of wells; the unknowns

# RawFileInfo / RawFileInfoPreamble -- the root index structure; interesting information is all in the preamble
my $rfi = Finnigan::RawFileInfo->decode(\*INPUT, $header->version);
is( $rfi->stringify, "Thu Feb 25 2010 9:2:27.781; data addr: 24950; RunHeader addr: 777542", "RawFileInfo->stringify");
is( $rfi->size, 844, "RawFileInfo->size" );
is( $rfi->preamble->size, 804, "RawFileInfoPreamble->size" );
is( $rfi->preamble->data_addr, 24950, "RawFileInfoPreamble->data_addr" );
is( $rfi->preamble->run_header_addr, 777542, "RawFileInfoPreamble->run_header_addr" );
is( $rfi->{data}->{"unknown text"}->{value}, 'DB23HPD1', "RawFileInfo->{unknown text}" );

# MethodFile / OLE2File
my $mf = Finnigan::MethodFile->decode(\*INPUT);
is( $mf->size, 3646, "MethodFile->size" );
is( $mf->file_size, 20992, "MethodFile->file_size" );
# the entire translation table
is( $mf->translation_table->[0], 'LTQ Orbitrap XL MS', 'MethodFile->translation_table (key)');
is( $mf->translation_table->[1], 'LTQ', 'MethodFile->translation_table (value)');
# name translation for the first instrument
is( ($mf->instrument_name(1))[0], 'LTQ Orbitrap XL MS', 'MethodFile->instrument_name(1) (key)');
is( ($mf->instrument_name(1))[1], 'LTQ', 'MethodFile->instrument_name(1) (value)');
# container functions
is( $mf->container->dif->stringify, "Double-Indirect FAT; 1/109 entries used", "OLE2DIF->stringify");
is( $mf->container->dif->sect->[0], 0, "OLE2DIF->sect used");
isnt( $mf->container->dif->sect->[1], 0, "OLE2DIF->sect vacant");
my $text_node = $mf->container->find("LTQ/Text");
ok($text_node, "OLE2File->find");
is( $text_node->name, "Text", "OLE2DirectoryEntry->name" );
is( length $text_node->data, 9722, "OLE2DirectoryEntry->data length" );
like($text_node->data, qr/S\0e\0g\0m\0e\0n\0t\0 \0001\0 \0I\0n\0f\0o\0r\0m\0a\0t\0i\0o\0n\0/m, 'OLE2DirectoryEntry->data'); # it is UTF-16

# fast-forward to RunHeader
my $run_header_addr = $rfi->preamble->run_header_addr;
seek INPUT, $run_header_addr, 0;
is( tell INPUT, 777542, "seek to run header address" );

my $run_header      = Finnigan::RunHeader->decode( \*INPUT, $header->version );
my $inst_id         = Finnigan::InstID->decode( \*INPUT );
is( $inst_id->model, 'LTQ Orbitrap XL', "InstID->model");

my $scan_index_addr = $run_header->sample_info->scan_index_addr;
my $trailer_addr    = $run_header->trailer_addr;

is( $run_header->sample_info->start_time, 0.00581833333333333, "RunHeader->sample_info->start_time" );
is( $run_header->sample_info->end_time, 0.242753333333333, "RunHeader->sample_info->end_time" );
is( $scan_index_addr, 829706, "RunHeader->sample_info->scan_index_addr" );
is( $trailer_addr, 832082, "RunHeader->trailer_addr" );

my $first_scan = $run_header->sample_info->first_scan;
my $last_scan  = $run_header->sample_info->last_scan;
is( $first_scan, 1, "RunHeader->sample_info->first_scan" );
is( $last_scan, 33, "RunHeader->sample_info->last_scan" );

# fast-forward to ScanIndex
seek INPUT, $scan_index_addr, 0;
is( tell INPUT, 829706, "seek to scan index address" );

# measure scan index record size
my $entry       = Finnigan::ScanIndexEntry->decode( \*INPUT );

my $record_size = $entry->size;
is( $entry->size, 72, "ScanIndexEntry->decode->size" );

# check that the index record stream is of the right size
my $stream_size = $trailer_addr - $scan_index_addr;
my $nrecords = $stream_size / $record_size;
is( $stream_size % $record_size, 0, "scan index record stream should contain a whole number of $record_size\-byte records");

# look inside this index entry
is( $entry->offset, 0, "ScanIndexEntry->offset" );
is( $entry->index, 0, "ScanIndexEntry->index" );
is( $entry->scan_event, 0, "ScanIndexEntry->scan_event" );
is( $entry->scan_segment, 0, "ScanIndexEntry->scan_segment" );
is( $entry->next, 1, "ScanIndexEntry->next" );
is( $entry->unknown, 21, "ScanIndexEntry->unknown" );
is( $entry->data_size, 31932, "ScanIndexEntry->data_size" );
is( $entry->start_time, 0.00581833333333333, "ScanIndexEntry->start_time" );
is( $entry->total_current, 10851256, "ScanIndexEntry->total_current" );
is( $entry->base_mz, 1521.9716796875, "ScanIndexEntry->base_mz" );
is( $entry->base_intensity, 796088, "ScanIndexEntry->base_intensity" );
is( $entry->low_mz, 400, "ScanIndexEntry->low_mz" );
is( $entry->high_mz, 2000, "ScanIndexEntry->high_mz" );


# read the first ScanEvent record
seek INPUT, $trailer_addr, 0;
my $rec;
my $bytes_to_read = 4;
my $nbytes = read INPUT, $rec, $bytes_to_read;
is ( $nbytes, $bytes_to_read, "should have read the $bytes_to_read of the trailer events count");
my $trailer_length = unpack 'V', $rec;
is ( $trailer_length, 33, "the trailer events count should be 33");

my $scan_event = Finnigan::ScanEvent->decode( \*INPUT, $header->version );
is ($scan_event->preamble->analyzer('decode'), "FTMS", "ScanEvent->preamble->analyzer");
is ($scan_event->preamble->polarity('decode'), "positive", "ScanEvent->preamble->polarity");
is ($scan_event->preamble->scan_mode('decode'), "profile", "ScanEvent->preamble->scan_mode");
is ($scan_event->preamble->ionization('decode'), "ESI", "ScanEvent->preamble->ionization");
is ($scan_event->preamble->dependent, 0, "ScanEvent->preamble->dependent");
is ($scan_event->preamble->scan_type('decode'), "Full", "ScanEvent->preamble->scan_type");
is ($scan_event->preamble->ms_power('decode'), "MS1", "ScanEvent->preamble->ms_power");
is ("$scan_event", "FTMS + p ESI Full ms [400.00-2000.00]", "ScanEvent->preamble->stringify");
is ($scan_event->preamble->corona('decode'), "undefined", "ScanEvent->preamble->corona");
is ($scan_event->preamble->wideband('decode'), "Off", "ScanEvent->preamble->wideband");
is ($scan_event->fraction_collector->stringify, "[400.00-2000.00]", "ScanEvent->fraction_collector->stringify");
is ($scan_event->np, 0, "ScanEvent->np");
is ($scan_event->precursors, undef, "ScanEvent->precursors");

my $converter = $scan_event->converter;
is (&$converter(1), 38518081.414831, "ScanEvent->converter");


# read the second ScanEvent record
$scan_event = Finnigan::ScanEvent->decode( \*INPUT, $header->version );
is ($scan_event->preamble->analyzer('decode'), "ITMS", "ScanEvent->preamble->analyzer (2)");
is ($scan_event->preamble->polarity('decode'), "positive", "ScanEvent->preamble->polarity (2)");
is ($scan_event->preamble->scan_mode('decode'), "profile", "ScanEvent->preamble->scan_mode (2)");
is ($scan_event->preamble->dependent, 1, "ScanEvent->preamble->dependent (2)");
is ($scan_event->preamble->scan_type('decode'), "Full", "ScanEvent->preamble->scan_type (2)");
is ($scan_event->preamble->ms_power('decode'), "MS2", "ScanEvent->preamble->ms_power (2)");
is ("$scan_event", 'ITMS + p ESI d Full ms2 445.12@cid35.00 [110.00-460.00]', "ScanEvent->preamble->stringify (2)");
is ($scan_event->preamble->corona('decode'), "undefined", "ScanEvent->preamble->corona (2)");
is ($scan_event->preamble->wideband('decode'), "Off", "ScanEvent->preamble->wideband (2)");
is ($scan_event->fraction_collector->stringify, "[110.00-460.00]", "ScanEvent->fraction_collector->stringify (2)");
is ($scan_event->np, 1, "ScanEvent->np");
my $pr = join ", ", map {"$_"} @{$scan_event->precursors};
is ($pr, '445.12@cid35.00', "ScanEvent->precursors (2)");
$Finnigan::activationMethod = 'ecd';
$pr = $scan_event->precursors->[0]->stringify;
is ($pr, '445.12@ecd35.00', "ScanEvent->precursors (3: activation method)");

# read the first scan
my $data_addr = $rfi->preamble->data_addr;
seek INPUT, $data_addr, 0;
is( tell INPUT, 24950, "seek to scan data address" );

my $ph = Finnigan::PacketHeader->decode( \*INPUT );
is ($ph->{data}->{"unknown long[1]"}->{value}, 1, "PacketHeader->{unknown long[1]}");
is ($ph->profile_size, 5624, "PacketHeader->profile_size");
is ($ph->peak_list_size, 1161, "PacketHeader->peak_list_size");
is ($ph->layout, 128, "PacketHeader->layout");
is ($ph->descriptor_list_size, 580, "PacketHeader->descriptor_list_size");
is ($ph->size_of_unknown_stream, 581, "PacketHeader->size_of_unkonwn_stream");
is ($ph->size_of_triplet_stream, 27, "PacketHeader->size_of_triplet_stream");
is ($ph->{data}->{"unknown long[2]"}->{value}, 0, "PacketHeader->{unknown long[2]}");
is ($ph->low_mz, 400.0, "PacketHeader->low_mz");
is ($ph->high_mz, 2000.0, "PacketHeader->high_mz");

my $profile = Finnigan::Profile->decode( \*INPUT, $ph->layout );
is ($profile->first_value, 344.543619791667, "Profile->first_value");
is ($profile->step, -1/(3*512), "Profile->step");
is ($profile->peak_count, 580, "Profile->peak_count");
is ($profile->nbins, 293046, "Profile->nbins");

$profile->set_converter( $converter ); # from ScanEvent 1 above
my $bins = $profile->bins;
is ($bins->[0]->[0], 400.209152455266, "Profile->bins (Mz)");
is ($bins->[0]->[1], 447.530578613281, "Profile->bins (signal)");

# back to the first scan; read with compound decoder
seek INPUT, $data_addr, 0;
is( tell INPUT, 24950, "seek to scan data address (2)" );

my $scan = Finnigan::Scan->decode( \*INPUT );
is ( $scan->header->profile_size, 5624, "Scan->header->profile_size");
$profile = $scan->profile;
$profile->set_converter( $converter ); # from ScanEvent 1 above
$bins = $profile->bins;
is ($bins->[0]->[0], 400.209152455266, "Scan->profile->bins (Mz)");
is ($bins->[0]->[1], 447.530578613281, "Scan->profile->bins (signal)");

my $c = $scan->centroids;
is ($c->count, 580, "Scan->centroids->count");
is ($c->list->[0]->[0], 400.212463378906, "Scan->centroids->list (Mz)");
is ($c->list->[0]->[1], 1629.47326660156, "Scan->centroids->list (abundance)");

#use Data::Dumper;
#print STDERR Dumper($scan->centroids);
