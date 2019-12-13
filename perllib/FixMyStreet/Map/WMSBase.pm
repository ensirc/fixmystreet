# FixMyStreet:Map::WMSBase
# Makes it easier for cobrands to use their own WMS base map.
# This cannot be used directly; you must subclass it and implement several
# methods. See, e.g. FixMyStreet::Map::Northamptonshire.

package FixMyStreet::Map::WMSBase;

use strict;
use Math::Trig;
use Utils;
use JSON::MaybeXS;

sub scales {
    my $self = shift;
    my @scales = (
        # A list of scales corresponding to zoom levels, e.g.
        # '192000',
        # '96000',
        # '48000',
        # etc...
    );
    return @scales;
}

# The copyright string to display in the corner of the map.
sub copyright {
    return '';
}

# A hash of parameters that control the zoom options for the map
sub zoom_parameters {
    my $self = shift;
    my $params = {
        zoom_levels    => scalar $self->scales,
        default_zoom   => 0,
        min_zoom_level => 0,
        id_offset      => 0,
    };
    return $params;
}

# A hash of parameters used in calculations for map tiles
sub tile_parameters {
    my $params = {
        urls         => [ '' ], # URL of the map tiles, up to the /{z}/{x}/{y} part
        layer_names  => [ '' ],
        wms_version => '1.0.0',
        layer_style  => '',
        matrix_set   => '',
        suffix       => '', # appended to tile URLs
        size         => 256, # pixels
        dpi          => 96,
        inches_per_unit => 0, # See OpenLayers.INCHES_PER_UNIT for some options.
        projection   => 'EPSG:3857', # Passed through to OpenLayers.Projection
    };
    return $params;
}

# This is used to determine which template to render the map with
sub map_template { 'wms' }

# Reproject a WGS84 lat/lon into an x/y coordinate in this map's CRS.
# Subclasses will want to override this.
sub reproject_from_latlon($$$) {
    my ($self, $lat, $lon) = @_;
    return (0.0, 0.0);
}

# Reproject a x/y coordinate from this map's CRS into WGS84 lat/lon
# Subclasses will want to override this.
sub reproject_to_latlon($$$) {
    my ($self, $x, $y) = @_;
    return (0.0, 0.0);
}


sub map_tiles {
    my ($self, %params) = @_;
    my ($left_col, $top_row, $z) = @params{'x_left_tile', 'y_top_tile'};
    my $tile_url = $self->tile_base_url;
    my $layer = $self->tile_parameters->{layer_names};
    my $tile_suffix = $self->tile_parameters->{suffix};
    my $version = $self->tile_parameters->{version};
    my $size = $self->tile_parameters->{size};
    my $format = $self->tile_parameters->{format};
    my $projection = $self->tile_parameters->{projection};
    my @scales = $self->scales;
    my $cols = $params{cols};
    my $rows = $params{rows};

    my @col_offsets = (0.. ($cols-1) );
    my @row_offsets = (0.. ($rows-1) );

    my $res = $scales[$params{zoom}] /
        ($self->tile_parameters->{inches_per_unit} * $self->tile_parameters->{dpi});
    my $size = $res * $size;
    my ($min_x, $min_y, $max_x, $max_y) = ($left_col, $top_row - $size, $left_col + $size, $top_row);

    return [
        map {
            my $row_offset = $_;
            [
                map {
                    my $col_offset = $_;
                    my $row = $row_offset * $size;
                    my $col = $col_offset * $size;
                    my $src = sprintf '%s&bbox=%d,%d,%d,%d',
                        $tile_url, $min_x + $col, $min_y - $row, $max_x + $col, $max_y - $row;
                    my $dotted_id = sprintf '%d.%d', ($min_x + $col), ($min_y - $row);

                    # return the data structure for the cell
                    +{
                        src => $src,
                        row_offset => $row_offset,
                        col_offset => $col_offset,
                        dotted_id => $dotted_id,
                        alt => "Map tile $dotted_id", # TODO "NW map tile"?
                    }
                }
                @col_offsets
            ]
        }
        @row_offsets
    ];
}

# display_map C PARAMS
# PARAMS include:
# latitude, longitude for the centre point of the map
# CLICKABLE is set if the map is clickable
# PINS is array of pins to show, location and colour
sub display_map {
    my ($self, $c, %params) = @_;

    # Map centre may be overridden in the query string
    $params{latitude} = Utils::truncate_coordinate($c->get_param('lat') + 0)
        if defined $c->get_param('lat');
    $params{longitude} = Utils::truncate_coordinate($c->get_param('lon') + 0)
        if defined $c->get_param('lon');

    $params{rows} //= 2; # 2x2 square is default
    $params{cols} //= 2;

    my $zoom_params = $self->zoom_parameters;

    $params{zoom} = do {
        my $zoom = defined $c->get_param('zoom')
            ? $c->get_param('zoom') + 0
            : $c->stash->{page} eq 'report'
                ? $zoom_params->{default_zoom}+1
                : $zoom_params->{default_zoom};
        $zoom = $zoom_params->{zoom_levels} - 1
            if $zoom >= $zoom_params->{zoom_levels};
        $zoom = 0 if $zoom < 0;
        $zoom;
    };

    $c->stash->{map} = $self->get_map_hash( %params );

    if ($params{print_report}) {
        $params{zoom}++ unless $params{zoom} >= $zoom_params->{zoom_levels};
        $c->stash->{print_report_map}
            = $self->get_map_hash(
                %params,
                img_type => 'img',
                cols => 4, rows => 4,
            );
    }
}

