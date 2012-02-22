// Javascript helper functions for Cytoscape Web display
var nwhelpers;
if (!nwhelpers) {
    nwhelpers = {};
}
(function () {
    "use strict";
    nwhelpers.load_popup = function (url, motifURL) {
        $.ajax({
            url: url,
            success: function (html) {
                $("#pop_up").html(html);
            },
            error: function () {
                $("#pop_up").html("<p>Error!!</p>");
            }
        });
        if (motifURL !== null) {
            $.ajax({
                url: motifURL,
                success: function (pssm) {
                    var options = {
                        width: 300,
                        height: 150,
                        glyphStyle: '20pt Helvetica'
                    };
                    isblogo.makeLogo("canvas", pssm, options);
                },
                error: function () {
                    $("#pop_up").html("<p>Error!!</p>");
                }
            });
        }
    };

    nwhelpers.show_msg = function (options) {
        if (typeof (options) === "string") {
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

    var defaultShapeMapper = {
        attrName: 'type',
        entries:  [ { attrValue: 'gene', value: 'ELLIPSE' },
                    { attrValue: 'bicluster', value: 'ROUNDRECT' },
                    { attrValue: 'regulator', value: 'TRIANGLE' },
                    { attrValue: 'motif', value: 'DIAMOND' } ]
    };

    var defaultColorMapper = {
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
            shape: { discreteMapper: defaultShapeMapper },
            label: { passthroughMapper: { attrName: "name" } },
            color: { discreteMapper: defaultColorMapper },
            borderWidth: 2,
            labelHorizontalAnchor: "center"
        },
        edges: {
            width: {
                defaultValue: 1,
                continuousMapper: { attrName: "weight", minAttrValue: 0.0, maxAttrValue: 1.0, minValue: 1, maxValue: 12 }
                //passthroughMapper: { attrName: "weight" }
            },
            color: "#0B94B1"
        }
    };

    nwhelpers.initCytoscapeWeb = function (swfPath, flashInstallerPath) {
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
        vis.addListener("select", "nodes", function (evt) {
            var selectedNodes = vis.selected("nodes");
        });
        return vis;
    };

    nwhelpers.addCytoscapeClickListener = function (vis, load_content) {
        var node_click_listener = vis.addListener("click", "nodes", function (event) {
            var data = event.target.data, url, motifURL = null;
            if (data.type === 'gene') {
                url = "/gene/" + data.id + "?format=html";
            } else if (data.type === 'regulator') {
                if (data.name.indexOf("~~") < 0) {
                    url = "/gene/" + data.name + "?format=html";
                } else {
                    url = "/regulator/" + data.name + "?format=html";
                }
            } else if (data.type === 'bicluster') {
                var pattern = /bicluster:(\d+)/;
                var id = pattern.exec(data.id)[1];
                url = "/bicluster/" + id + "?format=html";
            } else if (data.type === 'motif') {
                var pattern = /motif:(\d+)/;
                var id = pattern.exec(data.id)[1];
                url = "/motif/" + id + "?format=html";
                motifURL = "/json/pssm?motif_id=" + id;
            } else {
                return;
            }
            load_content(url, motifURL);
            $("#pop_up").wijdialog({
                autoOpen: true,
                title: event.target.data.name,
                width: 600
            });
        });
        return vis;
    };

    nwhelpers.initAndLoadCytoscapeWeb = function (dataURL, swfPath, flashInstallerPath, load_popup_content) {
        var vis = nwhelpers.initCytoscapeWeb(swfPath, flashInstallerPath);
        nwhelpers.addCytoscapeClickListener(vis, load_popup_content);

        // load data
        $.ajax({
            url: dataURL,
            success: function (data) {
                if (typeof data !== "string") {
                    if (window.ActiveXObject) { // IE 
                        data = data.xml;
                    } else {
                        data = (new XMLSerializer()).serializeToString(data);
                    }
                }
                vis.draw({network: data, visualStyle: nwhelpers.VISUAL_STYLE, layout: {name: 'ForceDirected'}});
            },
            error: function () {
                nwhelpers.show_msg({
                    type: "error",
                    target: "#cytoscapeweb",
                    message: "The file you specified could not be loaded. url=" + options.url,
                    heading: "File not found"
                });
            }
        });
        return vis;
    };

    nwhelpers.initBiclusterNetworkTab = function (biclusterId,
                                                  swfPath, flashInstallerPath,
                                                  load_popup_content) {
        var vis = nwhelpers.initAndLoadCytoscapeWeb("/network/graphml?biclusters=" + biclusterId,
                                                    swfPath, flashInstallerPath, load_popup_content);
        return vis;
    };

    nwhelpers.initNetworkTab = function (bicluster_count, geneName,
                                         swfPath, flashInstallerPath,
                                         load_popup_content) {
        if (bicluster_count === 0) {
            $("#" + div_id).html("<p>No biclusters found for this gene.</p>");
            return;
        }
        return nwhelpers.initAndLoadCytoscapeWeb("/network/graphml?gene=" + geneName,
                                                 swfPath, flashInstallerPath, load_popup_content);
    };

    nwhelpers.initCanvas = function (django_pssm) {
        var motif_id;
        for (motif_id in django_pssm)  {
            var pssm = { alphabet: ['A', 'C', 'T', 'G'],
                         values: django_pssm[motif_id]
                       };
            var canvas_id = 'canvas_' + motif_id;
            var canvasOptions = {
                width: 300, //400,
                height: 150, //300,
                glyphStyle: '20pt Helvetica'
            };
            isblogo.makeLogo(canvas_id, pssm, canvasOptions);
        }
    };

    nwhelpers.initCanvas2 = function (pssmMap, prefix, motifIds) {
        var i;
        for (i = 0; i < motifIds.length; i += 1) {
            var motifId = motifIds[i];
            var pssm = { alphabet: ['A', 'C', 'T', 'G'],
                         values: pssmMap[motifId]
                       };
            var canvas_id = prefix + motifId;
            var canvasOptions = {
                width: 220, //400,
                height: 120, //300,
                glyphStyle: '20pt Helvetica'
            };
            isblogo.makeLogo(canvas_id, pssm, canvasOptions);
        }
    };

}());