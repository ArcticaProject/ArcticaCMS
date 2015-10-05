#!/usr/bin/perl -T 
use strict;
#print "\n\n\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n";
use HTML::Entities;
use Encode qw(decode);
use Data::Dumper;
use JSON;
use File::Copy;

my $GitHOME		= "/var/lib/arctica-www/arctica-project.org/pagedata/git/WebSites.WWW";
my $GITMarkdownDir	= "content/markdown";
my $MHTMLRootDir 	= "/var/lib/arctica-www/arctica-project.org/pagedata/autogen/gitmd/mhtml";
my $MenuRootDir 	= "/var/lib/arctica-www/arctica-project.org/pagedata/autogen/gitmd/menutree";

opendir(DIR, "$GitHOME/$GITMarkdownDir") or die $!;
my @DirContent = readdir(DIR);
closedir(DIR);

foreach my $entry (@DirContent) {
	$entry =~ s/[\s\n]//g;
	if (lc($entry) =~ /^([a-z0-9\-]{2,})$/) {
		my $cleanEntry = $1;
		print "entry:  $cleanEntry\n";
		my $theStartDir = "$GitHOME/$GITMarkdownDir/$cleanEntry";
		if (-f "$theStartDir/.dirconf") {	# make this check if menu is requested... for now we generate regardless... 
							# we actually use the json file even if menu is not requested...  so make menujson regardles.
			print "Generating menu for: $cleanEntry...\n";
			my (undef,$title,$description) = fetchPageINFO("$GitHOME/$GITMarkdownDir",$cleanEntry);
#			print "Title:	$title\nDescr:	$description\n";
			my %JSONIT;
			my %MenuTree = theDirPharser("$GitHOME/$GITMarkdownDir",$cleanEntry);
			$JSONIT{'config'}{'PLACEHOLDER'} = 1;
			$JSONIT{'title'} = $title;
			$JSONIT{'description'} = $description;
			$JSONIT{'menutree'} = \%MenuTree;
#			print Dumper(%MenuTree),"\n";
			open(JSON,">$MenuRootDir/$cleanEntry.tmpson");
			print JSON encode_json(\%JSONIT),"\n";
			close(JSON);
			move("$MenuRootDir/$cleanEntry.tmpson","$MenuRootDir/$cleanEntry.json");
		}
	}
}




#open(PDATA,">$GProdsDir/$ProductREF.prd/data.json");
#print PDATA encode_json(\%pInfo);
#close(PDATA);


#print "=================================================\n",Dumper(%JSONIT),"\n=================================================\n";


