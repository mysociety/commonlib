#!/usr/bin/perl
#
# CouncilMatch.pm:
# 
# Code related to matching/fixing OS and GE data for councils.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: CouncilMatch.pm,v 1.1 2005-01-21 19:28:01 francis Exp $
#

package mySociety::CouncilMatch;

use Data::Dumper;

our $parent_types = [qw(DIS LBO MTD UTA LGD CTY)];
our $child_types = [qw(DIW LBW MTW UTE UTW LGW CED)];

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

# match_council_wards COUNCIL_ID VERBOSITY MAPIT_DB DADEM_DB
# Attempts to match up the wards from the raw_input_data table to the Ordnance
# Survey names.  Stores results in raw_process_status.
sub match_council_wards ($$$$) {
    my ($area_id, $verbosity, $m_dbh, $d_dbh) = @_;
    print "Area: $area_id\n" if $verbosity > 0;
    my $error = "";

    # Set of wards GovEval have
    my $wards_array = $d_dbh->selectcol_arrayref(q#select distinct(ward_name) from raw_input_data
        where council_id = ?#, {}, $area_id);
    my $wards_goveval = [];
    do { push @{$wards_goveval}, { name => $_} } for @$wards_array;

    # Set of wards already in database (from Ordnance Survey / ONS)
    my $rows = $m_dbh->selectall_arrayref(q#select distinct on (area_id) area_id, name from area_name, area where
        area_name.area_id = area.id and parent_area_id = ? and
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
        $ret .= sprintf "%38s => %-38s\n", 'Matches Made: GovEval', 'OS/ONS Name (mySociety ID)';
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
        $ret .= sprintf "\n%38s\n", "Other Database wards:";
        $ret .= sprintf "-" x 80 . "\n";
        foreach my $d (@$wards_database) {
            if (!exists($d->{referred})) {
                $ret .= sprintf "%38s\n", $d->{id} . " " . $d->{name};
            }
        }
        $ret .= sprintf "\n%38s\n", "Other GovEval wards:";
        $ret .= sprintf "-" x 80 . "\n";
        foreach my $g (@$wards_goveval) {
            if (!exists($g->{matches})) {
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

    # Clean up looped references
    foreach my $d (@$wards_database) {
        delete $d->{used};
    }
    foreach my $g (@$wards_goveval) {
        delete $g->{matches};
    }

    # Update status field
    $status = $error ? 'wards-mismatch' : 'wards-match';
    $d_dbh->do(q#delete from raw_process_status where council_id=?#, {}, $area_id);
    $d_dbh->do(q#insert into raw_process_status (council_id, status, details)
        values (?,?,?)#, {}, $area_id, $status, ($error ? ($error . "\n") : "") . $matchesdump);
    $d_dbh->commit();

    return { 'matchesdump' => $matchesdump, 
             'error' => $error };
}



1;
