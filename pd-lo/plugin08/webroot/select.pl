#!/opt/local/bin/perl -w
use strict;
use CGI qw(:standard);
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use CGI::Upload;
use File::Copy;
use Net::OpenSoundControl::Client;

my $cgi = new CGI;
my $cgu = CGI::Upload->new({ query => $cgi});

my $sampledir = "/home/lo/src/k2-data/pd-lo/viper06/webroot/upload";

#foreach my $key (sort(keys(%ENV))) {
#    print "$key = $ENV{$key}<br>\n";
#} 

# message to desplay;
my $flash = "";
my $currentsample = "";

my @osc;

# sample upload
my $file = $cgi->param("samplefile");
my $sampleselect = $cgi->param("sampleselect");

if($file) {
  my $newsample = uploadSample($file);
  if($newsample) {
    $currentsample = selectSample($newsample);
  }
}
elsif($sampleselect) {
  $currentsample = selectSample($sampleselect);
}
else {
  $flash = "<span class='finfo'>Welcome to S.O.U.P<br/></span>";
}

if(@osc > 0) {
  sendOsc(@osc);
}

# sample select

print header;

print <<"HTML";
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="de" lang="de">
<head>
	<title>s.o.u.p</title>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
	<style type="text/css" media="all">\@import "support/style.css";</style>

	<style type="text/css" media="all">\@import "support/drupal.css";</style>
	
	<script type="text/javascript"><!--
	
	function play() {
		var list = document.getElementById("sampleselect");
		if(list) {
			document.location.href="upload/" + list.value;
		}
	}
	//-->
	</script>

<style type="text/css"><!-- 
		
		#leftColumn { display: none; }
		#middleColumn { margin: 0; }
		#innerColumnContainer, #outerColumnContainer { border-left-width: 0; }
	
		* html body
		{
			text-align: center;	/* hack to center this under IE5 */
		}
		* html #pageWrapper
		{
			text-align: left;	/* keep the content left-aligned */
		}
		
		#pageWrapper
		{
			width: 800px;
			margin-left: auto;
			margin-right: auto;
		}
	
	--></style>

</head>
<body>

		<div id="pageWrapper">
			<div id="masthead">
		<hr class="hide" />
			</div>
			<div id="outerColumnContainer">
				<div id="innerColumnContainer">
					<div id="SOWrap">
						<div id="middleColumn">
							<div class="inside">

  <div class="node sticky">    
    <div class="content">
  <span id='flash'>$flash</span>
  	</div>
  	</div>
  <div class="node sticky">    
    <div class="content">
  <form action="http://$ENV{SERVER_ADDR}$ENV{SCRIPT_NAME}" method="post" enctype="multipart/form-data">
  <h4>s.e.l.e.c.t a sample</h4>
  <select name="sampleselect" id="sampleselect" size="10">
HTML

opendir(DIR,$sampledir) || die "can't opendir $sampledir: $!";
foreach(readdir(DIR)) {
  if(-r "$sampledir/$_" && -f "$sampledir/$_" && !/^\./) {
    my $selected = ($_ eq $currentsample) ? " selected":"";
    print "<option".$selected.">".$_."</option>\n";
  }
}
closedir(DIR);

print <<"HTML";
  </select><br/>

  <input type="button" value="play" onClick="play();">
    <input type="submit" value="select">
  <h4>u.p.l.o.a.d your sample</h4>
  <input type="file" name="samplefile" accept="audio/*" maxlength="2097152"><br/>
  <input type="submit" value="send">
  </form>

  <h4>s.t.r.e.a.m the results</h4>
  <p>after choosing/uploading your sample you may want to generate some traffic in order to spot
     your computer in the autio chaos. using this live stream you will gnereate some feedback in two
     ways: audio and wireless.</p>
  <p>note that this is rather heavy for the server, so please don't stream for to long...</p>
  <a href="http://$ENV{SERVER_ADDR}:8000/soup">live stream (mp3)</a>
	</div>