sub theDirPharser {
	my %theResultingHash;
	my $mainRHCnt = 0;
	my $theRootDIR = $_[0]; 
	my $theNewDir = $_[1];
	my $theDIR = "$theRootDIR/$theNewDir";

	$theDIR =~ s/\/*$//g;
	$theDIR =~ s/\/\//\//g;
#	print "theDir: $theDIR\n";
	if (-d $theDIR) {
		my %lOrder;
		if (-f "$theDIR/listorder") {
#			print "FOUND LIST ORDER FILE!\n";
			my $locnt;
			open(LORDER,"$theDIR/listorder");
			while (<LORDER>) {
				my $line = lc($_);
				$line=~ s/[^a-z0-9]//g;
				if ($line) {
					$lOrder{'cnt'}{'locnt'}++;
					$lOrder{'ordered'}{$lOrder{'cnt'}{'locnt'}} = $line;
#					print "LISTORDER:$line\n";
				}
			}
			close(LORDER);
		}

		my @Dir;
		my @Page;
		opendir(DIR, $theDIR) or die $!;
		my @DirContent = readdir(DIR);
		closedir(DIR);

		foreach my $content (sort @DirContent) {
#			print "UNCLEAN: $content\n";
			$content =~ s/\.md$//g;
			$content =~ s/[^a-z0-9\-]//g;

#			print "CLEAN..: $content\n";
			if ($content =~ /^([a-z0-9\-]{1,})$/) {
				$content = "$1";
#				print "CONTENT: $content\n";
				if	(-f "$theDIR/$content.md") {
#					print "FILE: $content\n";
#					print "IS FILE!\n";
					my ($isPub,$title,$description,undef) = fetchPageINFO($theDIR,$content);
					if ($isPub eq 1) {
#						print "IS PUBLIC! ($title)\n";
						$lOrder{'cnt'}{'pgcnt'}++;
						$lOrder{'pages'}{$content}{'cntn'} = $lOrder{'cnt'}{'pgcnt'};
						$lOrder{'pages'}{$content}{'title'} = $title;
						$lOrder{'pages'}{$content}{'description'} = $description;
					}
				} elsif (-d "$theDIR/$content") {
#					print "DIR: $content\n";
#					print "IS DIR!\n";
					my ($isPub,$title,$description,$diricon) = fetchPageINFO($theDIR,$content);
					if ($isPub eq 1) {
#						print "IS PUBLIC! ($title)\n";
						$lOrder{'cnt'}{'dircnt'}++;
						$lOrder{'dir'}{$content}{'cntn'} = $lOrder{'cnt'}{'dircnt'};
						$lOrder{'dir'}{$content}{'title'} = $title;
						$lOrder{'dir'}{$content}{'description'} = $description;
						$lOrder{'dir'}{$content}{'dicon'} = $diricon;
					}
				}
#				print "------------------------------------------------\n";
			}
		}

		if ($lOrder{'ordered'}) {
#			print "Start generating LIST:\n";
			foreach my $key (sort keys $lOrder{'ordered'}) {
				if ($lOrder{'pages'}{$lOrder{'ordered'}{$key}}) {
					$mainRHCnt++;
					$theResultingHash{$mainRHCnt}{'type'} = "p";
					$theResultingHash{$mainRHCnt}{'name'} = $lOrder{'ordered'}{$key};
					$theResultingHash{$mainRHCnt}{'title'} = $lOrder{'pages'}{$lOrder{'ordered'}{$key}}{'title'};
					$theResultingHash{$mainRHCnt}{'description'} = $lOrder{'pages'}{$lOrder{'ordered'}{$key}}{'description'};
					$lOrder{'done'} = $lOrder{'ordered'}{$key};
				} elsif ($lOrder{'dir'}{$lOrder{'ordered'}{$key}}) {
					$mainRHCnt++;
					my %gotHash = theDirPharser($theDIR,$lOrder{'ordered'}{$key});
					$theResultingHash{$mainRHCnt}{'type'} = "d";
					$theResultingHash{$mainRHCnt}{'name'} = $lOrder{'ordered'}{$key};
					$theResultingHash{$mainRHCnt}{'title'} = $lOrder{'dir'}{$lOrder{'ordered'}{$key}}{'title'};
					$theResultingHash{$mainRHCnt}{'description'} = $lOrder{'dir'}{$lOrder{'ordered'}{$key}}{'description'};
					$theResultingHash{$mainRHCnt}{'dicon'} = $lOrder{'dir'}{$lOrder{'ordered'}{$key}}{'dicon'};
					$theResultingHash{$mainRHCnt}{'sub'} = \%gotHash;

					$lOrder{'done'}{$lOrder{'ordered'}{$key}} = 1;
				} 

#				print "$key $lOrder{'ordered'}{$key}\n";
			}
		}

		if ($lOrder{'pages'}) {
			foreach my $name (sort keys $lOrder{'pages'}) {
				unless (($lOrder{'done'}{$name}) or ($name eq "index")) {
					$mainRHCnt++;
					$theResultingHash{$mainRHCnt}{'type'} = "p";
					$theResultingHash{$mainRHCnt}{'name'} = $name;
					$theResultingHash{$mainRHCnt}{'title'} = $lOrder{'pages'}{$name}{'title'};
					$theResultingHash{$mainRHCnt}{'description'} = $lOrder{'pages'}{$name}{'description'};
					$lOrder{'done'}{$name} = 1;
				}
			}
		}

		if ($lOrder{'dir'}) {
			foreach my $name (sort keys $lOrder{'dir'}) {
				unless ($lOrder{'done'}{$name}) {
					$mainRHCnt++;
					my %gotHash = theDirPharser($theDIR,$name);
					$theResultingHash{$mainRHCnt}{'type'} = "d";
					$theResultingHash{$mainRHCnt}{'name'} = $name;
					$theResultingHash{$mainRHCnt}{'title'} = $lOrder{'dir'}{$name}{'title'};
					$theResultingHash{$mainRHCnt}{'description'} = $lOrder{'dir'}{$name}{'description'};
					$theResultingHash{$mainRHCnt}{'dicon'} = $lOrder{'dir'}{$name}{'dicon'};
					$theResultingHash{$mainRHCnt}{'sub'} = \%gotHash;
					$lOrder{'done'}{$name} = 1;
				}
			}
		}
#		print "=================================================\n",Dumper(%theResultingHash),"\n=================================================\n";
#		print "=================================================\n",Dumper(%lOrder),"\n=================================================\n";
		return %theResultingHash;
	}
}

sub fetchPageINFO {
	my $baseDir = $_[0];
	my $pageName = lc($_[1]);
#	print "PNAME1: $pageName\n";
	$pageName =~ s/[^a-z0-9]//g;
#	print "PNAME2: $pageName\n";
	if (-d $baseDir) {
		if (-f "$baseDir/$pageName.md") {
			my %tags = getMDTags("$baseDir/$pageName.md");
			my $pub = $tags{'pub'};
			my $title = $tags{'title'};
			my $description = $tags{'description'};
			$pub	=~ s/\D//g;if ($pub eq 1) {$pub = 1;} else {$pub = 0;}
			$title =~ s/\s*\n$//g;	$title =~ s/^\s*//g;	$description =~ s/^\s*//g;	$description =~ s/\s*\n$//g;
			return ($pub,encode_entities(decode('UTF-8',$title)),encode_entities(decode('UTF-8',$description)),0);
		} elsif (-d "$baseDir/$pageName") {
			my $dirIcon = 0;
			if (-f "$baseDir/$pageName/icon.png") {
				$dirIcon = 1;
			}
			if (-f "$baseDir/$pageName/index.md") {
				my %tags = getMDTags("$baseDir/$pageName/index.md");
				my $pub = $tags{'pub'};
				my $title = $tags{'title'};
				my $description = $tags{'description'};
				$pub	=~ s/\D//g;if ($pub eq 1) {$pub = 1;} else {$pub = 0;}
				$title =~ s/\s*\n$//g;	$title =~ s/^\s*//g;	$description =~ s/^\s*//g;	$description =~ s/\s*\n$//g;
				return ($pub,encode_entities(decode('UTF-8',$title)),encode_entities(decode('UTF-8',$description)),$dirIcon);
			} elsif (-f "$baseDir/$pageName/info") {
				open(INFO,"$baseDir/$pageName/info");
				my ($pub,$title,$description,undef) = <INFO>;
				close(INFO);
				$pub	=~ s/\D//g;if ($pub eq 1) {$pub = 1;} else {$pub = 0;}
				$title =~ s/\s*\n$//g;	$title =~ s/^\s*//g;	$description =~ s/^\s*//g;	$description =~ s/\s*\n$//g;
				return ($pub,encode_entities(decode('UTF-8',$title)),encode_entities(decode('UTF-8',$description)),$dirIcon);
			} else {
				return 0;
			}
		} else {
			return 0;
		}
	} else {
		return 0;
	}
}


sub getMDTags {
	my %Tags;
	my $mdFile = $_[0];
	if (-f $mdFile) {
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
				} 
			} 
			$lcnt++;
		}
		close(OMD);
		if (%Tags) {
			return(%Tags);
		} 
	}
}



