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

# SAVE AS ISO-8859-15
use CGI::Carp qw(fatalsToBrowser);
use strict;
use JSON;
use Data::Dumper;
my %AWS;
$AWS{'LocalPATH'} = "/var/lib/arctica-www/arctica-project.org";
$AWS{'PageDataPATH'} = "$AWS{'LocalPATH'}/pagedata";
$AWS{'WEBPATH'} = "";
$AWS{'LOGOHTMLSTRING'} = "<span class=\"theLogoTextSMALL\"><sup>The </sup><b class=\"theLogoTextBIG\">Arctica</b><sub> Project</sub></span>";

if ($ENV{'QUERY_STRING'}) {
	my ($tmp_QS1,$tmp_QS2,$tmp_QS3) = split(/\:/,lc($ENV{'QUERY_STRING'}));
#	print "\n\n\n$ENV{'QUERY_STRING'}\n\n$tmp_QS1\n$tmp_QS2\n$tmp_QS3\n\n";
	if ($tmp_QS1 =~ /^([a-z0-9]*)$/) {
		$AWS{'qsPageType'} = $1;
#		print "<h1>$AWS{'qsPageType'}</h1>";
		if ($AWS{'qsPageType'} eq "mk") {$AWS{'qsPageType'} = "md";}
	}
	
	if ($AWS{'qsPageType'} eq "landing") {
		$AWS{'qsPageRef'} = "start";
		$AWS{'qsPageACTIVE'} = "landing:start";
	} else {
		if ($tmp_QS2 =~ /^([a-z0-9\/]*)$/) {
			$AWS{'qsPageRef'} = $1;
			if ($AWS{'qsPageRef'} =~ /^([[a-z0-9]*)\/.*$/) {
				$AWS{'qsPageACTIVE'} = "$AWS{'qsPageType'}:$1";
			} elsif ($AWS{'qsPageRef'} =~ /^([[a-z0-9]*)$/) {
				$AWS{'qsPageACTIVE'} = "$AWS{'qsPageType'}:$1";
			} else {
				$AWS{'qsPageACTIVE'} = "0:0";
			}
		}
	}
	$AWS{'qsPageREST'} = $tmp_QS3;# NOT CLEAN! (Should we clean here or later?)
	 
} else {
	$AWS{'qsPageType'} = "landing";
	$AWS{'qsPageRef'} = "start";
	$AWS{'qsPageACTIVE'} = "landing:start";
}
print "Content-type: text/html\n\n";
genHeader($AWS{'qsPageType'});
genTopBAR();
#print "$ENV{'QUERY_STRING'}<br>\nPT: $AWS{'qsPageType'}\nPR: $AWS{'qsPageRef'}\nPL: $AWS{'qsPageREST'}\n\n";
if (1 eq 2) {
} elsif ($AWS{'qsPageType'} eq "md") {
#print "<!-- MOTHERFUCKER START -->";
	fetchMarkDownHTML($AWS{'qsPageRef'});
#print "<!-- MOTHERFUCKER END -->";
} elsif ($AWS{'qsPageType'} eq "landing") {
	genTopLandingBanner($AWS{'qsPageRef'});
}

genFooter();

sub fetchMarkDownHTML {
	my $pageRef = lc($_[0]);
	my $BaseMHTMLPATH = "$AWS{'PageDataPATH'}/autogen/gitmd/mhtml";
	my $BaseMenuTreePATH = "$AWS{'PageDataPATH'}/autogen/gitmd/menutree";
	my $BaseGitContentPATH = "$AWS{'PageDataPATH'}/git/WebSites.WWW/content/markdown";
	my $buildNavLine;
	my %dirConf;
	my $PageHTML;
	my $MenuHTML;
	my $firstTitle;
	my $firstDescription;
	my $ItsA404 = 0;
	print "<DIV class=\"main_markdownarea-outerDIV\"><DIV class=\"main_markdownarea-innerDIV\">";
	$pageRef =~ s/[^a-z0-9\-\/]//g;
	if ($pageRef =~ /^([a-z0-9\-\/]*)$/) {
		$pageRef = $1;
		$pageRef =~ s/^\///g;
		$pageRef =~ s/\/$//g;
	} else {
		$pageRef = undef;
	} 
	my $FirstLevelName;
	if ($pageRef =~ /^([a-z0-9\-]*).*/) {
		my $FirstLevel = $1;
		if (-d "$BaseGitContentPATH/$FirstLevel") {
			$FirstLevelName = $FirstLevel;
		}
	}
	
	if ($FirstLevelName) {
#######		print "<h1>$FirstLevelName</h1>";
		if (-f "$BaseGitContentPATH/$FirstLevelName/.dirconf") {
#			print "<h1>JSON:$BaseMenuTreePATH/$FirstLevelName.json:JSON</h1>";
			open(MCNF,"$BaseGitContentPATH/$FirstLevelName/.dirconf");
			while (<MCNF>) {
				my $cnfline = $_;
				$cnfline =~ s/[\ \n]//g;
				if ($cnfline =~ /^([a-z0-9]*)\=([a-z0-9]*)$/) {
					$dirConf{$1} = $2;
				}
			}
			close(MCNF);
		}

		my $menuData;

		if (-f "$BaseMenuTreePATH/$FirstLevelName.json") {
#			print "<h1>JSON:$BaseMenuTreePATH/$FirstLevelName.json:JSON</h1>";
			open(MENU,"$BaseMenuTreePATH/$FirstLevelName.json");
			my $fromjson  = decode_json(<MENU>);
			close(MENU);
			$firstTitle = $fromjson->{'title'};
			$firstDescription = $fromjson->{'description'};
			$menuData = $fromjson->{'menutree'};
			$MenuHTML = makeMenuList($menuData,"/md/$FirstLevelName");
		}
#			print Dumper($menuData),"\n<br>\n";

		#########################
		# Check and build path
		# Use the menu data we already got instead of doing a fuckload of additional file reads from disk.
		my $buildPath;
		my $checkData = $menuData;
		my $isValidSite = 1;

		if ($pageRef eq $FirstLevelName) {
#######			print "FIRSTLEVELPAGE!!!";
		} elsif ($pageRef =~ /^standalone\/([a-z0-9\-]*)$/) {
			$buildPath = "/$1";
#print "STANDALONE PAGE!$lonelyPage";
		} else {
			if ($checkData) {
				$pageRef =~ s/^$FirstLevelName\///g;
				foreach my $refx (split(/\//,$pageRef)) {
#					print "$buildPath ($refx)";
					my $gotNameMatch = 0;
					foreach my $key (keys $checkData) {
#						print "$key<br>\n";
						if ($checkData->{$key}{'name'} eq $refx) {
							$gotNameMatch = 1;
#							print "MATCH: $checkData->{$key}{'name'} :: $refx<br>\n";
							$buildPath .= "/$refx";
							if ($checkData->{$key}{'type'} eq 'p') {
								$buildNavLine .= "<a href=\"/md/$FirstLevelName$buildPath.html\" class=\"mdtopnavpathlink\">$checkData->{$key}{'title'}</a>";
							} elsif ($checkData->{$key}{'type'} eq 'd') {
								$buildNavLine .= "<a href=\"/md/$FirstLevelName$buildPath/\" class=\"mdtopnavpathlink\">$checkData->{$key}{'title'}</a>/";
							}
#							print "<pre>",Dumper($checkData),"</pre><hr>";
							$checkData = $checkData->{$key}{'sub'};
#							print "<pre>",Dumper($checkData),"</pre><hr>";
						} 
					}
					unless ($gotNameMatch > 0) {
						$isValidSite = 0;
						$ItsA404 = 1;
					}
				}
			} else {
				# DO SOMETHING HERE IF menuData/checkData dont exist!
			}
		}
		$buildNavLine = "<span class=\"mdtopnavpath\"><a href=\"/md/$FirstLevelName/\" class=\"mdtopnavpathlink\" title=\"$firstDescription\">$firstTitle</a>/$buildNavLine</span>";
#######		print "ISVALS:$isValidSite <br>\n$buildNavLine<br>$FirstLevelName$buildPath\n";
		# Check and build path
		#########################
		my $mhtmlName = "$FirstLevelName$buildPath";
		$mhtmlName =~ s/^\///g;
		$mhtmlName =~ s/\/$//g;
		$mhtmlName =~ s/\//\_/g;

		my $mhtmlPath;
		if (-f "$BaseMHTMLPATH/$mhtmlName.mhtml") {
			$mhtmlPath = "$BaseMHTMLPATH/$mhtmlName.mhtml";
		} elsif (-f "$BaseMHTMLPATH/$mhtmlName\_index.mhtml") {
			$mhtmlPath = "$BaseMHTMLPATH/$mhtmlName\_index.mhtml";
		} 
		if (-f $mhtmlPath) {
			$PageHTML = getMHTMLdata($mhtmlPath,"h");
		}
	}

	if (($PageHTML) and ($ItsA404 ne 1)) {
			if (lc($dirConf{'treemenu'}) eq "left") {
				print "<div class=\"main_markdown_side_menu_outerDIV\">";
				print "<a href=\"/md/$FirstLevelName/\" class=\"md_menutreetoptitle\">$firstTitle</a>";
				print "<br>$MenuHTML</div>";
			}
			print "<div class=\"the_markdown_container_DIV\">";
			if ($dirConf{'topnavline'}) {
				print "$buildNavLine<br>\n";
			}
			print "$PageHTML\n<br></div>";
		#print "$MenuHTML";
		#print "";
	} else {
		print "<h1 style=\"font-size: 400%\">404!?</h1>";
	}
	print "</DIV></DIV>";
}


sub genTopBAR {
my ($mainMenu,$miniMenu) = genTopMenu($AWS{'qsPageACTIVE'},"landing:start;Start;","md:docs:index;Documentation;");
	print <<"EOF";
<!-- TopBAR START -->
<div class="mini_top_bar-outerDIV"><div class="mini_top_bar-innerDIV"><table class="main_top_bar-TABLE">
<tr><td width="30%"><div class="mini_top_bar-logoDIV">$AWS{'LOGOHTMLSTRING'}</div></td>
<td width="70%"><div class="mini_top_bar-menuDIV">$miniMenu</div></td></tr></table></div></div>
<div class="main_top_bar-outerDIV" id="theVeryTOP"><div class="main_top_bar-innerDIV"><table class="main_top_bar-TABLE">
	<tr>
		<td  class="main_top_bar-projectLogoTD" width="30%"><div class="main_top_bar-projectLogoDIV">$AWS{'LOGOHTMLSTRING'}</div></td>
		<td class="main_top_bar-topMenuTD" width="70%"><div class="main_top_bar-topMenuDIV">$mainMenu
EOF
print "		</div></td>\n	</tr>\n</table></div></div>\n<!-- TopBAR END -->\n";
}

sub genTopLandingBanner {
	print "<div class=\"landingPageBigBannerOuterImgDIV\" style=\"background-image:url('/media/landingbanner/NONFREE_banner_001.jpg');\">";
	print "<div class=\"landingPageBigBannerInnerDIV\"><table class=\"landingPageBigBannerOverlayTABLE\">";
	print "<tr><td class=\"landingPageBigBannerOverlayTD\"><span class=\"landingPageBigBannerTextSPAN\">";
	print "<b style=\"font-size: 120%;\">Sssssh.... listen...</b><br>";
	print "<b style=\"font-size: 200%;\">There is a disturbance in the north!</b><br><b style=\"font-size: 120%;\">Can you feel it?</b>";
	print "</span></td></tr>";
	print "</table></div></div>";
}



sub genHeader {
	my $bodybgstyle;
	if ($_[0] eq "landing") {# dont load a big heavy BG picture for the landing page where we probably got a big heavy banner!
		$bodybgstyle = "style=\"background-image:url('');\"";
	}
	print <<"EOF";
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Strict//EN">
<HTML>
	<HEAD>
		<meta charset="UTF-8">
		<title>The Arctica Project</title>
		<link rel="stylesheet" type="text/css" href="/css/main.css">
		<link rel="stylesheet" type="text/css" href="/css/md1.css">
	</HEAD>
	<BODY $bodybgstyle>
EOF
}

sub genFooter {
	print <<"EOF";
<div class="footer_main_skinny_separator_DIV"></div>
<div class="footer_main_footer_area_DIV">
	<div class="footer_gray_bar-innerDIV">
		<div class="footer_BackToTopBTN" onClick=\"location.href=\'#theVeryTOP\'\">to the top</div>
		<br>
		<div class="footer_main_contentDIV">
			<br><br><h1>FOOTER CONTENT GOES HERE?</h1><br>
	<img src="/Aquicon-RSS.png" height="64" border="0" alt="rss feed">
<br>
		</div>
	</div>
	<div class="footer_copyright_notice_barDIV">Copyright &copy; 2014-2015 The Arctica Project</div>
</div>
	</BODY>
</HTML>
EOF
}


sub getMHTMLdata {
	my $mhtmlFile = $_[0];
	my $fetchWhat = lc($_[1]);
	if (-f $mhtmlFile) {
		if ($fetchWhat eq "a") {
			open(MHTML,$mhtmlFile);
			my ($pub,$title,$decription,undef,undef,undef,undef,undef,undef,undef,@HTML) = <MHTML>;
			$pub =~ s/\D//g;
			$title = s/\n//g;
			$decription = s/\n//g;
			close(MHTML);
			return ($pub,$title,$decription,"@HTML");
		} elsif ($fetchWhat eq "t") {
			open(MHTML,$mhtmlFile);
			my ($pub,$title,$decription,undef,undef) = <MHTML>;
			$pub =~ s/\D//g;
			$title = s/\n//g;
			$decription = s/\n//g;
			close(MHTML);
			return ($pub,$title,$decription);
		} elsif ($fetchWhat eq "h") {
			open(MHTML,$mhtmlFile);
			my (undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,@HTML) = <MHTML>;
			close(MHTML);
			return "@HTML";
		}
	}
}


sub genTopMenu {
	my ($theActivePage,@menuItems) = @_;

	my $mainMENU = "<ul class=\"main_top_bar-topMenuUL\">";
	my $miniMENU = "<ul class=\"mini_top_bar-topMenuUL\">";
	foreach my $menuitem (@menuItems) {
		$menuitem =~ s/\n//g;
		if ($menuitem =~ /^([a-z0-9]*)\:([a-z0-9\/]*)\;(.*)\;$/) {
			my $isActive = "mainTopMenuTextSPAN_NOTA";
			my $pageType = $1;
			my $pageRef = $2;
			my $linkText = $3;
			if ("$pageType:$pageRef" =~ /^$theActivePage/) {
				$isActive = "mainTopMenuTextSPAN_ISA";
			}
			$mainMENU .= "<li class=\"main_top_bar-topMenuLI\" onclick=\"location.href=\'/$pageType/$pageRef\'\"><span class=\"$isActive\">$linkText</span></li>";
			$miniMENU .= "<li class=\"mini_top_bar-topMenuLI\" onclick=\"location.href=\'/$pageType/$pageRef\'\"><span class=\"$isActive\">$linkText</span></li>";
		}
	}
	$mainMENU .= "</ul>";
	$miniMENU .= "</ul>";
	return ($mainMENU,$miniMENU);
}

sub makeMenuList {
	my $menuData = $_[0];
	my $linkPrefix = $_[1];
	my $HTML;
	my $nameHash;
	$HTML = "<ul class=\"verticalMenuUL\">";
	foreach my $key (sort keys $menuData) {
#		print "K: $key	\n";
		my $mouseOverDescription;
		if (length($menuData->{$key}{'description'}) > 2) {
			$mouseOverDescription = " title=\"$menuData->{$key}{'description'}\"";
		}
		if (lc($menuData->{$key}{'type'}) eq 'p') {
			$HTML .= "<li class=\"verticalMenuLI\"><a class=\"verticalMenuA\" href=\"$linkPrefix/$menuData->{$key}{'name'}.html\" $mouseOverDescription>$menuData->{$key}{'title'}</a></li>\n";
		} elsif (lc($menuData->{$key}{'type'}) eq 'd') {
			$HTML .= "<li class=\"verticalMenuLI\"><a class=\"verticalMenuA\" href=\"$linkPrefix/$menuData->{$key}{'name'}/\" $mouseOverDescription>$menuData->{$key}{'title'}/</a></li>\n";
			if ($menuData->{$key}{'sub'}{'1'}) {
				$HTML .= makeMenuList($menuData->{$key}{'sub'},"$linkPrefix/$menuData->{$key}{'name'}");
			}
		}

	}
	$HTML .= "</ul>\n";
	return $HTML;
}




