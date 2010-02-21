#!/usr/bin/perl
# Reads URLs from stdin  and spits out HTTP methods to stdout
# Copyright (C) Vlatko Kosturjak, Kost. Distributed under GPL.

use strict;
use LW2;
use Data::Dumper;
use Getopt::Long;

my $showall=0;
my $showcodes=0;
my $showmethod=0;
my $verbose=0;
my $showdebug=0;
my $enumnonexistant=0;
my $enumoptions=0;
my $enumoptionstar=0;
my $enumeach=0;
my $tryall=0;
my $usehttp1=0;

my $uri;

# known HTTP methods
my @methods=('GET','HEAD','PUT','DELETE','POST','SEARCH','TRACE','OPTIONS','DELETE','CONNECT','PROPFIND','PROPPATCH','TRACK','DEBUG');
# http codes which says that specific method is allowed
my @httpcodes=('200','300','301','302','303','304');
my $nonexistantmethod="NONEXISTANT";

my $result = GetOptions (
	"a|all" => \$tryall,
	"o|optionstar" => \$enumoptionstar,
	"p|options" => \$enumoptions,
	"u|nonexistant" => \$enumnonexistant,
	"e|each" => \$enumeach,
	"s|show-all" => \$showall,
	"c|codes" => \$showcodes,
	"m|method" => \$showmethod,
	"1|http1" => \$usehttp1,
	"u|uri=s" => \$uri,
	"v|verbose"  => \$verbose,
	"d|debug" => \$showdebug,
	"h|help" => \&help
);

$verbose=99 if ($showdebug);

if ($tryall) {
	$enumnonexistant=1;
	$enumoptions=1;
	$enumoptionstar=1;
	$enumeach=1;
}

unless ($uri) {
	$uri="/";
}	

if ($enumnonexistant==0 or $enumoptions==0 or $enumoptionstar==0 or  $enumeach==0) {
	$enumeach=1;
}

my ($isssl,$ssllib,$sslver) = LW2::ssl_is_available();
my $havessl=$isssl;

if ($verbose>1) {
	if ($isssl) {
		print STDERR "SSL supported. Using $ssllib version $sslver\n";
		$havessl=1;
	} else {
		print STDERR "SSL not supported. Please install SSL support.\n";
	}
}

