(function(){

if (!fixmystreet.maps) {
    return;
}

var highways_style = new OpenLayers.Style({
    fill: false,
    strokeOpacity: 0.8,
    strokeWidth: 4
});
function is_motorway(f) {
    return f &&
           f.attributes &&
           f.attributes.ROA_NUMBER &&
           f.attributes.ROA_NUMBER.indexOf('M') > -1;
}
function is_a_road(f) {
    return !is_motorway(f);
}
var rule_motorway = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: is_motorway
    }),
    symbolizer: {
        strokeColor: "#0079C1"
    }
});
var rule_a_road = new OpenLayers.Rule({
    filter: new OpenLayers.Filter.FeatureId({
        type: OpenLayers.Filter.Function,
        evaluate: is_a_road
    }),
    symbolizer: {
        strokeColor: "#00703C"
    }
});
highways_style.addRules([rule_motorway, rule_a_road]);
var highways_stylemap = new OpenLayers.StyleMap({
    'default': highways_style
});

fixmystreet.highways_layer.styleMap = highways_stylemap;

})();
