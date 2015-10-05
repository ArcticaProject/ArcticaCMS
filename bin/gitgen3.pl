#!/usr/bin/perl -T

# Copyright (C) 2015 by gznget <opensource@gznianguan.com>
# Copyright (C) 2015 by Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.

# yes yes... ITS FKING UGLY! But it works... (or so we do hope)
use strict;
use Data::Dumper;
use File::Copy;

my $GitURL		= "https://github.com/ArcticaProject/WebSites.WWW";
my $GitHOME		= "/var/lib/arctica-www/arctica-project.org/pagedata/git/WebSites.WWW";
my $GITMarkdownDir	= "content/markdown";
my $MHTMLRootDir 	= "/var/lib/arctica-www/arctica-project.org/pagedata/autogen/gitmd/mhtml";
my $GitBIN  		= "/usr/bin/git";
my $MarkDownPY		= "/usr/bin/markdown_py";
my $tmpDir 		= "/tmp";
my $menuGenScript	= "/var/lib/arctica-www/arctica-project.org/bin/themenugen.pl";

$ENV{'PATH'} = "/bin:/usr/bin";
if (-f "$tmpDir/aweb_gitget.lock") {die("Either something fucked up! (or an old instance may still be working on something...)");}
open(LOCK,">/tmp/aweb_gitget.lock");print LOCK "$$\n",time(),"\n";close(LOCK);
unless (-f "$tmpDir/aweb_gitget.lock") {die("Lock file creation FAILED!");}

if (-d $GitHOME) {
	my $FromID = 0;
	my $ToID = 0;
	my $ActionsCnt = 0;
	my %Changes;
	chdir($GitHOME);
#	system("$GitBIN pull");
	open(GITPULL,"$GitBIN pull $GitURL 2>&1|");
	my @GitPULLOutput = <GITPULL>;
	close(GITPULL);
	if ((@GitPULLOutput[0] =~ /Already up-to-date/) or (@GitPULLOutput[2] =~ /Already up-to-date/)) {
		print "Nothing TODO!\n";
	} else {
		print "Changes to work on!\n";
	}
#print Dumper(@GitPULLOutput),"\n";
	foreach my $line (@GitPULLOutput) {
		$line =~ s/\n//g;
		if ($line =~ /Updating ([a-f0-9]*)\.\.([a-f0-9]*)/) {
			$FromID	= $1;
			$ToID	= $2;
			last;
		}
	}
	if (($FromID ne 0) and ($ToID ne 0)) {
		open(GITDIFF,"$GitBIN diff --name-status $FromID..$ToID|");
		my @GitDIFFS = <GITDIFF>; 
		close(GITDIFF);
		foreach my $changeLine (@GitDIFFS) {
			if ($changeLine	=~ /^([AMD])\s*$GITMarkdownDir\/([a-zA-Z0-9\-\/]*\.md)/) {
				my $CType = $1;
				my $CFile = $2;
				if ($CType eq "M") {
					push @{$Changes{'A'}}, $CFile;
				} else {
					push @{$Changes{$CType}}, $CFile;
				}
				$ActionsCnt++;
			}
		}
	}
	if ($ActionsCnt > 0) {
		if ($Changes{'D'}) {
			foreach my $rmFile (@{$Changes{'D'}}) {
				unless(-f "$GitHOME/$GITMarkdownDir/$rmFile") {
					my $mhtmlName = $rmFile;
					$mhtmlName =~ s/^\///g;
					if ($mhtmlName =~ /^([a-z0-9\-\/]*)\.md$/) {
						$mhtmlName = $1;
						$mhtmlName =~ s/\//\_/g;
						my $fullFinalRMPath = "$MHTMLRootDir/$mhtmlName.mhtml";
						if (-f $fullFinalRMPath) {
							unlink($fullFinalRMPath);
							unless (-f $fullFinalRMPath) {
								print "************* File deleted! ($fullFinalRMPath)\n";
							}
						}
					}
				}
			}
		} 

		if ($Changes{'A'}) {
			print "CHANGES:",Dumper($Changes{'A'}),"\n";
			foreach my $newFile (@{$Changes{'A'}}) {
				if (-f "$GitHOME/$GITMarkdownDir/$newFile") {
					print "NEWFILE:	$newFile	($GitHOME/$GITMarkdownDir/$newFile)\n";
					my $mhtmlName = $newFile;
					$mhtmlName =~ s/^\///g;
					if ($mhtmlName =~ /^([a-z0-9\-\/]*)\.md$/) {
						$mhtmlName = $1;
						$mhtmlName =~ s/\//\_/g;
						my $fullFinalDestPath = "$MHTMLRootDir/$mhtmlName.mhtml";
						print "Creating:	$fullFinalDestPath\n";
						my $tmpMDFile = preProcessMD("$GitHOME/$GITMarkdownDir/$newFile",$tmpDir);
						print "TMP_MD:	$tmpMDFile\n";
						my $tmpMHTMLFile = convertMDtoMHTML($tmpMDFile,$tmpDir);
						print "TMHTML:	$tmpMHTMLFile\n";
						postProcessMHTML($tmpMHTMLFile,$fullFinalDestPath,$tmpDir);
						if (-f $tmpMDFile) {
							unlink($tmpMDFile);
						}
						if (-f $tmpMHTMLFile) {
							unlink($tmpMHTMLFile);
						}
#						unlink($tmpMDFile);unlink($tmpMHTMLFile);
					} else {
						print "Problem with file path!";
					}
				}
			}
		}
	}
}
system($menuGenScript);
#markdown_py --x footnotes -o html4 
unlink("$tmpDir/aweb_gitget.lock");
sub preProcessMD {
	my $mdInFile = $_[0];
	my $tmpDir = $_[1];
	if ((-d $tmpDir) and (-f $mdInFile)) {
		my $tmpFile = genTmpFileName();
		copy($mdInFile,"$tmpDir/$tmpFile.md");
		return "$tmpDir/$tmpFile.md";
	} else {
		return 0;
	}
} 

