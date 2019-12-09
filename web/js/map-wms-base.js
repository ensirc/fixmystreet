// Functionality required by all OpenLayers WMS base maps

fixmystreet.maps.setup_wms_base_map = function() {
    fixmystreet.map_type = OpenLayers.Layer.WMS;

    fixmystreet.map_options = {
        maxExtent: this.layer_bounds,
        units: 'm',
    };

    fixmystreet.layer_options = [];
    $.each(fixmystreet.wms_config.layer_names, function(i, v) {
        fixmystreet.layer_options.push({
            projection: new OpenLayers.Projection(fixmystreet.wms_config.map_projection),
            name: v,
            layer: v,
            formatSuffix: fixmystreet.wms_config.tile_suffix.replace(".", ""),
            requestEncoding: "REST",
            url: fixmystreet.wms_config.tile_urls[i],
            style: fixmystreet.wms_config.layer_style,
            layer_names: fixmystreet.wms_config.layer_names,
            wms_version: fixmystreet.wms_config.wms_version,
            format: fixmystreet.wms_config.format,
            tile_size: fixmystreet.wms_config.tile_size,
            scales: fixmystreet.wms_config.scales,
            tileOrigin: new OpenLayers.LonLat(fixmystreet.wms_config.origin_x, fixmystreet.wms_config.origin_y)
        });
    });
};
