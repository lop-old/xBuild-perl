##===============================================================================
## Copyright (c) 2013-2016 PoiXson, Mattsoft
## <http://poixson.com> <http://mattsoft.net>
##
## Description: Tools and utilities for perl scripts.
##
## Install to location: /usr/bin/xBuild
##
## Download the original from:
##   http://dl.poixson.com/xBuild/
##
## Required packages:
##
## Permission to use, copy, modify, and/or distribute this software for any
## purpose with or without fee is hereby granted, provided that the above
## copyright notice and this permission notice appear in all copies.
##
## THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
## WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
## MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
## ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
## WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
## ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
## OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
##===============================================================================
# tools.pl

package xBuild;

use strict;
use warnings;

use IO::File;
#use Fcntl qw(:flock SEEK_END);



our $debug = 0;

our $INSTANCE_SLEEP_MAX_INTERVAL =  30.0;  # 30 seconds
our $INSTANCE_SLEEP_INCREMENT    =   0.5;  # .5 seconds
our $INSTANCE_SLEEP_MAX_TIME     = 300.0;  #  5 minutes



# turn off stdout buffering
$| = 1;



our $PWD = getcwd;
if (length($xBuild::PWD) == 0) {
	xBuild::error ('Failed to get current working directory!');
	exit 1;
}



sub pid_exists {
	my $pid = shift;
	my $exists = kill 0, $pid;
	return $exists;
}



our $PID_FILE_HANDLE;
our $WROTE_PID_FILE = 0;
sub single_instance {
	if ($xBuild::INSTANCE_SLEEP_MAX_TIME == 0.0) {
		allow_one_instance ();
	} else {
		wait_for_instance ();
	}
}
sub wait_for_instance {
	my $sleeptime = $xBuild::INSTANCE_SLEEP_INCREMENT;
	my $totaltime = 0.0;
	if ( is_single_instance() == 0 ) {
		print "\n";
		sleep($sleeptime);
		$totaltime += $sleeptime;
		while ( is_single_instance() == 0 ) {
			# max time
			if ($xBuild::INSTANCE_SLEEP_MAX_TIME > 0.0) {
				if ($totaltime >= $xBuild::INSTANCE_SLEEP_MAX_TIME) {
					xBuild::error ("Max wait time reached! ${xBuild::INSTANCE_SLEEP_MAX_TIME}s");
					exit 1;
				}
			}
			# increment
			if ($sleeptime < $xBuild::INSTANCE_SLEEP_MAX_INTERVAL) {
				$sleeptime+=$xBuild::INSTANCE_SLEEP_INCREMENT;
			}
			my $now = localtime();
			printf " [ %s ]  %.1fs  Waiting for another instance to finish..\n", $now, $sleeptime;
			sleep($sleeptime);
			$totaltime += $sleeptime;
		}
		print "\n";
	}
}
sub allow_one_instance {
	if ( is_single_instance() == 0 ) {
		xBuild::error ('Another instance is already running!');
		exit 1;
	}
}
sub is_single_instance {
	if (length($xBuild::PID_FILE) == 0) {
		xBuild::error ('PID_FILE variable not set.');
		exit 1;
	}
	# open or create pid file
	sysopen ($xBuild::PID_FILE_HANDLE, $xBuild::PID_FILE, O_RDWR | O_CREAT)
		or xBuild::error ("Cannot open file: $!: $xBuild::PID_FILE");
#	flock($xBuild::PID_FILE_HANDLE, LOCK_EX)
#		or xBuild::error ("Cannot lock file $!: $xBuild::PID_FILE");
	my $OLD_PID = <$xBuild::PID_FILE_HANDLE>;
	if (defined $OLD_PID && length($OLD_PID) gt 0) {
		xBuild::debug ("OLD PID: $OLD_PID");
		if (pid_exists($OLD_PID)) {
			$xBuild::WROTE_PID_FILE = 0;
			return 0;
		}
		sysseek ($xBuild::PID_FILE_HANDLE, 0, SEEK_SET)
			or xBuild::error ("Cannot seek $!: $xBuild::PID_FILE");
		truncate ($xBuild::PID_FILE_HANDLE, 0)
			or xBuild::error ("Cannot truncate $!: $xBuild::PID_FILE");
	}
	# write pid to file
	$xBuild::WROTE_PID_FILE = 1;
	syswrite ($xBuild::PID_FILE_HANDLE, $$)
		or xBuild::error ("Cannot write to $!: $xBuild::PID_FILE");
	return 1;
}
END {
#	flock($xBuild::PID_FILE_HANDLE, LOCK_UN)
#		or xBuild::error ("Cannot unlock file $!: $xBuild::PID_FILE");
	if (defined $xBuild::PID_FILE_HANDLE) {
		close ($xBuild::PID_FILE_HANDLE);
		if ( $xBuild::WROTE_PID_FILE == 1 ) {
			unlink $xBuild::PID_FILE
				or xBuild::error ("Cannot remove $!: $xBuild::PID_FILE");
			xBuild::debug ('Removed lock file');
		}
	}
}
sub set_INSTANCE_SLEEP_MAX_TIME {
	$xBuild::INSTANCE_SLEEP_MAX_TIME = shift;
}



