#!/usr/bin/perl
#
# CouncilMatch.pm:
# 
# Code related to matching/fixing OS and GE data for councils.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: CouncilMatch.pm,v 1.12 2005-02-02 00:10:01 francis Exp $
#

package mySociety::CouncilMatch;

use Data::Dumper;
use LWP::Simple;
use HTML::TokeParser;
use Text::CSV;
use URI;

use mySociety::StringUtils qw(trim merge_spaces);

our ($d_dbh, $m_dbh);
# set_db_handles MAPID_DB DADEM_DB
# Call first with DB handles to use for other functions.
sub set_db_handles($$) {
    $m_dbh = shift;
    $d_dbh = shift;
}

our $parent_types = [qw(DIS LBO MTD UTA LGD CTY)];
our $child_types = [qw(DIW LBW MTW UTE UTW LGW CED)];

# process_ge_data COUNCIL_ID VERBOSITY 
# Performs next step(s) in processing on GE data.  Returns
# hashref containing 'details' and 'error' should you need it,
# but that is also saved in raw_process_status.
sub process_ge_data ($$) {
    my ($area_id, $verbosity) = @_;
    my ($status, $error, $details);

    # Match up wards
    my $ret = match_council_wards($area_id, $verbosity);
    $status = $ret->{error} ? 'wards-mismatch' : 'wards-match';
    $error .= $ret->{error} ? $ret->{error} : "";
    $details .= $ret->{details};

    # See if we have URL
    if ($status eq "wards-match") {
        my $found = check_for_extradata($area_id);
        $status = $found ? "url-found" : "url-missing";

        # Check against council website
        if ($status eq 'url-found') {
            my $ret = check_councillors_against_website($area_id, $verbosity);
            $status = $ret->{error} ? 'councillors-mismatch' : 'councillors-match';
            $error .= $ret->{error} ? $ret->{error} : "";
            $details = $ret->{details} . "\n" . $details;
        }
    }

    # Save status
    set_process_status($area_id, $status, $error ? $error : undef, $details);
    $d_dbh->commit();

    return { 'details' => $details, 
             'error' => $error };
}


