var vqhelpers;
if (!vqhelpers) {
    vqhelpers = {};
}
(function() {
    function makeGenomeParams(chromosomes) {
        var chromosomeNames = [];
        var chromosomeLengths = [];
        for (var i = 0; i < chromosomes.length; i += 1) {
            chromosomeNames.push(chromosomes[i].name);
            chromosomeLengths.push({
                'chr_name': chromosomes[i].name,
                'chr_length': chromosomes[i].length
            });
        }
        return {
            DATA: {
                key_order: chromosomeNames,
                key_length: chromosomeLengths
            },
            OPTIONS: {
              radial_grid_line_width: 2,
              label_layout_style: 'clock',
              label_font_style: '16px helvetica'
            }
        };
    }
    function makeWedgeParams(genes) {
        var geneValues = [];
        for (var i = 0; i < genes.length; i++) {
            geneValues.push({
                chr: genes[i].chr,
                start: genes[i].start,
                end: genes[i].end,
                options: 'label=p47.11,type=gneg',
                value: '#ff0000'
            });
        }
        return [{
            PLOT: {
                height: 10,
                type: 'karyotype'
            },
            DATA: {
                data_array: geneValues
            },
            OPTIONS: {
                legend_label: 'Halo !',
                legend_description: 'HALODESC',
                listener: function () { return null; },
                outer_padding: 10
            }
        }];
    }

    function makeNetworkParams(network) {
        return {
            DATA: {
                data_array: network
            },
            OPTIONS: {
                outer_padding : 10,
                node_highlight_mode : 'isolate',
                node_fill_style : 'steelblue',
                link_stroke_style : 'red',
                link_alpha : 0.3,
                node_key : function(node) { return vq.utils.VisUtils.options_map(node)['label'];},
                node_tooltip_items :  {
                    Chr : 'chr',
                    Start : 'start',
                    End : 'end',
                    Label : function(c) { return vq.utils.VisUtils.options_map(c)['label']; }
                },
                link_tooltip_items :  {
                    'Node 1 Chr' : 'sourceNode.chr', 'Node 1 Start' : 'sourceNode.start', 'Node 1 End' : 'sourceNode.end',
                    'Node 1 Label' : function(c) { return vq.utils.VisUtils.options_map(c.sourceNode)['label'];},
                    'Node 2 Chr' : 'targetNode.chr', 'Node 2 Start' : 'targetNode.start', 'Node 2 End' : 'targetNode.end',
                    'Node 2 Label' : function(c) { return vq.utils.VisUtils.options_map(c.targetNode)['label'];}
		}
            }
        };
    }

    vqhelpers.makeCircVisData = function (elem, chromosomes, genes, network) {
        var plotParams = {
            container: elem,
            width: 400,
            height: 300,
            vertical_padding: 10,
            horizontal_padding: 5,
            enable_pan: false,
            enable_zoom: false,
            show_legend: true,
            legend_corner: 'ne',
            legend_radius: 25
        };

        var data = {
            PLOT: plotParams,
            GENOME: makeGenomeParams(chromosomes),
            WEDGE: makeWedgeParams(genes),
            NETWORK: makeNetworkParams(network)
        };
        var result = {
            DATATYPE: 'vq.models.CircVisData',
            CONTENTS: data
        };
        return result;
    };
}());
