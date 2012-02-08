/*
  Javascript helper functionality to support the dynamic behavior of search.
*/
var searchhelpers;
if (!searchhelpers) {
    searchhelpers = {};
}
(function() {

    function check_selection(geneMap, speciesId) {
        var selectBoxes = $('[id^=sel_gene_' + speciesId + ']');
        var selectedGenes = [];
        for (i = 0; i < selectBoxes.length; i++) {
            if (selectBoxes[i].checked) {
                var comps = selectBoxes[i].id.split('_');
                var geneId = comps[comps.length - 1];
                selectedGenes[selectedGenes.length] = geneMap[speciesId][geneId];
            }
        }
        if (selectedGenes.length === 0) {
            $('<div id="display-network_' + speciesId + '"></div>').replaceAll('#display-network_' + speciesId);
            return;
        }
        var biclusters = [];
        for (i = 0; i < selectedGenes.length; i++) {
            for (j = 0; j < selectedGenes[i].biclusters.length; j++) {
                if (biclusters.indexOf(selectedGenes[i].biclusters[j]) === -1) {
                    biclusters[biclusters.length] = selectedGenes[i].biclusters[j];
                }
            }
        }
        if (biclusters.length > 0) {
            var ids = biclusters.join(',');
            $('<div id="display-network_' + speciesId + '"><a href="/network?biclusters=' + ids + '">view network for selected regulons (' + biclusters.length + ')</a></div>').replaceAll('#display-network_' + speciesId);
        } else {
            $('<div id="display-network_' + speciesId + '"></div>').replaceAll('#display-network_' + speciesId);
        }
    }

    /*
     * Binds the check boxes in the result tables, so that a click on a select box
     * updates a link to display the network for the regulons for the selected genes.
     * geneMap is a Map that goes from species_id -> gene_id -> [bicluster_ids]
     */
    searchhelpers.bindResultTableEvents = function(geneMap) {
        $('[id^=sel_all_genes]').click(function(event) {
            var comps = event.target.id.split('_');
            var speciesId = comps[comps.length - 1];
            $('[id^=sel_gene_' + speciesId + ']').prop('checked', event.target.checked);
            check_selection(geneMap, speciesId);
        });
        $('[id^=sel_gene]').click(function(event) {
            var comps = event.target.id.split('_');
            var speciesId = comps[comps.length - 2];
            check_selection(geneMap, speciesId);
        });
    };
}());