# get_process_status COUNCIL_ID
# Returns the text string saying what state of GE data processing
# the council is in.
sub get_process_status ($) {
    my ($area_id) = @_;
    my $ret = $d_dbh->selectrow_arrayref(q#select status from raw_process_status 
        where council_id = ?#, {}, $area_id);
    if (!defined($ret)) {
        return "";
    }
    return $ret->[0];
}

# set_process_status COUNCIL_ID STATUS ERROR DETAILS
# Alter processing status for a council.
sub set_process_status ($$$$) {
    my ($area_id, $status, $error, $details) = @_;

    $d_dbh->do(q#delete from raw_process_status where council_id=?#, {}, $area_id);
    $d_dbh->do(q#insert into raw_process_status (council_id, status, error, details)
        values (?,?,?,?)#, {}, $area_id, $status, $error, $details);
}


# canonicalise_council_name NAME
# Convert the NAME of a council into a "canonical" version of the name.
# That is, one with all the parts which often vary between spellings
# reduced to the simplest form.  e.g. Removing the word "Council" and
# punctuation.
sub canonicalise_council_name ($) {
    $_ = shift;

    if (m/^Durham /) {
        # Durham County and Durham District both have same name (Durham)
        # so we leave in the type (County/District) as a special case
        s# City Council# District#;
        s# County Council# County#;
    } else {
        s#\s*\(([A-Z]{2})\)##; # Pendle (BC) => Pendle
        s#(.+) - (.+)#$2#;     # Sir y Fflint - Flintshire => Flintshire

        s#^City and County of ##;         # City and County of the City of London => the City of London
        s#^The ##i;
        s# City Council$##;    # OS say "District", GovEval say "City Council", we drop both to match
        s# County Council$##;  # OS say "District", GovEval say "City Council", we drop both to match
        s# Borough Council$##; # Stafford Borough Council => Stafford
        s# Council$##;         # Medway Council => Medway
        s# City$##;            # Liverpool City => Liverpool
        s#^City of ##;         # City of Glasgow => Glasgow
        s#^County of ##;
        s#^Corp of ##;         # Corp of London => London
        s# District$##;
        s# County$##;
        s# City$##;
        s# London Boro$##;

        s#sh'r$#shire#;       # Renfrewsh'r => Renfrewshire
        s#W\. Isles#Na H-Eileanan an Iar#;    # Scots Gaelic(?) name for Western Isles
        s#^Blackburn$#Blackburn with Darwen#;

        s#\bN\.\s#North #g;    # N. Warwickshire => North Warwickshire
        s#\bS\.\s#South #g;    # S. Oxfordshire => South Oxfordshire
        s#\bE\.\s#East #g;     # North E. Derbyshire => North East Derbyshire
        s#\bW\.\s#West #g;     # W. Sussex => West Sussex
        s#\bGt\.\s#Great #g;   # Gt. Yarmouth => Great Yarmouth

        s#&#and#g;
        s#-# #g;
        s#'##g;                # King's Lynn => Kings Lynn
        s#,##g;                # Rhondda, Cynon, Taff => Rhondda Cynon Taff
    }
   
    $_ = lc;
    return $_;
}

# Load in nickname data
my $nickmap;
my $csv_parser = new Text::CSV;
open NICKNAMES, "<../mapit-dadem-loading/nicknames/nicknames.csv" or die "couldn't find nicknames.csv file";
<NICKNAMES>; # heading
while (my $line = <NICKNAMES>) {
    chomp($line);
    $csv_parser->parse($line);
    my ($nick, $canon) = map { trim($_) } $csv_parser->fields();
    push @{$nickmap->{lc($nick)}}, lc($canon);
}

# match_modulo_nickname NAMEA NAMEB
# Sees if two names match, allowing for nickname.  Each name must be in form
# "firstname initials othernames", all lowercase.  e.g. "timmy tailor" would
# match "timothy tailor".  Returns 1 if match, 0 otherwise.
sub match_modulo_nickname($$) {
    my ($a, $b) = @_;
    my (@a, @b);
    my ($afirst, $arest) = ($a =~ m/^(.*) (.*)$/);
    my ($bfirst, $brest) = ($b =~ m/^(.*) (.*)$/);
    return 0 if (!defined($arest) || !defined($brest) || !defined($afirst) || !defined($bfirst));
    return 0 if ($arest ne $brest);
    return 1 if ($afirst eq $bfirst);
    my %anames = ($afirst => 1);
    my %bnames = ($bfirst => 1);
    do { $anames{$_} = 1 } for @{$nickmap->{$afirst}};
    do { $bnames{$_} = 1 } for @{$nickmap->{$bfirst}};
    #print "$afirst-$arest, $bfirst-$brest\n";
    #print Dumper(\%anames);
    #print Dumper(\%bnames);
    foreach $_ (keys %anames) {
        return 1 if (exists($bnames{$_}));
    }
    return 0;
}

#print match_modulo_nickname("jack nobody", "hans nobody");
#print "\n";
#print match_modulo_nickname("timmy tailor", "timothy tailor");
#print "\n";
#exit;

# canonicalise_person_name NAME
# Convert name from various formats "Fred Smith", "Smith, Fred",
# "Fred R Smith", "Smith, Fred RK" to uniform one "fred smith".  Removes
# initials except first one if there is no first name, puts surname last,
# lowercases.
sub canonicalise_person_name ($) {
    ($_) = @_;

    # Swap Lastname, Firstname
    s/^([^,]+),([^,]+)$/$2 $1/;  

    # Clear up spaces and punctuation
    s#[[:punct:]]##g;
    $_ = trim($_);
    $_ = merge_spaces($_);

    # Remove fancy words
    my $titles = "Cllr |Councillor |Dr |Hon |hon |rah |rh |Mrs |Ms |Mr |Miss |Rt Hon |Reverend |The Rev |The Reverend |Sir |Dame |Rev |Prof ";
    my $honourifics = " MP| CBE| OBE| MBE| QC| BEM| rh| RH| Esq| QPM| JP| FSA| Bt| BEd| Hons| TD| MA| QHP| DL| CMG| BB| AKC| Bsc| Econ| LLB| GBE| QSO| BA| FRSA| FCA| DD| KBE| PhD";
    while (s#^($titles )##) {};
    while (s#( $honourifics)$##) {};

    # Split up initials unspaced 
    s/\b([[:upper:]])([[:upper:]])\b/$1 $2/g;
    # Remove initials apart from first name/initial
    s/\b(\S+ )((?:[[:upper:]] )+)/$1/;

    # Remove case
    $_ = lc($_);

    return $_;
}

# canonicalise_ward_name WARD
# Returns Ward name with extra suffixes (e.g. Ward) removed, and in lowercase.
sub canonicalise_ward_name ($) {
    ($_) = @_;
    s# Ward$##;
    return mySociety::CouncilMatch::canonicalise_council_name($_);
}

# Internal use
# check_for_extradata COUNCIL_ID 
# Checks we have the councillor names webpage URL, and any other needed data.
sub check_for_extradata ($) {
    my ($area_id) = @_;
    my $ret = $d_dbh->selectrow_arrayref(q#select council_id, councillors_url from 
        raw_council_extradata where council_id = ?#, {}, $area_id);
    my $found = 0;
    if (defined($ret)) {
        if ($ret->[1] ne "") {
            $found = 1;
        }
    }
    return $found;
}
 
# Internal use
# match_council_wards COUNCIL_ID VERBOSITY 
# Attempts to match up the wards from the raw_input_data table to the Ordnance
# Survey names. Returns hash ref containing 'details' and 'error'.
sub match_council_wards ($$) {
    my ($area_id, $verbosity) = @_;
    print "Area: $area_id\n" if $verbosity > 0;
    my $error = "";

    # Set of wards GovEval have
    my @raw_data = get_raw_data($area_id);
    # ... find unique set
    my %wards_hash;
    do { $wards_hash{$_->{'ward_name'}} = 1 } for @raw_data;
    my @wards_array = keys(%wards_hash);
    # ... store in special format
    my $wards_goveval = [];
    do { push @{$wards_goveval}, { name => $_} } for @wards_array;

    # Set of wards already in database (from Ordnance Survey / ONS)
    my $rows = $m_dbh->selectall_arrayref(q#select distinct on (area_id) area_id, name from area_name, area where
        area_name.area_id = area.id and parent_area_id = ? and (name_type = 'O' or name_type = 'S') and
        (# . join(' or ', map { "type = '$_'" } @$mySociety::CouncilMatch::child_types) . q#) 
        #, {}, $area_id);
    my $wards_database = [];
    foreach my $row (@$rows) { 
        my ($area_id, $name) = @$row;
        push @{$wards_database}, { name => $name, id => $area_id };
    }
    
    @$wards_database = sort { $a->{name} cmp $b->{name} } @$wards_database;
    @$wards_goveval = sort { $a->{name} cmp $b->{name} } @$wards_goveval;

    my $dump_wards = sub {
        $ret = "";
        $ret .= sprintf "%38s => %-38s\n", 'Ward Matches Made: GovEval', 'OS/ONS Name (mySociety ID)';
        $ret .= sprintf "-" x 38 . ' '. "-" x 38 . "\n";

        foreach my $g (@$wards_goveval) {
            if (exists($g->{matches})) {
                $first = 1;
                foreach my $d (@{$g->{matches}}) {
                    $ret .= sprintf "%38s => %-38s\n", $first ? $g->{name} : "", $d->{name} . " (" . $d->{id}.")";
                    $first = 0;
                    $d->{referred} = 1;
                }
            }
        }

        $first = 1;
        foreach my $d (@$wards_database) {
            if (!exists($d->{referred})) {
                if ($first) {
                    $ret .= sprintf "\n%38s\n", "Other Database wards:";
                    $ret .= sprintf "-" x 80 . "\n";
                    $first = 0;
                }
                $ret .= sprintf "%38s\n", $d->{id} . " " . $d->{name};
            }
        }
        $first = 1;
        foreach my $g (@$wards_goveval) {
            if (!exists($g->{matches})) {
                if ($first) {
                    $ret .= sprintf "\n%38s\n", "Other GovEval wards:";
                    $ret .= sprintf "-" x 80 . "\n";
                    $first = 0;
                }
                $ret .= sprintf "%38s\n", $g->{name};
            }
        }
        $ret .= "\n";
        return $ret;
    };

    if (@$wards_goveval != @$wards_database) {
        # Different numbers of wards by textual name.
        # This will happen due to different spellings, the
        # below fixes it up if it can.
    }
 
    # Work out area_id for each GovEval ward
    foreach my $g (@$wards_goveval) {
        # Find the entry in database which best matches each GovEval
        # name, store multiple same-length ties.
        my $longest_len = -1;
        my $longest_matches = undef;
        foreach my $d (@$wards_database) {
            my $match1 = $g->{name};
            my $match2 = $d->{name};
            my $common_len = Common::placename_match_metric($match1, $match2);
          
            # If more common characters, store it
            if ($common_len > $longest_len) {
                $longest_len = $common_len;
                $longest_matches = undef;
                push @{$longest_matches}, $d;
            } elsif ($common_len == $longest_len) {
                push @{$longest_matches}, $d;
            }
        }

        # Longest len
        if ($longest_len < 3) {
            $error .= "${area_id}: Couldn't find match in database for GovEval ward " .  $g->{name} . " (longest common substring < 3)\n";
        } else {
            # Record the best ones
            $g->{matches} = $longest_matches;
            #print Dumper($longest_matches);
            # If exactly one match, use it for definite
            if ($#$longest_matches == 0) {
                push @{$longest_matches->[0]->{used}}, $g;
                $g->{id} = $longest_matches->[0]->{id};
                print "Best is: " . $g->{name} . " is " .  $longest_matches->[0]->{name} . " " .  $longest_matches->[0]->{id} . "\n" if $verbosity > 0;
            } else {
                foreach my $longest_match (@{$longest_matches}) {
                    print "Ambiguous are: " . $g->{name} . " is " .  $longest_match->{name} . " " .  $longest_match->{id} .  "\n" if $verbosity > 0;
                }

            }
        }
    }

    # Second pass to clear up those with two matches 
    # e.g. suppose there are both "Kilbowie West Ward", "Kilbowie Ward"
    # The match of "Kilbowie Ward" against "Kilbowie West" and "Kilbowie"
    # will find Kilbowie as shortest substring, and have two matches.
    # We want to pick "Kilbowie" not "Kilbowie West", but can only do so
    # after "Kilbowie West" has been allocated to "Kilbowie West Ward".
    # Hence this second pass.
    foreach my $g (@$wards_goveval) {
        next if (exists($g->{id}));
        next if (!exists($g->{matches}));

        # Find matches which haven't been used elsewhere
        my @left = grep { !exists($_->{used}) } @{$g->{matches}};
        my $count = scalar(@left);
       
        if ($count == 0) {
            # If there are none, that's no good
            $error .= "${area_id}: Couldn't find match in database for GovEval ward " . $g->{name} . " (had ambiguous matches, but all been taken by others)\n";
        } elsif ($count > 1) {
            # If there is more than one
            $error .= "${area_id}: Only ambiguous matches found for GovEval ward " .  $g->{name} .  ", matches are " . join(", ", map { $_->{name} } @left) . "\n";
        } else {
            my $longest_match = $left[0];
            push @{$longest_match->{used}}, $g;
            $g->{id} = $longest_match->{id};
            $g->{matches} = \@left;
            print "Resolved is: " . $g->{name} . " is " .  $longest_match->{name} . " " .  $longest_match->{id} . "\n" if $verbosity > 0;
        }
    }
    
    # Check we used every single ward (rather than used same twice)
    foreach my $d (@$wards_database) {
        if (!exists($d->{used})) {
            $error .= "${area_id}: Ward in database, not in GovEval data: " . $d->{name} . " id " . $d->{id} . "\n";
        } else {
            delete $d->{used};
        }
    }
    
    # Store textual version of what we did
    $matchesdump = &$dump_wards();

    # Make it an error when a ward has two 'G' spellings, as it happens rarely
    if (!$error) {
        my $wardnames;
        foreach my $g (@$wards_goveval) {
            die if (!exists($g->{matches}));
            die if (scalar(@{$g->{matches}}) != 1);
            my $dd = @{$g->{matches}}[0];
            if (exists($wardnames->{$dd->{id}})) {
                if ($wardnames->{$dd->{id}} ne $g->{name}) {
                    $error .= "${area_id}: Ward has multiple GovEval spellings '" . $g->{name} . "', '" . $wardnames->{$dd->{id}} ."'\n";
                }
            }
            $wardnames->{$dd->{id}} = $g->{name};
        }
    }

    # Delete any old aliases
    foreach my $d (@$wards_database) {
        $m_dbh->do(q#delete from area_name where area_id = ? and name_type = 'G'#, {}, $d->{id});
    }

    # Store name aliases in DB
    if (!$error) {
        foreach my $g (@$wards_goveval) {
            die if (!exists($g->{matches}));
            die if (scalar(@{$g->{matches}}) != 1);
            my $dd = @{$g->{matches}}[0];
            $m_dbh->do(q#insert into area_name (area_id, name_type, name)
                values (?,?,?)#, {}, $dd->{id}, 'G', $g->{name});
        }
        $m_dbh->commit();
    }
 
    # Clean up looped references
    foreach my $d (@$wards_database) {
        delete $d->{used};
    }
    foreach my $g (@$wards_goveval) {
        delete $g->{matches};
    }

    # Return data
    return { 'details' => $matchesdump, 
             'error' => $error };
}

# get_raw_data COUNCIL_ID 
# Return raw input data, with any admin modifications, for a given council.
# In the form of an array of references to hashes.  Each hash contains the
# ward_name, rep_first, rep_last, rep_party, rep_email, rep_fax.
sub get_raw_data($) {
    my ($area_id) = @_;

    # Hash from representative key (either ge_id or newrow_id, with appropriate
    # prefix to distinguish them) to data about the representative.
    my $council;
    
    # Real data case
    my $sth = $d_dbh->prepare(
            q#select * from raw_input_data where
            council_id = ?#, {});
    $sth->execute($area_id);
    while (my $rep = $sth->fetchrow_hashref) {
        my $key = 'ge_id' . $rep->{ge_id};
        $council->{$key} = $rep;
        $council->{$key}->{key} = $key;
    }

    # Override with other data
    $sth = $d_dbh->prepare(
            q#select * from raw_input_data_edited where
            council_id = ? order by order_id#, {});
    $sth->execute($area_id);
    # Apply each transaction in order
    while (my $edit = $sth->fetchrow_hashref) {
        my $key = $edit->{ge_id} ? 'ge_id'.$edit->{ge_id} : 'newrow_id'.$edit->{newrow_id};
        if ($edit->{alteration} eq 'delete') {
            die "get_raw_data: delete row that doesn't exist" if (!exists($council->{$key}));
            delete $council->{$key};
        } elsif ($edit->{alteration} eq 'modify') {
            $council->{$key} = $edit;
            $council->{$key}->{key} = $key;
        } else {
            die "Uknown alteration type";
        }
    }

    return values(%$council);
}

# edit_raw_data COUNCIL_ID COUNCIL_NAME COUNCIL_TYPE ONS_CODE DATA ADMIN_USER
# Alter raw input data as a transaction log (keeping history).
# DATA is in the form of a reference to an array of references to hashes.  Each
# hash contains the ward_name, rep_first, rep_last, rep_party, rep_email, rep_fax, key
# (from get_raw_data above).  Include all the councils, as deletions are
# applied.  ADMIN_USER is name of person who made this edit.
# COUNCIL_NAME and COUNCIL_TYPE are stored in the edit for reference later if
# for some reason ids get broken, really only COUNCIL_ID matters.
sub edit_raw_data($$$$$$) {
    my ($area_id, $area_name, $area_type, $area_ons_code, $newref, $user) = @_;
    my @new = @$newref;

    my @old = get_raw_data($area_id);

    my %old; do { $old{$_->{key}} = $_ } for @old;
    my %new; do { $new{$_->{key}} = $_ } for @new;

    # Delete entries which are in old but not in new
    foreach my $key (keys %old) {
        if (!exists($new{$key})) {
            my ($newrow_id) = ($key =~ m/^newrow_id([0-9]+)$/);
            my ($ge_id) = ($key =~ m/^ge_id([0-9]+)$/);
            my $sth = $d_dbh->prepare(q#insert into raw_input_data_edited
                (ge_id, newrow_id, alteration, council_id, council_name, council_type, council_ons_code,
                ward_name, rep_first, rep_last, 
                rep_party, rep_email, rep_fax, 
                editor, whenedited, note)
                values (?, ?, ?, ?, ?, ?, ?,
                        ?, ?, ?, ?, ?, ?, 
                        ?, ?, ?) #);
            $sth->execute($ge_id, $newrow_id, 'delete', $area_id, $area_name, $area_type, $area_ons_code,
                $old{$key}->{ward_name}, $old{$key}->{rep_first}, $old{$key}->{rep_last}, 
                $old{$key}->{rep_party}, $old{$key}->{rep_email}, $old{$key}->{rep_fax},
                $user, time(), "");
        }
    }

    # Go through everything in new, and modify if different from old
    foreach my $rep (@new) {
        my $key = $rep->{key};

        if ($key && exists($old{$key})) {
            my $changed = 0;
            foreach my $fieldname qw(ward_name rep_first rep_last rep_party rep_email rep_fax) {
                if ($old{$key}->{$fieldname} ne $rep->{$fieldname}) {
                    print "changed";
                    $changed = 1;
                }
            }
            next if (!$changed);
        }
        
        # Find row identifiers
        my ($newrow_id) = ($key =~ m/^newrow_id([0-9]+)$/);
        my ($ge_id) = ($key =~ m/^ge_id([0-9]+)$/);
        if (!$newrow_id && !$ge_id) {
            my @row = $d_dbh->selectrow_array(q#select nextval('raw_input_data_edited_newrow_seq')#);
            $newrow_id = $row[0];
        }

        # Insert alteration
        my $sth = $d_dbh->prepare(q#insert into raw_input_data_edited
            (ge_id, newrow_id, alteration, council_id, council_name, council_type, council_ons_code,
            ward_name, rep_first, rep_last, rep_party, 
            rep_email, rep_fax, 
            editor, whenedited, note)
            values (?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?,
                    ?, ?,
                    ?, ?, ?) #);
        $sth->execute($ge_id, $newrow_id, 'modify', $area_id, $area_name, $area_type, $area_ons_code,
            $rep->{'ward_name'}, $rep->{'rep_first'}, $rep->{'rep_last'}, $rep->{'rep_party'},
                $rep->{'rep_email'}, $rep->{'rep_fax'},
            $user, time(), "");

    }
    $d_dbh->commit();
}

# Break parts of array separated by various sorts of punctuation
sub split_lumps_further($) {
    my ($lumps) = @_;
    my @lumps = map { split / - | \(| \)/, $_ } @$lumps;
    return @lumps;
}

# check_councillors_against_website COUNCIL_ID VERBOSITY 
# Attempts to match up the wards from the raw_input_data table to the Ordnance
# Survey names. Returns hash ref containing 'details' and 'error'.
sub check_councillors_against_website($$) {
    my ($area_id, $verbose) = @_;
    print "Council " . $area_id . "\n" if $verbose;

    # Get URL from database
    my $extradata = $d_dbh->selectrow_hashref(q#select council_id, councillors_url from 
        raw_council_extradata where council_id = ?#, {}, $area_id);

    # Get known data from database
    my @raw = mySociety::CouncilMatch::get_raw_data($area_id);
    my $wardnames = $m_dbh->selectall_hashref(
            q#select * from area_name, area where area_name.area_id = area.id and
            parent_area_id = ?#, 'name', {}, $area_id);
    my $wardnamescanon;
    do { $wardnamescanon->{canonicalise_ward_name($_)} = $wardnames->{$_} } for keys %$wardnames;
    # Various lookup tables
    my $wardsbyid;
    do { $wardsbyid->{$wardnames->{$_}->{id}} = $wardnames->{$_}->{name} } for keys %$wardnames;
    my $cllrsbykey;
    do { $cllrsbykey->{$_->{key}} = $_ } for @raw;
    my $cllrsbywardid;
    do { push @{$cllrsbywardid->{$wardnames->{$_->{ward_name}}->{id}}}, $_ if (defined($wardnames->{$_->{ward_name}})) } for @raw;

    # Get all HTML from councillor list web page, and tidy
    print "Getting main page... $extradata->{councillors_url} " if $verbose;
    my $mainpage = LWP::Simple::get($extradata->{councillors_url});
    print "...got\n" if $verbose;
    my @lumps = mySociety::StringUtils::break_into_lumps($mainpage);
    @lumps = split_lumps_further(\@lumps);
    my $content = $mainpage;

    # Get out next layer of URLs
    my @urls;
    my $p = HTML::TokeParser->new(\$mainpage);
    # include only clickable maps "area"
    while (my $token = $p->get_tag("area")) {
        my $url = $token->[1]{href};
        next if !$url;
        next if $url =~ m/^\#/;
        next if $url =~ m/\.pdf$/;
        if (!URI->new($url)->scheme()) { # only relative ones
            my $uri = URI->new_abs($url, $extradata->{councillors_url});
            $url = $uri->as_string();
            push @urls, $url;
        }
    }

    # scan_with_pattern PATTERN
    # Scan lumps to find wards and councillors in given pattern
    my $scan_with_pattern = sub {
        my ($pattern) = @_;
        die "scan_with_pattern: invalid pattern $pattern" if ($pattern ne "WCWCCC" && $pattern ne "CWCWCW");
        my $error = "";

        my $warddone;
        do { $warddone->{$wardnames->{$_}->{id}} = [] if $wardnames->{$_}->{id}} for keys %$wardnames;
        my $repdone;
        do { $repdone->{$_->{key}} = [] } for @raw;
    
        # Scan for stuff
        my $lastwardid = undef;
        my $lastcllrkey = undef;
        foreach my $lump (@lumps) {
            my $canon_lump = canonicalise_person_name($lump);
            print "lump: $canon_lump\n" if $verbose > 1;

            my $matches = 0;
            foreach my $rep (@raw) {
                my $first = $rep->{rep_first};
                my $last = $rep->{rep_last};
                # Match representative names various ways
                my $canon_name = canonicalise_person_name("$first $last");
                print "name: $canon_name\n" if $verbose > 1;
                # If lump begins with an initial, initialise first word of name
                # In that case, don't bother with nicknames
                my $match = 0;
                if ($canon_lump =~ m/^[[:alpha:]] /) {
                    $canon_name =~ s/^([[:alpha:]])([[:alpha:]]+) /$1 /;
                    $match = ($canon_lump eq $canon_name);
                } else {
                    # Apply nicknames
                    $match = match_modulo_nickname($canon_lump, $canon_name); 
                }
                if ($match) {
                    print "councillor matched '$canon_lump' == '$canon_name'\n" if $verbose;
                    $lastcllrkey = $rep->{key};
                    push @{$repdone->{$lastcllrkey}}, $lump;
                    $matches ++;
                    if ($pattern eq "WCWCCC") {
                        # check ward right
                        if (!(defined $lastwardid)) {
                            $error .= $area_id . ": councillor $first $last in wrong ward, ge " . $rep->{ward_name} . " none on website\n";
                        } elsif (!(defined $wardnames->{$rep->{ward_name}})) {
                            $error .= $area_id . ": councillor $first $last has unknown ward " . $rep->{ward_name} . "\n";
                        } elsif ($wardnames->{$rep->{ward_name}}->{id} != $lastwardid) {
                            $error .= $area_id . ": councillor $first $last in wrong ward, ge " . $rep->{ward_name} . " website " . $wardsbyid->{$lastwardid} . "\n";
                        }
                    }
                }
            }
            if ($matches > 1) {
                $error .= $area_id . ": $lump matched multiple councillors\n";
            }

            my $canonlump = canonicalise_ward_name($lump);
            if (exists($wardnamescanon->{$canonlump})) {
                print "ward matched '$canonlump'\n" if $verbose;
                $lastwardid = $wardnamescanon->{$canonlump}->{id};
                push @{$warddone->{$lastwardid}}, $lump;
                if ($pattern eq "CWCWCW") {
                    # check councillor right
                    if (!$lastcllrkey) {
                        $error .= $area_id . ": ward $lump without councillor\n";
                    } elsif (!grep { $_->{key} eq $lastcllrkey } @{$cllrsbywardid->{$lastwardid}}) {
                        #print Dumper(@{$cllrsbywardid->{$lastwardid}});
                        #print "lastcllrkey $lastcllrkey\n";
                        $error .= $area_id . ": councillor " . $cllrsbykey->{$lastcllrkey}->{rep_first} . " " .
                            $cllrsbykey->{$lastcllrkey}->{rep_last} . " appears in wrong ward, ge " . 
                            $cllrsbykey->{$lastcllrkey}->{ward_name} . " website $lump\n";
                    }
                }
            }
        }

        # Check all got
        foreach my $ward (keys %$warddone) {
            if (!scalar(@{$warddone->{$ward}})) {
                $error = $area_id . ": ward not matched " . $wardsbyid->{$ward} . " $ward\n" . $error;
            }
        }
        foreach my $rep (keys %$repdone) {
            if (!scalar(@{$repdone->{$rep}})) {
                my $name = $cllrsbykey->{$rep}->{rep_first} . " " . $cllrsbykey->{$rep}->{rep_last};
                # Find best matches by common substring to give as examples
                my $canon_name = canonicalise_person_name($name);
                my ($best_len, $best_match);
                foreach my $lump (@lumps) {
                    my $canon_lump = canonicalise_person_name($lump);
                    my $common_len = Common::placename_match_metric($canon_lump, $canon_name);
                    if (!defined($best_len) or $best_len < $common_len) {
                        $best_match = $lump;
                        $best_len = $common_len;
                    }
                }
                $error = $area_id . ": councillor not matched ge " . $name . " best match on council website: $best_match\n" . $error;
            }
        }

        # Dump matches we have made
        my $details = "";
        $details .= sprintf "%38s => %-38s\n", 'Councillor Matches Made: GovEval', 'Council Website';
        $details .= sprintf "-" x 38 . ' '. "-" x 38 . "\n";
        foreach my $repkey (keys %$repdone) {
            my $gename = $cllrsbykey->{$repkey}->{rep_first} . " " . $cllrsbykey->{$repkey}->{rep_last};
            $first = 1;
            foreach my $match (@{$repdone->{$repkey}}) {
                $details .= sprintf "%38s => %-38s\n", $first ? $gename : "", $match;
                $first = 0;
            }
        }
        $details .= sprintf "\n%38s => %-38s\n", 'Ward Matches Made: GovEval', 'Council Website';
        $details .= sprintf "-" x 38 . ' '. "-" x 38 . "\n";
        foreach my $ward (keys %$warddone) {
            my $gename = $wardsbyid->{$ward};
            $first = 1;
            foreach my $match (@{$warddone->{$ward}}) {
                $details .= sprintf "%38s => %-38s\n", $first ? $gename : "", $match;
                $first = 0;
            }
        }

        return ($error, $details);
    };

    my ($error1, $details1) = &$scan_with_pattern("WCWCCC");
    my ($error2, $details2) = &$scan_with_pattern("CWCWCW");
    my $ecount1 = ($error1 =~ tr/\n/\n/);
    my $ecount2 = ($error2 =~ tr/\n/\n/);
    if ($ecount1 > 20 and $ecount2 > 20) {
        # Nothing much good, so try recursive get
        foreach my $url (@urls) {
            print "Getting... $url " if $verbose;
            my $subpage = LWP::Simple::get($url);
            print "...got\n" if $verbose;
            my @newlumps = mySociety::StringUtils::break_into_lumps($subpage);
            @newlumps = split_lumps_further(\@newlumps);
            push @lumps, @newlumps;
        }
        ($error1, $details1) = &$scan_with_pattern("WCWCCC");
        ($error2, $details2) = &$scan_with_pattern("CWCWCW");
        $ecount1 = ($error1 =~ tr/\n/\n/);
        $ecount2 = ($error2 =~ tr/\n/\n/);
    }

    my ($details, $error);
    if (!$error1) {
        print "WCWCCC worked\n" if $verbose;
        $details = $details1;
    }
    if (!$error2) {
        print "CWCWCW worked\n" if $verbose;
        $details = $details2;
    }
    if ($error1 && $error2) {
        if ($ecount1 < $ecount2) {
            print "least-errorful is WCWCCC\n" if $verbose;
            $error .= $error1;
            $details = $details1;
        } else {
            print "least-errorful is CWCWCW\n" if $verbose;
            $error .= $error2;
            $details = $details2;
        }
    }

    # Return data
    return { 'details' => $details, 
             'error' => $error };
}


1;
