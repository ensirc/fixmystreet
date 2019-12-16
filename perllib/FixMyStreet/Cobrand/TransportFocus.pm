package FixMyStreet::Cobrand::TransportFocus;
use base 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

sub on_map_default_status { return 'open'; }

sub body {
    FixMyStreet::DB->resultset('Body')->search({ name => 'Highways England' })->first;
}

sub problems_restriction {
    my ($self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');
    $rs = $rs->to_body($self->body);
    return $rs;
}

1;
