package Tatooine::File;

=nd
Package: File
	Class for working with files.
=cut

use strict;
use warnings;

use utf8;

=nd
Method: fileUpload($opt)
	The method of uploading files on the server.

Parameters:
	$opt			-	hash with parameters
	$opt->{file}	-	source file
	$opt->{name}	-	The new file name to write to the server
=cut
sub uploadFile {
	my ($self, $opt) = @_;
	my ($input_file, $file_name, $path);

	$input_file = $opt->{file};
	$file_name = $opt->{name};

	# The path for uploading
	$path = $opt->{path};
	$path = $self->filePath() unless $path;

	# Get the file extension
	my ($file_extension) = $input_file =~ m#([^\\/:]+)$#;
	$file_extension =~ s/[^.]+\.(.*)/$1/gi;

	unless ($file_name){
		$file_name = $input_file;
		$file_name =~ s/\.$file_extension//;
	}
	$file_name .= ".$file_extension" if $file_name;

	open(OUT,">$path$file_name");
	binmode(OUT, ':bytes');
	while (<$input_file>) {
		print OUT $_;
	}
	close(OUT);

	return $file_name;
}

1;