sub get_map_hash {
    my ($self, %params) = @_;

    @params{'x_centre_tile', 'y_centre_tile'}
        = $self->latlon_to_tile_with_adjust(
            @params{'latitude', 'longitude', 'zoom', 'rows', 'cols'});

    $params{x_left_tile} = $params{x_centre_tile} - int($params{cols} / 2);
    $params{y_top_tile}  = $params{y_centre_tile} - int($params{rows} / 2);

    $params{pins} = [
        map {
            my $pin = { %$_ }; # shallow clone
            ($pin->{px}, $pin->{py})
                = $self->latlon_to_px($pin->{latitude}, $pin->{longitude},
                            @params{'x_left_tile', 'y_top_tile', 'zoom'});
            $pin;
        } @{ $params{pins} }
    ];

    my @scales = $self->scales;
    return {
        %params,
        type => $self->map_template,
        map_type => 'OpenLayers.Layer.WMS',
        tiles => $self->map_tiles( %params ),
        copyright => $self->copyright(),
        zoom => $params{zoom},
        zoomOffset => $self->zoom_parameters->{min_zoom_level},
        numZoomLevels => $self->zoom_parameters->{zoom_levels},
        tile_size => $self->tile_parameters->{size},
        tile_dpi => $self->tile_parameters->{dpi},
        tile_urls => encode_json( $self->tile_parameters->{urls} ),
        tile_suffix => $self->tile_parameters->{suffix},
        layer_names => encode_json( $self->tile_parameters->{layer_names} ),
        layer_style => $self->tile_parameters->{layer_style},
        map_projection => $self->tile_parameters->{projection},
        wms_version => $self->tile_parameters->{wms_version},
        format => $self->tile_parameters->{format},
        scales => encode_json( \@scales ),
    };
}

sub tile_base_url {
    my $self = shift;
    my $params = $self->tile_parameters;
    return sprintf '%s?version=%s&format=%s&size=%s&width=%s&height=%s&service=WMS&layers=%s&request=GetMap&srs=%s',
        $params->{urls}[0], $params->{wms_version}, $params->{format}, $params->{size}, $params->{size},
        $params->{size}, $params->{layer_names}[0], $params->{projection};
}

# Given a lat/lon, convert it to tile co-ordinates (precise).
sub latlon_to_tile($$$$) {
    my ($self, $lat, $lon, $zoom) = @_;

    my ($x, $y) = $self->reproject_from_latlon($lat, $lon);

    return ( $x, $y );
}

# Given a lat/lon, convert it to OSM tile co-ordinates (nearest actual tile,
# adjusted so the point will be near the centre of a 2x2 tiled map).
#
# Takes parameter for rows/cols.  For even sizes (2x2, 4x4 etc.) will
# do adjustment, but simply returns actual for odd sizes.
#
sub latlon_to_tile_with_adjust {
    my ($self, $lat, $lon, $zoom, $rows, $cols) = @_;
    my ($x_tile, $y_tile)
        = my @ret
        = $self->latlon_to_tile($lat, $lon, $zoom);

    # Try and have point near centre of map, passing through if odd
    my $tile_params = $self->tile_parameters;
    my @scales = $self->scales;
    my $res = $scales[$zoom] /
        ($tile_params->{inches_per_unit} * $tile_params->{dpi});


    $x_tile = $x_tile -  ($res * $tile_params->{size});
    $y_tile = $y_tile + ($res * $tile_params->{size});

    return ( int($x_tile), int($y_tile) );
}

# Given a lat/lon, convert it to pixel co-ordinates from the top left of the map
sub latlon_to_px($$$$$$) {
    my ($self, $lat, $lon, $x_tile, $y_tile, $zoom) = @_;
    my ($pin_x_tile, $pin_y_tile) = $self->latlon_to_tile($lat, $lon, $zoom);
    my $tile_params = $self->tile_parameters;
    my @scales = $self->scales;
    my $res = $scales[$zoom] /
        ($tile_params->{inches_per_unit} * $tile_params->{dpi});
    my $pin_x = ( $pin_x_tile - $x_tile ) / $res;
    my $pin_y = ( $y_tile - $pin_y_tile ) / $res;
    return ($pin_x, $pin_y);
}

sub click_to_tile {
    my ($self, $pin_tile, $pin, $zoom, $reverse) = @_;
    my $tile_params = $self->tile_parameters;
    my @scales = $self->scales;
    my $size = $tile_params->{size};
    my $res = $scales[$zoom] /
        ($tile_params->{inches_per_unit} * $tile_params->{dpi});

    return $reverse ? $pin_tile + ( ( $size - $pin ) * $res ) : $pin_tile + ( $pin * $res );
}

# Given some click co-ords (the tile they were on, and where in the
# tile they were), convert to WGS84 and return.
sub click_to_wgs84 {
    my ($self, $c, $pin_tile_x, $pin_x, $pin_tile_y, $pin_y) = @_;
    my $zoom = (defined $c->get_param('zoom') ? $c->get_param('zoom') : $self->zoom_parameters->{default_zoom});
    my $tile_x = $self->click_to_tile($pin_tile_x, $pin_x, $zoom);
    my $tile_y = $self->click_to_tile($pin_tile_y, $pin_y, $zoom, 1);
    my ($lat, $lon) = $self->reproject_to_latlon($tile_x, $tile_y);
    return ( $lat, $lon );
}

1;
