#!/usr/bin/perl
# finddupso.pl: Find duplicated shared libraries(.so) and suggest removing files
# SPDX-License-Identifider: GPL-2.0-only
# Copyright(C) Hiroshi Takekawa
#
# If you use some well-controlled distribution, you don't need this.
# If you build some packages by yourself, you might need this.
#
# This script finds duplicated shared libraries and generate removing
# command lines, then you could copy and paste it to actually remove them.
#  'Duplicated shared libraries' means:
#    The same named libraries have different major versions.  Those won't be suggested to remove for safety.  Information printed.
#    The same named libraries have different minor versions.  Those which are older wlll be suggested to remove.
#    The same named libraries resides in the different directories.  Those which resides in 'local' directories wlll be suggested to remove.

my @dirs_32 = qw#/lib /usr/lib /usr/lib32 /usr/local/lib /usr/X11R7.devel.ia32/lib#;
my @dirs_64 = qw#/lib64 /usr/lib64 /usr/local/lib64 /usr/X11R6/lib64#;

sub find_dup_so (@) {
    my %fullpaths;
    my %majorvers;
    my %minorvers;
    my %mtimes;
    my @majordiffs;
    my @oldlibs;
    my @lamelibs;
    my @duplibs;
    my @dirs = @_;

    print "### Starting: ", join(' ', @dirs), "\n";
    foreach $dir (@dirs) {
	#print "# Directory: ", $dir, "\n";
	opendir DIR, $dir or die "# Error: Cannot open directory $dir: $!\n";
	while ($_ = readdir DIR) {
	    next if /^\.\.?$/o;
	    next unless /^(.*)\.so\.(.*)$/o;
	    my $fullpath = join('/', $dir, $_);
	    next if -l $fullpath;
	    my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
		$atime, $mtime, $ctime, $blksize, $blocks) = stat($fullpath);
	    my $libname = $1;
	    my $ver = $2;
	    my ($major, $minor, $release) = split /\./, $ver, 3;#/
	    if (defined($fullpaths{$libname})) {
		if ($majorvers{$libname} != $major) {
		    push @majordiffs, "# Major version diffs: $fullpaths{$libname} <=> $fullpath\n";
		} elsif ($minorvers{$libname} != $minor) {
		    my ($newer_path, $older_path, $newer_mtime, $older_mtime);
		    if ($minorvers{$libname} > $minor) {
			$newer_path = $fullpaths{$libname}; $newer_mtime = $mtimes{$libname};
			$older_path = $fullpath; $older_mtime = $mtime;
		    } else {
			$newer_path = $fullpath; $newer_mtime = $mtime;
			$older_path = $fullpaths{$libname}; $older_mtime = $mtimes{$libname};
		    }
		    if ($newer_mtime < $older_mtime) {
			print "# Minor version diff(LAME): $older_path <=> $newer_path\n";
			push @lamelibs, $newer_path;
		    } else {
			print "# Minor version diff: $newer_path <=> $older_path\n";
			push @oldlibs, $older_path;
		    }
		} elsif ($releasevers{$libname} != $release) {
		    my ($newer_path, $older_path, $newer_mtime, $older_mtime);
		    if ($releasevers{$libname} > $release) {
			$newer_path = $fullpaths{$libname}; $newer_mtime = $mtimes{$libname};
			$older_path = $fullpath; $older_mtime = $mtime;
		    } else {
			$newer_path = $fullpath; $newer_mtime = $mtime;
			$older_path = $fullpaths{$libname}; $older_mtime = $mtimes{$libname};
		    }
		    print "# Release diffs for $libname: $newer_path <=> $older_path\n";
		    if ($newer_mtime < $older_mtime) {
			print "## WARNING: $newer_path has older mtime\n";
			push @lamelibs, $newer_path;
		    } else {
			push @oldlibs, $older_path;
		    }
		} else {
		    if ($mtimes{$libname} < $mtime) {
			print "# Duplication: $fullpath == $fullpaths{$libname}\n";
			if ($fullpath =~ /local/) {
			    push @duplibs, $fullpath;
			} else {
			    push @duplibs, $fullpaths{$libname};
			}
		    } else {
			print "# Duplication: $fullpaths{$libname} == $fullpath\n";
		    }
		}
	    } else {
		$fullpaths{$libname} = $fullpath;
		$majorvers{$libname} = $major;
		$minorvers{$libname} = $minor;
		$releasevers{$libname} = $release;
		$mtimes{$libname} = $mtime;
	    }
	}
	closedir DIR;
    }
    print "\n";
    print sort @majordiffs;
    print "\n";
    print map "rm " . $_ . "\n", @oldlibs;
    if (scalar(@duplibs) > 0) {
	print "#\n# duplicated libraries. You could remove these\n#\n";
	print map "rm " . $_ . "\n", @duplibs;
    }
    if (scalar(@lamelibs) > 0) {
	print "#\n# older mtime libs with newer version\n#\n";
	print map "rm " . $_ . "\n", @lamelibs;
    }
}

find_dup_so @dirs_32;
find_dup_so @dirs_64;
