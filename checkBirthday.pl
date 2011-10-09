#!/usr/bin/perl

# Modules
use strict;
use warnings;
use utf8;
use Switch;
use Text::vCard::Addressbook;
use File::List;
use Mail::Sendmail;

# Global defs
my $contact_dir        = '/opt/kerio/mailserver/store/mail/domain.local/user/Contacts/#msgs';
my $contact_file       = 'eml';
my $warn_before_bday   = '5';

my $send_mail_report  = '0';
my $send_mail_from    = 'no-reply@domain.local';
my $send_mail_to      = 'user@domain.local';
my $send_mail_subject = 'Birthday reminder';
my $send_mail_data    = undef;

my $debug = 0;

opendir(DIR, "$contact_dir") or die "Cannot open $contact_dir";
closedir(DIR);

# Collect date in YYYYMMDD format
sub getDate($) {
	my $warn = shift;
	my $result = undef;
	my @date = undef;

	if ($warn) {
		@date=localtime(time+($warn*86400));
	} else {
		@date=localtime(time);
	}
	my ($tday, $tmonth, $tyear) = ($date[3], $date[4]+1, $date[5]+1900);
	#my ($tday, $tmonth, $tyear) = (localtime)[3..5]; $tyear+=1900; $tmonth++;
	
	$result = sprintf("%02d%02d%02d", $tyear,$tmonth,$tday);
	print " -> Collect date in YYYMMDD format in warn $warn days\n" if $debug eq 1;
	print "    day: $tday month: $tmonth year: $tyear result: $result\n" if $debug eq 1;

	return $result;
}

# Parse date and cut YYYY
sub parseDate($) {
	my $date = shift;
	my $result = undef;
	my ($day, $month, $year) = undef;

	$day   = substr($date, -2, 2);
	$month = substr($date, -4, 2);

	$result = $month.$day;
	print " -> Parsing date $date\n" if $debug eq 1;
	print "    day: $day month: $month result: $result\n" if $debug eq 1;

	return $result;
}

# Just sendmail
sub sendMail($) {
	my $message = shift;
	my %mail = ( To      => $send_mail_to,
		     From    => $send_mail_from,
		     Subject => $send_mail_subject,
		     Message => $message,
		     'Content-Type' => 'text/plain; charset="UTF-8"'
	     	   );

	if (sendmail %mail) {
		print "Report has been sent to $send_mail_to\n";
	} else { 
		print "Error sending report: $Mail::Sendmail::error \n"
	}
}

# Get all .eml contact files
my $search = new File::List($contact_dir);
my @files = @{ $search->find("\.$contact_file\$") };

# Parse fount contacts
foreach my $file (@files) {
	print "Processing $file\n" if $debug eq 1;

	my $address_book = Text::vCard::Addressbook->new({
		'source_file' => $file,
	});
	
	# Process vCard
	foreach my $vcard ($address_book->vcards()) {
		if($vcard->bday()) {
			print " -> found bday ".$vcard->bday()."\n" if $vcard->bday() and $debug eq 1;
			# Check if has birthday in upcomming days
			my $vcardDate = &parseDate($vcard->bday());
			for (my $loop=0; $loop<=$warn_before_bday; $loop++) {
				my $loopDate = &parseDate(&getDate($loop));
				print " -> Check if $loopDate == $vcardDate\n" if $debug eq 1;
				if ($loopDate == $vcardDate) {
					my $message .= $vcard->fullname .' has birthday ';
					switch ($loop) {
						case 0 { $message .= 'today' }
						case 1 { $message .= 'tomorrow' }
						else   { $message .= 'in '.$loop.' days' }
					}
					$send_mail_data .= $message.".\n";
				}
			}
		}
	}
}

if ($send_mail_data) {
	print $send_mail_data;
	if ($send_mail_report == 1) {
		&sendMail($send_mail_data)
	}
}

exit 0;

