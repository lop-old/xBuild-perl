use strict;
use warnings;

use IO::File;
#use Fcntl qw(:flock SEEK_END);



our $INSTANCE_SLEEP_MAX_INTERVAL =  30.0;  # 30 seconds
our $INSTANCE_SLEEP_INCREMENT    =   0.5;  # .5 seconds
our $INSTANCE_SLEEP_MAX_TIME     = 300.0;  #  5 minutes



sub pid_exists {
	my $pid = shift;
	my $exists = kill 0, $pid;
	return $exists;
}



our $PID_FILE_HANDLE;
our $WROTE_PID_FILE = 0;
sub wait_for_instance {
	my $sleeptime = $main::INSTANCE_SLEEP_INCREMENT;
	my $totaltime = 0.0;
	if ( is_single_instance() eq 0 ) {
		print "\n";
		sleep($sleeptime);
		$totaltime += $sleeptime;
		while ( is_single_instance() eq 0 ) {
			# max time
			if ($main::INSTANCE_SLEEP_MAX_TIME > 0.0) {
				if ($totaltime >= $main::INSTANCE_SLEEP_MAX_TIME) {
					error ("Max wait time reached! ${main::INSTANCE_SLEEP_MAX_TIME}s");
					exit 1;
				}
			}
			# increment
			if ($sleeptime < $main::INSTANCE_SLEEP_MAX_INTERVAL) {
				$sleeptime+=$main::INSTANCE_SLEEP_INCREMENT;
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
	if ( is_single_instance() eq 0 ) {
		error ('Another instance is already running!');
		exit 1;
	}
}
sub is_single_instance {
	if (length($main::PID_FILE) eq 0) {
		error ('PID_FILE variable not set.');
		exit 1;
	}
	# open or create pid file
	sysopen ($main::PID_FILE_HANDLE, $main::PID_FILE, O_RDWR | O_CREAT)
		or error ("Cannot open file: $!: $main::PID_FILE");
#	flock($main::PID_FILE_HANDLE, LOCK_EX)
#		or error ("Cannot lock file $!: $main::PID_FILE");
	my $OLD_PID = <$main::PID_FILE_HANDLE>;
	if (defined $OLD_PID && length($OLD_PID) gt 0) {
		debug ("OLD PID: $OLD_PID");
		if (pid_exists($OLD_PID)) {
			$main::WROTE_PID_FILE = 0;
			return 0;
		}
		sysseek ($main::PID_FILE_HANDLE, 0, SEEK_SET)
			or error ("Cannot seek $!: $main::PID_FILE");
		truncate ($main::PID_FILE_HANDLE, 0)
			or error ("Cannot truncate $!: $main::PID_FILE");
	}
	# write pid to file
	$main::WROTE_PID_FILE = 1;
	syswrite ($main::PID_FILE_HANDLE, $$)
		or error ("Cannot write to $!: $main::PID_FILE");
	return 1;
}
END {
#	flock($main::PID_FILE_HANDLE, LOCK_UN)
#		or error ("Cannot unlock file $!: $main::PID_FILE");
	if (defined $main::PID_FILE_HANDLE) {
		close ($main::PID_FILE_HANDLE);
		if ( $main::WROTE_PID_FILE eq 1 ) {
			unlink $main::PID_FILE
				or error ("Cannot remove $!: $main::PID_FILE");
			debug ('Removed lock file');
		}
	}
}



sub load_file_contents {
	my $filepath = shift;
	if (! -f $filepath) {
		debug ("File not found: $filepath");
		return "";
	}
	debug ("Loading file: $filepath");
	open (FILE, '<:encoding(UTF-8)', $filepath)
		or error ("Unable to open file: $filepath");
	my $data = "";
	while (my $line = <FILE>) {
		chomp $line;
		$data .= "$line\n";
	}
	close (FILE);
	if (length($data) == 0) {
		debug ("File is empty: $filepath");
		return "";
	}
	return $data;
}



sub bin_file_exists {
	my $filename = shift;
	system ("which $filename >/dev/null || { echo \"Composer is not available - yum install rpm-build\"; exit 1; }")
		and error ("'which' command failed!");
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
	if (! defined $path || length($path) == 0 || $path eq $main::PWD) {
		$path = '.';
	}
	debug ("Checking dir: $path");
	opendir (DIR, $path)
		or error ("$!: $path");
	FILE_LOOP:
	while (my $file = readdir(DIR)) {
		if (length($file) == 0) {
			next FILE_LOOP;
		}
		if ($file eq '.' || $file eq '..') {
			next FILE_LOOP;
		}
		if ($file eq $find) {
			debug ("Found file: $path / $file");
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
		error ("No command argument provided!");
		exit 1;
	}
	if ($main::testing == 0) {
		debug ("COMMAND:\n$cmd");
		print "\n";
		system ($cmd) and error ("Failed to run command!");
		print "\n";
	} else {
		debug ("COMMAND SKIPPED:\n$cmd");
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
	if ($main::debug eq 0) {
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
	if (!defined $err || length($err) == 0 || $err eq "0") {
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