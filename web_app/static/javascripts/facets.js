var Manager;

(function ($) {
  $(function () {
    Manager = new AjaxSolr.Manager({
      solrUrl: 'http://localhost:8983/solr/'
    });
    Manager.addWidget(new AjaxSolr.ResultWidget({
      id: 'result',
      target: '#docs'
    }));
    Manager.addWidget(new AjaxSolr.PagerWidget({
      id: 'pager',
      target: '#pager',
      prevLabel: '&lt;',
      nextLabel: '&gt;',
      innerWindow: 1,
      renderHeader: function(perPage, offset, total) {
        $('#pager-header').html($('<span/>').text('displaying' + Math.min(total, offset + 1) + ' to ' + Math.min(total, offset + perPage) + ' of ' + total));
      }
    }));
    var fields = [ 'species_name', 'species_short_name', 'condition_name', 'network_name', 'influence_name', 'influence_type', 'gene_common_name', 'gene_name' ];
    for (var i = 0, l = fields.length; i < l; i++) {
      Manager.addWidget(new AjaxSolr.TagcloudWidget({
        id: fields[i],
        target: '#' + fields[i],
        field: fields[i]
      }));
    }
    Manager.addWidget(new AjaxSolr.CurrentSearchWidget({
      id: 'currentsearch',
      target: '#selection'
    }));
    Manager.addWidget(new AjaxSolr.AutocompleteWidget({
      id: 'text',
      target: '#search',
      field: 'text',
      fields: [ 'species_name', 'species_short_name', 'condition_name', 'network_name', 'influence_name', 'influence_type', 'gene_common_name', 'gene_name' ] //[ 'name', 'gene_common_name', 'gene_name' ]
    }));
    Manager.init();
    Manager.store.addByValue('q', '*:*');
    var params = {
      facet: true,
      'facet.field': [ 'species_name', 'species_short_name', 'condition_name', 'network_name', 'influence_name', 'influence_type', 'gene_common_name', 'gene_name' ], //[ 'name', 'gene_common_name', 'gene_name' ],
      'facet.limit': 20,
      'facet.mincount': 1,
      'f.topics.facet.limit': 50,
      'json.nl': 'map'
    };
    for (var name in params) {
      Manager.store.addByValue(name, params[name]);
    }
    Manager.doRequest();
  });
})(jQuery);