</div>
<!-- end content -->


								<hr class="hide" />
							</div>
						</div>
						<div id="leftColumn">
							<div class="inside">

<!--- left column begin -->


<!--- left column end -->

								<hr class="hide" />
							</div>
						</div>
						<div class="clear"></div>
					</div>
					<div id="rightColumn">
						<div class="inside">

<!--- right column begin -->
    <div id="sidebar-right">
  <div class="block block-menu" id="block-menu-33">
    <h2 class="title">menu</h2>
	<a href="select.pl">interface</a><br/>
	<a href="about.html">about</a><br/>

  </div></div>


 
<!--- right column end -->

							<hr class="hide" />
						</div>
					</div>
					<div class="clear"></div>
				</div>
			</div>

<div id="footer" class="inside">

 
<p>
	driven by <a href="http://drupal.org/">drupal</a> and hosted on <a href="http://www.textdrive.com/">textdrive</a> design by lorenz and alejo, valid xhtml/css tableless layout derived from <a href="http://webhost.bridgew.edu/etribou/layouts/">skidoo too</a>
</p>

<hr class="hide" />
</div>
	</div>
</body></html>

HTML

sub uploadSample {
  my $file = shift(@_);
    
  my $ifh = $cgu->file_handle('samplefile');
  my $mt = $cgu->mime_type('samplefile');
  my $filename = $cgu->file_name('samplefile');
  
  if($mt !~ /^audio\/.*/) {
    $flash .= "<span class='ferror'>file type must be either WAV or AIFF.</span><br/>";
    return undef;
  }
  
  # sanitize filename
  $filename =~ s/^[.\/]+//g;
  $filename =~ s/\s/_/g;
  $filename =~ s/[^0-9a-zA-Z\.\-_]//g;
  # save extension
  my $ext = "";
  my $basename = $filename;
  if($filename =~ /(.*)(\.\w+)$/) {
    $basename = $1;
    $ext = $2;
  }
  # create unique filename
  for(my $i=1; -e $sampledir."/".$filename; $i++) {
    $filename = $basename."_".$i.$ext;
  }

  #copy (upload) stuff
  copy($ifh,$sampledir."/".$filename);
  close($ifh);
  
  $flash .= "<span class='finfo'>sample upload was successfull.</span><br/>";
  $flash .= "<span class='debug'>ifh=".$ifh." mt=".$mt." filename=".$filename."</span><br/>";
  return $filename;
}

sub selectSample {
  my $sample = shift(@_);
  if(-r $sampledir."/".$sample) {
    push(@osc,['/web/client/sample', 's', $sampledir."/".$sample]);
    $flash .= "<span class='finfo'>sample ".$sample." is now assigned to your machine.</span><br/>";
    return $sample;
  }
  $flash .= "<span class='ferror'>sample ".$sample." could not be assigned to your machine!</span><br/>";
}

sub sendOsc {
  my $ip = $ENV{REMOTE_ADDR};
  # get mac oddress via arp and convert to uppercase XX:XX:XX:XX:XX:XX
  my $mac = `arp $ip | grep -E -o "[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}"`;
  chop $mac;
  if($mac eq "") {
		$mac = "unknown";
  }
  else {
    # sanitize. each element has to be 2 bytes long.
    my @items=split(':',$mac);
    last if (@items!=6);
    $mac = "";
    foreach(@items) {
      $mac .= length==1 ? "0" : "";
      $mac .= uc().":";
    }
    chop $mac;
  }
	$flash .= "<span class='fdebug'>your mac address: ".$mac."</span><br/>";
  
  # send osc to localhost 23456
  my $client = Net::OpenSoundControl::Client->new(
    Host => "127.0.0.1", Port => 23456) or die "Could not start client: $@\n";
  $client->send(['/web/client/set', 's', $mac, 's', $ip]);
  
  # send actual data here
  foreach (@_) {
    $client->send($_);
  }
  # eod
  $client->send(['/web/client/bang']);
}