sub convertMDtoMHTML {
	my $mdInFile = $_[0];
	my $tmpDir = $_[1];
#	print "INCONVERT 1\n";
	if ((-f $mdInFile) and (-d $tmpDir)) {
#	print "INCONVERT 2\n";
		my %tags = getAndStripMDTags($mdInFile);
		if (%tags) {print Dumper(%tags),"\n";}
#		my $tmpMHTMLFile0 = genTmpFileName();
		my $tmpMHTMLFile1 = genTmpFileName();
		my $tmpMHTMLFile2 = genTmpFileName();
		system($MarkDownPY,'-q','-x','footnotes','-o','html4','-f',"$tmpDir/$tmpMHTMLFile1.html",$mdInFile);
		if (-f "$tmpDir/$tmpMHTMLFile1.html") {
#	print "INCONVERT 3\n";
			open(THTML,"$tmpDir/$tmpMHTMLFile1.html");
			my @HTML = <THTML>;
			close(THTML);
			unlink($tmpMHTMLFile1);
			open(MHTML,">$tmpDir/$tmpMHTMLFile2.mhtml");
			print MHTML "$tags{'pub'}\n$tags{'title'}\n$tags{'description'}\n$tags{'tags'}\n$tags{'date'}\n$tags{'link'}\n$tags{'slug'}\n\n\n\n";
			print MHTML @HTML;
			close(MHTML);
			if (-f "$tmpDir/$tmpMHTMLFile2.mhtml") {
				return "$tmpDir/$tmpMHTMLFile2.mhtml";
			} else {return 0;}
		} else {return 0;}
	} else {return 0;}
}

sub postProcessMHTML {
	my $mhtmlInFile = $_[0];
	my $mhtmlDestFile = $_[1];
	my $tmpDir = $_[2];
	if ((-d $tmpDir) and (-f $mhtmlInFile)) {
		move($mhtmlInFile,$mhtmlDestFile);
		return 1;
	} else {
		return 0;
	}
}

sub getAndStripMDTags {
	my %Tags;
	my $mdFile = $_[0];
	if (-f $mdFile) {
		my @strippedMD;
		open(OMD,$mdFile);
		my $lcnt = 1;
		while (<OMD>) {
			my $line = $_;
			if ($lcnt < 11) {
				if ($line =~ /^\s*\.\.\s*[a-zA-Z0-9]*:.*/) {
					$line =~ s/\n//g;
					$line =~ s/\s*$//g;
					if ($_ =~ /^\.\. pub:\s*(\d)$/) {
						if ($1 eq 1) {
							$Tags{'pub'} = 1;
						} else {
							$Tags{'pub'} = 0;
						}
					} elsif ($_ =~ /^\.\. title:\s*(.*)$/) {
						my $tagdata = $1;
						if (length($tagdata) > 0) {
							$Tags{'title'} = $tagdata;
						}
					} elsif ($_ =~ /^\.\. description:\s*(.*)$/) {
						my $tagdata = $1;
						if (length($tagdata) > 0) {
							$Tags{'description'} = $tagdata;
						}
					} elsif ($_ =~ /^\.\. link:\s*(.*)$/) {
						my $tagdata = $1;
						if (length($tagdata) > 0) {
							$Tags{'link'} = $tagdata;
						}
					} elsif ($_ =~ /^\.\. tags:\s*(.*)$/) {
						my $tagdata = $1;
						if (length($tagdata) > 0) {
							$Tags{'tags'} = $tagdata;
						}
					} elsif ($_ =~ /^\.\. date:\s*(.*)$/) {
						my $tagdata = $1;
						if (length($tagdata) > 0) {
							$Tags{'date'} = $tagdata;
						}
					} elsif ($_ =~ /^\.\. slug:\s*(.*)$/) {
						my $tagdata = $1;
						if (length($tagdata) > 0) {
							$Tags{'slug'} = $tagdata;
						}
					}
				} else {
					push @strippedMD, $line;
				}
#			print $_ ;
			}else {
				push @strippedMD, $line;
			}
			$lcnt++;
		}
		close(OMD);
		open(SMD,">$mdFile");
		print SMD @strippedMD;
		close(SMD);
		if (%Tags) {
			return(%Tags);
		} 
	}
}


sub genTmpFileName {
	srand(); 
	my $time = time();
	my $rcnt = (32 - length($time));  
	my @chars = ('0'..'9','a'..'z','A'..'Z');
	my $randmake;
	for (my $i=0; $i<$rcnt; $i++) {$randmake .= $chars[int(rand($#chars + 1))];}
	return "$time$randmake";
}


