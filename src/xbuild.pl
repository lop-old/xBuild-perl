#!/usr/bin/perl -w
##===============================================================================
## Copyright (c) 2013-2016 PoiXson, Mattsoft
## <http://poixson.com> <http://mattsoft.net>
##
## Description: Build and deploy script for maven and rpm projects.
##
## Install to location: /usr/bin/xBuild
##
## Download the original from:
##   http://dl.poixson.com/xBuild/
##
## Required packages: perl-JSON perl-Proc-PID-File perl-Readonly perl-Switch
##                    gradle maven2
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
# xbuild.pl

package xBuild;

use strict;
use warnings;

use POSIX;
use Readonly;
use File::Copy;
use JSON;
use Switch;

use Data::Dumper;



##################################################

Readonly our $XBUILD_VERSION => '2.0.0';
Readonly our $PID_FILE => '/var/run/xBuild/xbuild.pid';

Readonly our $PROJECT_CONFIG_FILE  => 'xbuild.json';
Readonly our $DEPLOY_CONFIG_FILE   => 'xdeploy.json';

Readonly our $TEMP_BUILD_PATH => '/tmp/xbuild';

##################################################



our $config;
our $deploy;
our $dryrun = 0;

our $project_build_number = 'x';
our $deploy_config_depth  = 2;

our @run_goals = ();

require '/usr/bin/xBuild/tools.pl';



sub display_help {
	print "\n";
	print "Usage: xbuild [-hv] [GOAL]...\n";
	print "Reads a xbuild.json config file from a project and performs build goals.\n";
	print "\n";
	print "  -n, --build-number         set the build number\n";
	print "  -D, --deploy-config-depth  number of parent directories to ascend\n";
	print "                             when searching for deploy.json config file\n";
	print "\n";
	print "  -w, --max-wait  set the max wait in seconds if another instance is busy\n";
	print "                  set to -1 for no timeout, or 0 to fail immediately\n";
	print "                  default: 300 (5 minutes)\n";
	print "\n";
	print "  -t, --dry       dry run without writing\n";
	print "  -d, --debug     debug mode, most verbose logging\n";
	print "\n";
	print "  -h, --help      display this help and exit\n";
	print "  -v, --version   output version information and exit\n";
	print "\n";
	exit 1;
}



# parse arguments
ARGS_LOOP:
while (my $arg = shift(@ARGV)) {
	# FLAGS
	if ( $arg =~ /^\-/ ) {
		switch ($arg) {
			case '-n' {
				$arg = '--build-number';
			}
			case '-D' {
				$arg = '--deploy-config-depth';
			}
			case '-w' {
				$arg = '--max-wait';
			}
			case '-t' {
				$arg = '--dry';
			}
			case '--test' {
				$arg = '--dry';
			}
			case '-d' {
				$arg = '--debug';
			}
			case '-h' {
				$arg = '--help';
			}
			case '-v' {
				$arg = '--version';
			}
		} # /ALIAS_LOOP
		switch ($arg) {
			case '--build-number' {
				$project_build_number = shift(@ARGV);
			}
			case '--deploy-config-depth' {
				$xBuild::deploy_config_depth = shift(@ARGV);
			}
			case '--max-wait' {
				set_INSTANCE_SLEEP_MAX_TIME (shift(@ARGV));
			}
			case '--dry' {
				$dryrun = 1;
			}
			case '--debug' {
				$xBuild::debug = 1;
			}
			case '--help' {
				display_help();
				exit 1;
			}
			case '--version' {
				print "\n";
				print "xBuild ${XBUILD_VERSION}\n";
				print "\n";
				exit 1;
			}
			else {
				xBuild::error ("Unknown argument: ${arg}");
				exit 1;
			}
		} # /FLAG_SWITCH
		next ARGS_LOOP;
	} # /FLAGS
	# anything else should be a goal
	push (@run_goals, $arg);
} # /ARGS_LOOP



if ($xBuild::debug != 0) {
	xBuild::debug ('Debug mode enabled');
}
if ($dryrun != 0) {
	xBuild::debug ('Dry run enabled');
}
if ($xBuild::PWD =~ m/^\/(usr|bin)\/.*/ ) {
	xBuild::error ('Sorry, you cannot run this command from within /usr or /bin');
	exit 1;
}



# allow single instance
xBuild::single_instance ();



##################################################
### load config files



# load xbuild.json
sub load_xbuild_json {
	my $config_file = "${xBuild::PWD}/${xBuild::PROJECT_CONFIG_FILE}";
	my $data = load_file_contents ($config_file);
	if (! defined $data || length($data) == 0) {
		xBuild::error ("File not found or failed to load: ${config_file}");
		exit 1;
	}
	$xBuild::config = JSON->new->utf8->decode($data);
}
# load xdeploy.json
sub load_xdeploy_json {
	xBuild::debug ("Looking for deploy config: ${xBuild::DEPLOY_CONFIG_FILE}");
	my $found = find_file_in_parents (
		$xBuild::DEPLOY_CONFIG_FILE,
		'',
		$xBuild::deploy_config_depth
	);
	if (length($found) == 0) {
		xBuild::debug ("File not found: ${xBuild::DEPLOY_CONFIG_FILE}");
	} else {
		my $config_file = "${xBuild::PWD}/${found}";
		xBuild::debug ("Loading file: ${config_file}");
		my $data = load_file_contents ($config_file);
		if (defined $data && length($data) > 0) {
			$xBuild::deploy = JSON->new->utf8->decode($data);
		}
	}
}



