#!/usr/bin/perl -w
#
# mySociety/Alert.pm:
# Alerts by email or RSS.
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Alert.pm,v 1.34 2007-09-14 12:58:02 matthew Exp $

package mySociety::Alert::Error;

use Error qw(:try);

@mySociety::Alert::Error::ISA = qw(Error::Simple);

package mySociety::Alert;

use strict;
use Error qw(:try);
use File::Slurp;
use FindBin;
use XML::RSS;

use mySociety::AuthToken;
use mySociety::Config;
use mySociety::DBHandle qw(dbh);
use mySociety::Email;
use mySociety::EmailUtil;
use mySociety::GeoUtil;
use mySociety::MaPit;
use mySociety::Sundries qw(ordinal);
use mySociety::Web qw(ent);

# Add a new alert
sub create ($$;@) {
    my ($email, $alert_type, @params) = @_;
    my $already = 0;
    if (0==@params) {
        ($already) = dbh()->selectrow_array('select id from alert where alert_type=? and email=? limit 1',
            {}, $alert_type, $email);
    } elsif (1==@params) {
        ($already) = dbh()->selectrow_array('select id from alert where alert_type=? and email=? and parameter=? limit 1',
            {}, $alert_type, $email, @params);
    } elsif (2==@params) {
        ($already) = dbh()->selectrow_array('select id from alert where alert_type=? and email=? and parameter=? and parameter2=? limit 1',
            {}, $alert_type, $email, @params);
    }
    return $already if $already;

    my $id = dbh()->selectrow_array("select nextval('alert_id_seq');");
    if (0==@params) {
        dbh()->do('insert into alert (id, alert_type, email)
            values (?, ?, ?)', {}, $id, $alert_type, $email);
    } elsif (1==@params) {
        dbh()->do('insert into alert (id, alert_type, parameter, email)
            values (?, ?, ?, ?)', {}, $id, $alert_type, @params, $email);
    } elsif (2==@params) {
        dbh()->do('insert into alert (id, alert_type, parameter, parameter2, email)
            values (?, ?, ?, ?, ?)', {}, $id, $alert_type, @params, $email);
    }
    dbh()->commit();
    return $id;
}

sub confirm ($) {
    my $id = shift;
    dbh()->do("update alert set confirmed=1 where id=?", {}, $id);
    dbh()->commit();
}

# Delete an alert
sub delete ($) {
    my $id = shift;
    dbh()->do('update alert set whendisabled = ms_current_timestamp() where id = ?', {}, $id);
    dbh()->commit();
}

# This makes load of assumptions, but still should be useful
# 
# Child must have created, id, email, state(!) columns
# If parent/child, child table must also have name and text
#   and foreign key to parent must be PARENT_id

sub email_alerts () {
    my $url = mySociety::Config::get('BASE_URL');
    my $q = dbh()->prepare("select * from alert_type where ref != 'local_problems'");
    $q->execute();
    while (my $alert_type = $q->fetchrow_hashref) {
        my $ref = $alert_type->{ref};
        my $head_table = $alert_type->{head_table};
        my $item_table = $alert_type->{item_table};
        my $query = 'select alert.id as alert_id, alert.email as alert_email,
            alert.parameter as alert_parameter, alert.parameter2 as alert_parameter2, ';
        if ($head_table) {
            $query .= "
                   $item_table.id as item_id, $item_table.name as item_name, $item_table.text as item_text,
                   $head_table.*
            from alert
                inner join $item_table on alert.parameter = $item_table.${head_table}_id
                inner join $head_table on alert.parameter = $head_table.id";
        } else {
            $query .= " $item_table.*,
                   $item_table.id as item_id
            from alert, $item_table";
        }
        $query .= "
            where alert_type='$ref' and whendisabled is null and $item_table.created >= whensubscribed
             and (select whenqueued from alert_sent where alert_sent.alert_id = alert.id and alert_sent.parameter = $item_table.id) is null
            and $item_table.email <> alert.email and $alert_type->{item_where}
            and alert.confirmed = 1
            order by alert.id, $item_table.created";
        # XXX Ugh - needs work
        $query =~ s/\?/alert.parameter/ if ($query =~ /\?/);
        $query =~ s/\?/alert.parameter2/ if ($query =~ /\?/);
        $query = dbh()->prepare($query);
        $query->execute();
        my $last_alert_id;
        my %data = ( template => $alert_type->{template}, data => '' );
        while (my $row = $query->fetchrow_hashref) {
            dbh()->do('insert into alert_sent (alert_id, parameter) values (?,?)', {}, $row->{alert_id}, $row->{item_id});
            if ($last_alert_id && $last_alert_id != $row->{alert_id}) {
                _send_aggregated_alert_email(%data);
                %data = ( template => $alert_type->{template}, data => '' );
            }
            if ($row->{item_text}) {
                $data{problem_url} = $url . "/?id=" . $row->{id};
                $data{data} .= $row->{item_name} . ' : ' if $row->{item_name};
                $data{data} .= $row->{item_text} . "\n\n------\n\n";
            } else {
                $data{data} .= $url . "/?id=" . $row->{id} . " - $row->{title}\n\n";
            }
            if (!$data{alert_email}) {
                %data = (%data, %$row);
                if ($ref eq 'area_problems' || $ref eq 'council_problems' || $ref eq 'ward_problems') {
                    my $va_info = mySociety::MaPit::get_voting_area_info($row->{alert_parameter});
                    $data{area_name} = $va_info->{name};
                }
                if ($ref eq 'ward_problems') {
                    my $va_info = mySociety::MaPit::get_voting_area_info($row->{alert_parameter2});
                    $data{ward_name} = $va_info->{name};
                }
            }
            $last_alert_id = $row->{alert_id};
        }
        if ($last_alert_id) {
            _send_aggregated_alert_email(%data);
        }
    }

    # Nearby done separately as the table contains the parameters
    my $query = "select * from alert where alert_type='local_problems' and whendisabled is null and confirmed=1 order by id";
    $query = dbh()->prepare($query);
    $query->execute();
    while (my $alert = $query->fetchrow_hashref) {
        my %data = ( template => 'alert-problem', data => '' );
        my $q = "select * from problem_find_nearby(?, ?, ?) as nearby, problem
            where nearby.problem_id = problem.id and problem.state in ('confirmed', 'fixed')
            and problem.created >= ?
            and (select whenqueued from alert_sent where alert_sent.alert_id = ? and alert_sent.parameter = problem.id) is null
            and problem.email <> ?
            order by created desc";
        $q = dbh()->prepare($q, $alert->{parameter}, $alert->{parameter2}, 5, $alert->{whensubscribed}, $alert->{id}, $alert->{email});
        $q->execute();
        while (my $row = $q->fetchrow_hashref) {
            dbh()->do('insert into alert_sent (alert_id, parameter) values (?,?)', {}, $alert->{id}, $row->{id});
            $data{data} .= $url . "/?id=" . $row->{id} . " - $row->{title}\n\n";
            if (!$data{alert_email}) {
                %data = (%data, %$row);
            }
        }
        _send_aggregated_alert_email(%data);
    }
}

sub _send_aggregated_alert_email(%) {
    my %data = @_;
    $data{unsubscribe_url} = mySociety::Config::get('BASE_URL') . '/A/'
        . mySociety::AuthToken::store('alert', { id => $data{alert_id}, type => 'unsubscribe', email => $data{alert_email} } );
    my $template = File::Slurp::read_file("$FindBin::Bin/../templates/emails/$data{template}");
    my $email = mySociety::Email::construct_email({
        _template_ => $template,
        _parameters_ => \%data,
        From => [mySociety::Config::get('CONTACT_EMAIL'), mySociety::Config::get('CONTACT_NAME')],
        To => $data{alert_email},
    });

    my $result;
    if (mySociety::Config::get('STAGING_SITE')) {
        $result = 1; # SOFT_ERROR
    } else {
        $result = mySociety::EmailUtil::send_email($email, mySociety::Config::get('CONTACT_EMAIL'),
            $data{alert_email}, mySociety::Config::get('CONTACT_EMAIL'));
    }
    if ($result == mySociety::EmailUtil::EMAIL_SUCCESS) {
        dbh()->commit();
    } else {
        dbh()->rollback();
        throw mySociety::Alert::Error("Failed to send alert $data{alert_id}!");
    }
}

sub generate_rss ($$;$$) {
    my ($type, $qs, $db_params, $title_params) = @_;
    $db_params ||= [];
    my $url = mySociety::Config::get('BASE_URL');
    my $q = dbh()->prepare('select * from alert_type where ref=?');
    $q->execute($type);
    my $alert_type = $q->fetchrow_hashref;
    throw mySociety::Alert::Error('Unknown alert type') unless $alert_type;

    # Do our own encoding
    my $rss = new XML::RSS( version => '2.0', encoding => 'UTF-8',
        stylesheet=>'/xsl.xsl', encode_output => undef );
    $rss->add_module(prefix=>'georss', uri=>'http://www.georss.org/georss');

    my $query = 'select * from ' . $alert_type->{item_table} . ' where '
        . ($alert_type->{head_table} ? $alert_type->{head_table}.'_id=? and ' : '')
        . $alert_type->{item_where} . ' order by '
        . $alert_type->{item_order};
    $query .= ' limit 10' unless $type =~ /^all/;
    $q = dbh()->prepare($query);
    if ($query =~ /\?/) {
        throw mySociety::Alert::Error('Missing parameter') unless @$db_params;
        $q->execute(@$db_params);
    } else {
        $q->execute();
    }

    my @months = ('', 'January','February','March','April','May','June',
        'July','August','September','October','November','December');
    while (my $row = $q->fetchrow_hashref) {
        # XXX: How to do this properly? name might be null in comment table, hence needing this
        $row->{name} ||= 'anonymous';
        # And we want pretty dates... :-/
        $row->{confirmed} =~ s/^\d\d\d\d-(\d\d)-(\d\d) .*/ordinal($2+0).' '.$months[$1]/e if $row->{confirmed};

        (my $title = $alert_type->{item_title}) =~ s/{{(.*?)}}/$row->{$1}/g;
        (my $link = $alert_type->{item_link}) =~ s/{{(.*?)}}/$row->{$1}/g;
        (my $desc = $alert_type->{item_description}) =~ s/{{(.*?)}}/$row->{$1}/g;
        my %item = (
            title => ent($title),
            link => $url . $link,
            guid => $url . $link,
            description => ent(ent($desc)) # Yes, double-encoded, really.
        );
        # XXX: Not-very-generic extensions
        if ($row->{photo}) {
            $item{description} .= ent("\n<br><img src=\"$url/photo?id=$row->{id}\">");
        }
        if ($row->{easting} && $row->{northing}) {
            my ($lat,$lon) = mySociety::GeoUtil::national_grid_to_wgs84($row->{easting}, $row->{northing}, 'G');
            $item{georss} = { point => "$lat $lon" };
        }
        $rss->add_item( %item );
    }

    my $row = {};
    if ($alert_type->{head_sql_query}) {
        $q = dbh()->prepare($alert_type->{head_sql_query});
        if ($alert_type->{head_sql_query} =~ /\?/) {
            $q->execute(@$db_params);
        } else {
            $q->execute();
        }
        $row = $q->fetchrow_hashref;
    }
    foreach (keys %$title_params) {
        $row->{$_} = $title_params->{$_};
    }
    (my $title = $alert_type->{head_title}) =~ s/{{(.*?)}}/$row->{$1}/g;
    (my $link = $alert_type->{head_link}) =~ s/{{(.*?)}}/$row->{$1}/g;
    (my $desc = $alert_type->{head_description}) =~ s/{{(.*?)}}/$row->{$1}/g;
    $rss->channel(
        title => ent($title), link => "$url$link$qs", description  => ent($desc),
        language   => 'en-gb'
    );

    print CGI->header( -type => 'application/xml; charset=utf-8' );
    my $out = $rss->as_string;
    $out =~ s{</link>}{</link><uri>$ENV{SCRIPT_URI}</uri>};
    print $out;
}