sub load_file_contents {
	my $filepath = shift;
	if (length($filepath) == 0) {
		xBuild::error ("Path argument not provided to load_file_contents() function!");
		return "";
	}
	if (! -f $filepath) {
		xBuild::debug ("File not found: $filepath");
		return "";
	}
	xBuild::debug ("Loading file: $filepath");
	open (FILE, '<:encoding(UTF-8)', $filepath)
		or xBuild::error ("Unable to open file: $filepath");
	my $data = "";
	while (my $line = <FILE>) {
		chomp $line;
		$data .= "$line\n";
	}
	close (FILE);
	if (length($data) == 0) {
		xBuild::debug ("File is empty: $filepath");
		return "";
	}
	return $data;
}



sub bin_file_exists {
	my $filename = shift;
	system ("which $filename >/dev/null || { echo \"Composer is not available - yum install rpm-build\"; exit 1; }")
		and xBuild::error ("'which' command failed!");
}



sub find_file_in_parents {
	my $find = shift;
	my $path = shift;
	my $deep = shift;
	if (! defined $deep) {
		$deep = 0;
	} elsif ($deep < 0) {
		return "";
	}
	if (! defined $path || length($path) == 0 || $path eq $xBuild::PWD) {
		$path = '.';
	}
	xBuild::debug ("Checking dir: $path");
	opendir (DIR, $path)
		or xBuild::error ("$!: $path");
	FILE_LOOP:
	while (my $file = readdir(DIR)) {
		if (length($file) == 0) {
			next FILE_LOOP;
		}
		if ($file eq '.' || $file eq '..') {
			next FILE_LOOP;
		}
		if ($file eq $find) {
			xBuild::debug ("Found file: $path / $file");
			closedir (DIR);
			return "$path/$file";
		}
	}
	closedir (DIR);
	return find_file_in_parents ($find, "$path/..", --$deep);
}



sub run_command {
	my $cmd = shift;
	if (length($cmd) == 0) {
		xBuild::error ("No command argument provided!");
		exit 1;
	}
	if ($xBuild::testing == 0) {
		xBuild::debug ("COMMAND:\n$cmd");
		print "\n";
		system ($cmd) and xBuild::error ("Failed to run command!");
		print "\n";
	} else {
		xBuild::debug ("COMMAND SKIPPED:\n$cmd");
	}
}



sub split_comma {
	my $data = shift;
	if (! defined $data || length($data) == 0) {
		return "";
	}
	return split (/[,\s]+/, $data);
}



##################################################
### logging



sub title {
	big_title ( shift );
}
sub small_title {
	my $title = shift;
	my @lines = split /\n/, $title;
	my $maxlen = 0;
	LINES_LOOP:
	foreach my $line (@lines) {
		my $len = length($line);
		if ($len == 0) {
			next LINES_LOOP;
		}
		if ($len > $maxlen) {
			$maxlen = $len;
		}
	}
	if ($maxlen == 0) {
		return;
	}
	my $full  = ( '*' x ($maxlen + 8) );
	my $blank = ( ' ' x $maxlen );
	print "\n\n";
	print " $full \n";
	foreach my $line (@lines) {
		my $padding = $maxlen - length($line);
		my $padfront = ( ' ' x floor ($padding / 2) );
		my $padend   = ( ' ' x ceil  ($padding / 2) );
		print " **  $padfront$line$padend  ** \n";
	}
	print " $full \n";
	print "\n";
}
sub big_title {
	my $title = shift;
	my @lines = split /\n/, $title;
	my $maxlen = 0;
	LINES_LOOP:
	foreach my $line (@lines) {
		my $len = length($line);
		if ($len == 0) {
			next LINES_LOOP;
		}
		if ($len > $maxlen) {
			$maxlen = $len;
		}
	}
	if ($maxlen == 0) {
		return;
	}
	my $full  = ( '*' x ($maxlen + 10) );
	my $blank = ( ' ' x $maxlen );
	print "\n\n";
	print " $full \n";
	print " $full \n";
	print " ***  $blank  *** \n";
	foreach my $line (@lines) {
		my $padding = $maxlen - length($line);
		my $padfront = ( ' ' x floor ($padding / 2) );
		my $padend   = ( ' ' x ceil  ($padding / 2) );
		print " ***  $padfront$line$padend  *** \n";
	}
	print " ***  $blank  *** \n";
	print " $full \n";
	print " $full \n";
	print "\n";
}



sub debug {
	if ($xBuild::debug == 0) {
		return;
	}
	my $msg = shift;
	if (! defined $msg || length($msg) == 0) {
		print "\n";
		return;
	}
	my @lines = split /\n/, $msg;
	LINES_LOOP:
	foreach my $line (@lines) {
		if (length($line) == 0) {
			next LINES_LOOP;
		}
		print " [debug]  $line\n";
	}
}
sub error {
	my $msg = shift;
	my $err = shift;
	if (!defined $msg || length($msg) == 0) {
		$msg = "Failed unexpectedly!";
	}
	if (!defined $err || length($err) == 0 || $err == 0) {
		$err = 1;
	}
	print "\n\n";
	print "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
	print "\n [ERROR:$err]  $msg\n\n";
	print "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
	print "\n\n";
	exit 1;
}



1;