# load configs
load_xbuild_json ();
load_xdeploy_json ();
xBuild::debug ();



##################################################
### load goals














print "============================";
exit 1;










#my  $SCRIPT_PATH      = "/usr/bin/xBuild";
#my  $GOAL_SCRIPT_PATH = "$SCRIPT_PATH/goals";



#require "$SCRIPT_PATH/tools.pl";


















##################################################
### load config files



# load xbuild.json
#{
#	my $data = load_file_contents ($project_config_file);
#	if (! defined $data || length($data) == 0) {
#		error ("File not found or failed to load: $project_config_file");
#		exit 1;
#	}
#	$config = JSON->new->utf8->decode($data);
#}
# load xdeploy.json
#{
#	debug ("Looking for deploy config: ${main::deploy_config_file}");
#	my $found = find_file_in_parents (
#		$main::deploy_config_file,
#		'',
#		$DEPLOY_SEARCH_DEEP
#	);
#	if (length($found) == 0) {
#		debug ("File not found: ${main::deploy_config_file}");
#	} else {
#		debug ("Loading file: $found");
#		my $data = load_file_contents ("${main::PWD}/${found}");
#		if (defined $data && length($data) > 0) {
#			$deploy = JSON->new->utf8->decode($data);
#		}
#	}
#}
#debug ();



# project name
#$project_name = $xBuild::config->{Name};
# project version
#$project_version = $xBuild::config->{Version};



##################################################
### load goals



### main goals
# from xdeploy.json
#if ( (0+@goals_main) == 0 ) {
#	if (defined $deploy && exists $deploy->{'Default Goals'}) {
#		my $data = $deploy->{'Default Goals'};
#		@goals_main = split_comma ($data);
#	}
#}
# last resort defaults
#if ( (0+@goals_main) == 0 ) {
#	@goals_main = split_comma ("clean,build");
#}
#if ( (0+@goals_main) == 0 ) {
#	error ("Failed to find main goals to perform!");
#	exit 1;
#}



### build goals
# from xbuild.json
#if ( (0+@goals_build) == 0 ) {
#	if (exists $config->{'Build Goals'}) {
#		my $data = $config->{'Build Goals'};
#		@goals_build = split_comma ($data);
#	}
#}
# last resort defaults
#if ( (0+@goals_build) == 0 ) {
#	@goals_build = split_comma ("clean");
#}
#if ( (0+@goals_build) == 0 ) {
#	error ("Failed to find build goals to perform!");
#	exit 1;
#}



##################################################
### display info



#print "\n";
##########################################################################################################################################print "Project: $project_name\n";
##########################################################################################################################################print "Version: $project_version\n";
##########################################################################################################################################print "Build:   $project_build_number\n";
#print "Pid: $main::PID\n";
#if ($main::debug != 0) {
#	print "--Debug--\n";
#}
#if ($main::testing != 0) {
#	print "--Testing--\n";
#}
#print "\n";







print "\n\n\n\n\n\n\n";




#{
#	my $path = '/media/zwork/xBuild/src/goals/*.pl';
#	my @files = < $path >;
#	foreach my $entry (@files) {
#		if ( -f $entry ) {
#			print "$entry\n";
#		}
#		my($filename, $directories, $suffix) = fileparse($entry);
#		$filename=~s/\.pm//gx;
#	}
#}



print "\n\n\n\n\n\n\n";










print "DONE\n";
exit 1;



##################################################
### perform goals



#require "$GOAL_SCRIPT_PATH/clean.pl";
#require "$GOAL_SCRIPT_PATH/composer.pl";
#require "$GOAL_SCRIPT_PATH/deploy.pl";
#require "$GOAL_SCRIPT_PATH/gradle.pl";
#require "$GOAL_SCRIPT_PATH/maven.pl";
#require "$GOAL_SCRIPT_PATH/prep.pl";
#require "$GOAL_SCRIPT_PATH/rpm.pl";



# version files
#@project_version_files = @{$xBuild::config->{'Version Files'}};
#$project_version = parse_version_from_files(@project_version_files);



