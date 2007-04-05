#!/usr/bin/perl
#
# mySociety/Sundries.pm
# Sundry utilities, split from mySociety::Util.
#

package mySociety::Sundries;

use strict;

use Statistics::Distributions qw(fdistr);

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(&ordinal)
}
our @EXPORT_OK;

=head1 NAME

mySociety::Sundries

=head1 DESCRIPTION

Sundry utilities, split from mySociety::Util.

=head1 FUNCTIONS

=over 4

=item ordinal NUM

Return the ordinal for NUM (e.g. "1st", "2nd", etc.). XXX localisation.

=cut
sub ordinal ($) {
    my $num = shift;
    if ($num == 11 || $num == 12) {
        return "${num}th";
    } else {
        my $n = $num % 10;
        my @ending = qw(th st nd rd);
        if ($n < @ending) {
            return $num . $ending[$n];
        } else {
            return "${num}th";
        }
    }
}

=item create_accessor_methods 

For a package which is derived from "fields", create any accessor methods which
have not already been defined.

=cut
sub create_accessor_methods () {
    my $h = fields::new((caller())[0]);
    my $caller = caller();
    foreach (keys %$h) {
        
        next if (eval "exists($_)");
        eval <<EOF;
package $caller; 
sub $_ (\$;\$) {
    my \$self = shift;
    if (\@_) {
        \$self->{$_} = \$_[0];
    }
    return \$self->{$_};
}
EOF
    }
}

=item binomial_confidence_interval SUCCESSES SAMPLES

Returns the mean probability for one trial and its 95% confidence interval,
given the result of a particular series of bernoulli trials. SAMPLES is the
total number of trials, and SUCCESSES is the number that resulted in true.
Return values are (mean, low, high).

So, for example, these two series of trials have the same mean, but a different
confidence interval, because the latter has more samples.

  3 /   10: mean = 0.300000; 95% CI = [0.066739, 0.652454]
300 / 1000: mean = 0.300000; 95% CI = [0.271728, 0.329452]

=cut
sub binomial_confidence_interval ($$) {
    my ($x, $N) = @_;

    die "number of SAMPLES, $N, must be > 0" unless ($N > 0);
    die "number of SUCCESSES, $x, must be >= 0" if ($x < 0);
    die "number of SUCCESSES, $x must be <= SAMPLES, $N" if ($x > $N);

    # If n p q is large, use the normal approximation.
    my $p = $x / $N;
    return ($p, $p - sqrt($p * (1 - $p) / $N), $p + sqrt($p * (1 - $p) / $N))
        if ($N * $p * (1 - $p) > 25);

    # Otherwise we do it properly.

    # http://www.statsresearch.co.nz/pdf/confint.pdf
    # Non Asymptotic Binomial Confidence Intervals
    # x successes from N trials; print estimate of mean and 95% confidence
    # interval.
    my $alpha = 0.05;

    my $mean = ($x / $N);

    if ($x == 0 || $x == $N) {
        # One-sided; see note in http://statpages.org/confint.html
        $alpha *= 2;
    }

    my $lower;
    if ($x == 0) {
        $lower = 0;
    } else {
        $lower = $x
                    / ($x + ($N - $x + 1) * fdistr(2 * ($N - $x + 1), 2 * $x, $alpha / 2));
    }

    my $upper;
    if ($x == $N) {
        $upper = 1;
    } else {
        $upper = (($x + 1) * fdistr(2 * ($x + 1), 2 * ($N - $x), $alpha / 2))
                    / ($N - $x + ($x + 1) * fdistr(2 * ($x + 1), 2 * ($N - $x), $alpha / 2));
    }

    #printf "%d / %d: mean = %f; 95%% CI = [%f, %f]\n", $x, $N, $mean, $lower, $upper;
    return ($mean, $lower, $upper);
}

1;
