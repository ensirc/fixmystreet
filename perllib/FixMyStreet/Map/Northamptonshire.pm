package FixMyStreet::Map::Northamptonshire;
use base 'FixMyStreet::Map::WMSBase';

use strict;

sub default_zoom { 8; }

sub urls { [ 'https://maps.northamptonshire.gov.uk/interactivemappingwms/getcapabilities.ashx' ] }

sub layer_names{ [ 'BaseMap' ] }

sub copyright {
    return '&copy; NCC';
}

sub scales {
    my $self = shift;
    my @scales = (
        # The first 5 levels don't load and are really zoomed-out, so
        #  they're not included here.
        # '600000',
        # '500000',
        # '400000',
        # '300000',
        # '200000',
        '100000',
        '75000',
        '50000',
        '25000',
        '10000',
        '8000',
        '6000',
        '4000',
        '2000',
        '1000',
        '400',
    );
    return @scales;
}
sub tile_parameters {
    my $self = shift;
    my $params = {
        urls            => $self->urls,
        layer_names     => $self->layer_names,
        wms_version    => '1.1.1',
        layer_style     => 'default',
        format          => 'image/png', # appended to tile URLs
        size            => 256, # pixels
        dpi             => 96,
        inches_per_unit => 39.3701,
        projection      => 'EPSG:27700',
        origin_x        => -5220400.0,
        origin_y        => 4470200.0,
    };
    return $params;
}

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.debug.js',
    '/js/map-OpenLayers.js',
    '/js/map-wms-base.js',
    '/js/map-wms-northamptonshire.js',
] }

1;
