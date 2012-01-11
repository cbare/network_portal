var nwhelpers = {};

nwhelpers.showObject = function(obj) {
    var a = [];
    for (key in obj) {
        a.push(key + "=" + obj[key]);
    }
    return a.join(", ");
};

nwhelpers.show_msg = function(options) {
    if (typeof(options)=="string") {
        options = {message: options};
    }
    var options = $.extend({
        type: "info",
        target: "#output",
        heading: "Message"
    }, options);
    var msg = $("<div class=\"" + options.type + "_screen screen\">\
                 <div class=\"notification\">\
                 <div class=\"icon\"></div>\
                 <div class=\"heading\">" + (options.heading || "") + "</div>\
                 <div class=\"message\">" + (options.message || "") + "</div>\
                 </div>\
                 </div>");
    $(options.target).append(msg);
};


nwhelpers.pop_up1 = function(url, id) {
    $.ajax({
        url: url,
        success: function(html){
            $("#pop_up").html(html);
        },
        error: function(){
            $("#pop_up").html("<p>Error!!</p>");
        }
    });
};


nwhelpers.SHAPE_MAPPER = {
    attrName: 'type',
    entries:  [ { attrValue: 'gene', value: 'ELLIPSE' },
                { attrValue: 'bicluster', value: 'ROUNDRECT' },
                { attrValue: 'regulator', value: 'TRIANGLE' },
                { attrValue: 'motif', value: 'DIAMOND' } ]
};

nwhelpers.COLOR_MAPPER = {
    attrName: 'type',
    entries:  [ { attrValue: 'gene', value: '#ccffcc' },
                { attrValue: 'bicluster', value: '#f7f7f7' },
                { attrValue: 'regulator', value: '#ffcccc' },
                { attrValue: 'motif', value: '#ccccff'} ]
};

nwhelpers.VISUAL_STYLE = {
    global: {
        backgroundColor: "#FFFFFF"
    },
    nodes: {
        shape: { discreteMapper: nwhelpers.SHAPE_MAPPER },
        label: { passthroughMapper: { attrName: "name" } },
        color: { discreteMapper: nwhelpers.COLOR_MAPPER },
        borderWidth: 2,
        labelHorizontalAnchor: "center"
    },
    edges: {
        width: {
            defaultValue: 1,
            continuousMapper: { attrName: "weight", minAttrValue:0.0, maxAttrValue:1.0, minValue: 1, maxValue: 12 }
            //passthroughMapper: { attrName: "weight" }
        },
        color: "#0B94B1"
    }
};

function initCytoscapeWeb(swfPath, flashInstallerPath) {
    // id of Cytoscape Web container div
    var div_id = "cytoscapeweb";

    // initialization options
    var options = {
        // where you have the Cytoscape Web SWF
        swfPath: swfPath,
        // where you have the Flash installer SWF
        flashInstallerPath: flashInstallerPath,
        flashAlternateContent: "Cytoscape Web network viewer requires Flash."
    };

    // init and draw
    var vis = new org.cytoscapeweb.Visualization(div_id, options);
    // update gaggle data on selection events for the purpose of
    // broadcasting out lists of selected genes
    vis.addListener("select", "nodes", function(evt) {
        var selectedNodes = vis.selected("nodes");
    });
    return vis;
}
function addCytoscapeClickListener(vis, popup_func) {
    node_click_listener = vis.addListener("click", "nodes", function(event) {
        var data = event.target.data;
        var url;
        if (data.type=='gene') {
            url = "/gene/" + data.id + "?format=html";
        }
        else if (data.type=='regulator') {
            if (data.name.indexOf("~~") < 0) {
                url = "/gene/" + data.name + "?format=html"
            }
            else {
                url = "/regulator/" + data.name + "?format=html"
            }
        }
        else if (data.type=='bicluster') {
            pattern = /bicluster:(\d+)/;
            id = pattern.exec(data.id)[1];
            url = "/bicluster/" + id + "?format=html";
        }
        else if (data.type=='motif') {
            pattern = /motif:(\d+)/;
            id = pattern.exec(data.id)[1];
            url = "/motif/" + id + "?format=html";
        }
        else {
            return;
        }

        $("#pop_up").wijdialog({
            autoOpen: true,
            title: event.target.data.name,
            width: 600,
            open: function() { popup_func(url, id); }
        });
    });
    return vis;
}

nwhelpers.initBiclusterNetworkTab = function(biclusterId, djangoPSSM,
                                             swfPath, flashInstallerPath,
                                             popup_func) {
    var vis = initCytoscapeWeb(swfPath, flashInstallerPath);
    addCytoscapeClickListener(vis, popup_func);

    // load data
    $.ajax({
        url: "/network/graphml?biclusters=" + biclusterId,
        success: function(data){
            if (typeof data !== "string") { 
                if (window.ActiveXObject) { // IE 
                    data = data.xml; 
                }
                else { 
                    data = (new XMLSerializer()).serializeToString(data); 
                } 
            }
            vis.draw({network:data, visualStyle:nwhelpers.VISUAL_STYLE, layout:{name:'ForceDirected'}});
        },
        error: function(){
            nwhelpers.show_msg({
                type: "error",
                target:"#cytoscapeweb",
                message: "The file you specified could not be loaded. url=" + options.url,
                heading: "File not found",
            });
        }
    });
    nwhelpers.initCanvas(djangoPSSM);
    return vis;
};

nwhelpers.initNetworkTab = function(bicluster_count, geneName,
                                    swfPath, flashInstallerPath) {
    if (bicluster_count == 0) {
        $("#" + div_id).html("<p>No biclusters found for this gene.</p>")
        return;
    }
    var vis = initCytoscapeWeb(swfPath, flashInstallerPath);
    addCytoscapeClickListener(vis, nwhelpers.pop_up1);

    // load data
    $.ajax({
        url: "/network/graphml?gene=" + geneName,
        success: function(data){
            if (typeof data !== "string") { 
                if (window.ActiveXObject) { // IE 
                    data = data.xml; 
                }
                else { 
                    data = (new XMLSerializer()).serializeToString(data); 
                } 
            }
            vis.draw({network:data, visualStyle:nwhelpers.VISUAL_STYLE, layout:{name:'ForceDirected'}});
        },
        error: function(){
            nwhelpers.show_msg({
                type: "error",
                target:"#cytoscapeweb",
                message: "The file you specified could not be loaded. url=" + options.url,
                heading: "File not found",
            });
        }
    });
    return vis;
};

nwhelpers.initCanvas = function(django_pssm) {
    for (var motif_id in django_pssm)  {
        var pssm = { alphabet: ['A', 'C', 'T', 'G'],
                     values: django_pssm[motif_id]
                   };
        canvas_id = 'canvas_' + motif_id;
        var canvasOptions = {
            width: 300, //400,
            height: 150, //300,
            glyphStyle: '20pt Helvetica'
        };
        isblogo.makeLogo(canvas_id, pssm, canvasOptions);
    }
};
