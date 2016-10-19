#!/usr/bin/perl
#
# Copyright 2016 Mike Baranski (mike.baranski@gmail.com)
# 
# Please see LICENSE file for license information
#
# DO NOT CHANGE THIS FILE - See README.md for usage informatino
# and img-export.conf for configuration options.
# 
# Edit the configuration in img-export.conf
#

no strict 'refs';

print "\n\nStarting image resize script, reading configuration\n\n";

$config = "img-export.conf";
open(CONFIG, $config) or die ("Cannot open config file: $config");
while (<CONFIG>) {
    chomp;                  # no newline
    s/#.*//;                # no comments
    s/^\s+//;               # no leading white
    s/\s+$//;               # no trailing white
    next unless length;     # anything left?
    my ($var, $value) = split(/\s*=\s*/, $_, 2);
    $$var = $value;
    print "$var set to $value\n";
}

print "\n\n";
print "Configuration read, processing\n\n";

### DO NOT MODIFY THE CODE BELOW THIS LINE ###
open(FH, "selectout '$sqlStatement' 2>/dev/null|") or die("SQL query falied");
while(<FH>){
    my ($pid, $size, $fname, $lname) = split /\|/;
    $filenameStart = "$fname.$lname.$pid";
    
    if($size < $sizeCutoff){
	print ("Skipping image size is $size\n");
        next; # Skipping size < the cutoff
    }

    print "$pid size is $size, processing\n" if $debugOn;
    my $cmd = "/cas/bin/eirs -x -p $pid -o $tmpdir/$filenameStart.jpg >/dev/null 2>&1";
    system($cmd);

    if($? != 256){
        print ("Command returned invalid result ($?): [$cmd]\n");
        next; # Something didn't work with EIRS
    }

    my $fn = "$tmpdir/$filenameStart.00.jpg"; # Fix filename, EIRS adds .00.jpg for some reason
    
    if(! -f $fn){
        print "File not exported properly\n";
        next; # Cannot find the file
    }

    my $newFile = "$tmpdir/$filenameStart-resized.jpg";
    $cmd = "convert -resize $newMax $fn $newFile";
    print $cmd . "\n" if $debugOn;
    `$cmd`;

    if($? != 0){
	print "There was an error with the command: [$cmd]\n";
	next;
    }
    
    print "Converted $fn to $newFile for person.id = $pid\n" if $debugOn;

    if(! $resizeOnly){
	my $eirsCmd = "/cas/bin/eirs -f -a -p $pid -i $newFile >/dev/null 2>&1";
	`$eirsCmd`;
	if($? != 0){
	    print "Insert failed image with: $eirsCmd\nResult was $?\n";
	    next;
	}
	print "Image updated in database\n";
    }
}

close FH;