while (<STDIN>) {
chomp; 
my $url=trim($_);
next if ($url eq "");

my ($prot,$hostcrap,$port)=split(":",$url);
my ($left,$host)=split("\/\/",$hostcrap);
my $ssl=0;

if ($hostcrap eq "") {
	$host=$prot;
	$port=80;
	$prot="http";
} elsif ($port eq "") {
	if ($host eq "") { $port=$hostcrap; $host=$prot;}
	if ($port == 443) {
		$prot="https";
	} else {
		$prot="http";
	}
}

$prot="http" if (!$havessl);

print STDERR "$prot # $hostcrap # $port # $left # $host\n" if ($verbose>0);

if ($prot eq "http") {
	$port=80 if ($port eq "");
} elsif ($prot eq "https") {
	$port=443 if ($port eq "");
	$ssl=1;
} elsif ($prot eq "") {
	print STDERR "Empty protocol: $prot. Using defaults\n";
	$prot="http://";
	$port=80 if ($port eq "");
} else {
	print STDERR "Not common protocol: $prot. Using defaults\n";
	$prot="http://";
	$port=80 if ($port eq "");
}
print STDERR "Processing $prot:$host:$port\n" if ($verbose>0);

if ($enumoptions) {
	print "$prot://$host:$port;";
	print "OPTIONS $uri;" if ($showmethod);
	my %resp;
	my $req = LW2::http_new_request( host=>$host, uri=>$uri, port=> $port, protocol=> 'HTTP', ssl => $ssl, method=> "OPTIONS");
	${$req}{'whisker'}->{'version'}="1.0" if ($usehttp1);
	LW2::http_fixup_request(\%{$req});
	if (LW2::http_do_request(\%{$req},\%resp)) {
		print STDERR "$url OPTIONS: error: ".$resp{'whisker'}->{'error'}."\n";
	} else {
		my $respcode=$resp{'whisker'}->{'code'};
		print "($respcode) " if ($showcodes);
		print join(' ',split(",",$resp{'Allow'}));
		
	}
	print "\n";
}
if ($enumoptionstar) {
	print "$prot://$host:$port;";
	print "OPTIONS *;" if ($showmethod);
	my %resp2;
	my $req2 = LW2::http_new_request( host=>$host, uri=>'*', port=> $port, protocol=> 'HTTP', ssl => $ssl, method=> "OPTIONS");
	${$req2}{'whisker'}->{'version'}="1.0" if ($usehttp1);
	LW2::http_fixup_request(\%{$req2});
	if (LW2::http_do_request(\%{$req2},\%resp2)) {
		print STDERR "$url OPTIONS: error: ".$resp2{'whisker'}->{'error'}."\n";
	} else {
		my $respcode=$resp2{'whisker'}->{'code'};
		print "($respcode) " if ($showcodes);
		print join(' ',split(",",$resp2{'Allow'}));
		
	}
	print "\n";
}
if ($enumnonexistant) {
	print "$prot://$host:$port;";
	print "NONEXISTANT;" if ($showmethod);
	my %resp;
	my $req = LW2::http_new_request( host=>$host, uri=>$uri, port=> $port, protocol=> 'HTTP', ssl => $ssl, method=> $nonexistantmethod );
	${$req}{'whisker'}->{'version'}="1.0" if ($usehttp1);
	LW2::http_fixup_request(\%{$req});
	if (LW2::http_do_request(\%{$req},\%resp)) {
		print STDERR "$url $nonexistantmethod: error: ".$resp{'whisker'}->{'error'}."\n";
	} else {
		my $respcode=$resp{'whisker'}->{'code'};
		print "($respcode) " if ($showcodes);
		print join(' ',split(",",$resp{'Allow'}));
		
	}
	print "\n";
	
}
if ($enumeach) {
	print "$prot://$host:$port;";
	print "CHECKEACH;" if ($showmethod);
foreach my $method (@methods) {
	my %resp;
	my $req = LW2::http_new_request( host=>$host, uri=>$uri, port=> $port, protocol=> 'HTTP', ssl => $ssl, method=> $method );
	${$req}{'whisker'}->{'version'}="1.0" if ($usehttp1);
	LW2::http_fixup_request(\%{$req});
	print STDERR Dumper($req) if ($verbose>10);
	if (LW2::http_do_request(\%{$req},\%resp)) {
		print STDERR "$url $method: error: ".$resp{'whisker'}->{'error'}."\n";
	} else {
		my $respcode=$resp{'whisker'}->{'code'};
		my $codeok=0;
		foreach my $code (@httpcodes) { $codeok=1 if ($code==$respcode) }
		if ($showall or $codeok) {
			if ($showcodes) {
				print "$method($resp{'whisker'}->{'code'}) ";
			} else {
				print "$method ";
			}
		}
		print STDERR Dumper(%resp) if ($verbose>10);
	}
} # foreach
} # if ($enumeach)
print "\n";
} # while (<>)

sub trim($)
{
        my $string = shift;
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
        return $string;
}

sub help 
{
	print "$0: Reads URLs from stdin and displays HTTP methods supported\n";
	print "Copyright (C) Vlatko Kosturjak, Kost. Distributed under GPL.\n\n";
	print "Usage: $0 -c < urls.txt\n\n";
	print "Where URLs can be in form of http://url, server.domain:port or server.domain\n\n";
	print "	-a	try all known tricks to identify HTTP methods\n";
	print "	-o	trick: try with OPTIONS *\n";
	print "	-p	trick: try with OPTIONS /\n";
	print "	-u	trick: try with unknown HTTP method ($nonexistantmethod)\n";
	print "	-e	trick: try each known HTTP method\n";
	print "	-c	show HTTP response code returned\n";
	print "	-s	show all HTTP methods in each trick (useful with -c and -e)\n";
	print "	-m	show trick tried in output\n";
	print "	-1	use HTTP/1.0\n";
	print "	-u	use URL as argument (default: $uri)\n";
	print "	-v	verbose\n";
	print "	-d 	be even more verbose (for debugging!)\n";
	print "	-h 	this help message\n";
	exit (0);
} 