# display info
#big_title ("Project: $project_name\nVersion: $project_version $project_build_number");
#if ($project_build_number eq 'x') {
#	print " Build Number: <Not Set>\n";
#} else {
#	print " Build Number: $project_build_number\n";
#}
#print " User: $USER\n";
#print "\n";
##########################################################################################################################################{
##########################################################################################################################################	my $goals_str = join ", ", @goals_main;
##########################################################################################################################################	print " Goals: "; print $goals_str; print "\n";
##########################################################################################################################################	if (", $goals_str, " =~ /\sbuild,\s/ ) {
##########################################################################################################################################		print " Build: "; print join ", ", @goals_build; print "\n";
##########################################################################################################################################	}
##########################################################################################################################################}
##########################################################################################################################################my $project_title = "$project_name $project_version $project_build_number";
##########################################################################################################################################if (0+@goals_main == 0) {
##########################################################################################################################################	xBuild::error ("No main goals to perform..\n");
##########################################################################################################################################	exit 1;
##########################################################################################################################################}
##########################################################################################################################################for my $goal (@goals_main) {
##########################################################################################################################################	perform_goal ($goal);
##########################################################################################################################################}



#our $last_goal = "";
#sub perform_goal {
#	my $goal = shift;
##	small_title ("$project_title\nGoal: $goal");
#	small_title ("Goal: $goal");
#	# goal already ran
#	if (defined $last_goal && length($last_goal) > 0) {
#		if ($goal eq $last_goal) {
#			print "\nSkipping goal '$goal' has just run..\n";
#			return;
#		}
#	}
#	my $goal_config;
#	if(exists $xBuild::config->{Goals}->{$goal}) {
#		$goal_config = $xBuild::config->{Goals}->{$goal};
#	}
#	# find goal to run
#	GOAL_SWITCH:
#	switch ($goal) {
#		case 'build' {
##########################################################################################################################################			if (0+@goals_build == 0) {
##########################################################################################################################################				xBuild::error ("No build goals to perform..\n");
##########################################################################################################################################				exit 1;
##########################################################################################################################################			}
##########################################################################################################################################			print " Build Goals: "; print join ", ", @goals_build; print "\n";
##########################################################################################################################################			for my $goal (@goals_build) {
##########################################################################################################################################				perform_goal ($goal);
##########################################################################################################################################			}
#			return;
#		}
#		case 'clean' {
#			goal_clean ($goal_config);
#		}
#		case 'composer' {
#			goal_composer ($goal_config);
#		}
#		case 'deploy' {
#			goal_deploy ($goal_config, 0);
#		}
#		case '[deploy]' {
#			goal_deploy ($goal_config, 1);
#		}
#		case 'gradle' {
#			goal_gradle ($goal_config);
#		}
#		case 'maven' {
#			goal_maven ($goal_config);
#		}
#		case 'prep' {
#			goal_prep ($goal_config);
#		}
#		case 'rpm' {
#			goal_rpm ($goal_config);
#		}
#		case 'version' {
#			goal_version ($goal_config);
#		}
#		else {
#			xBuild::error ("Unknown goal: $goal");
#		}
#	} # /GOAL_SWITCH
#	$last_goal = $goal;
#}



#small_title (" \nFINISHED!\n ");
#exit 0;



##################################################



# auto detect project version
#sub parse_version_from_files {
#	my @files = shift;
#	my $version = "";
#	if ( (0+@files) == 0 ) {
#		xBuild::error ("No version files specified in config file: ${xBuild::PROJECT_CONFIG_FILE}");
#		exit 1;
#	}
#	# check all files
#	my $isempty = 1;
#	FILES_LOOP:
#	for (@files) {
#		# get file name
#		my $file = $_;
#		if (!defined $file || length($file) == 0) {
#			next FILES_LOOP;
#		}
#		# get file extension
#		my ($ext) = $file =~ /(\.[^.]+)$/;
#		if (!defined $ext || length($ext) == 0) {
#			xBuild::error ("File has no extension: $file");
#			exit 1;
#		}
#		$isempty = 0;
#		my $vers = parse_version_file($file, $ext);
#		if (!defined $vers || length($vers) == 0) {
#			xBuild::error ("Failed to parse version number from file: $file");
#			exit 1;
#		}
#		# store version number
#		if (length($version) == 0) {
#			$version = $vers;
#		# verify version number
#		} else {
#			if ($version ne $vers) {
#				xBuild::error ("Version miss-match:  $version  !=  $vers  in  $file");
#				exit 1;
#			}
#		}
#	}
#	if ($isempty == 1) {
#		xBuild::error ("No version files found in config: ${xBuild::PROJECT_CONFIG_FILE}");
#		exit 1;
#	}
#	if (length($version) == 0) {
#		xBuild::error ("Failed to detect project version!");
#		exit 1;
#	}
#	return $version;
#}
#sub parse_version_file {
#	my $file = shift;
#	my $ext  = shift;
#	# .spec
#	if ($ext eq '.spec') {
#		return &parse_version_file_spec ($file);
#	}
#	# pom.xml
#	if ($file =~ /\/pom\.xml$/) {
#		return &parse_version_file_pom_xml ($file);
#	}
#	xBuild::error ("Unknown file type: $file");
#	exit 1;
#}



1;