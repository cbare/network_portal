(function ($) {

AjaxSolr.ResultWidget = AjaxSolr.AbstractWidget.extend({
  beforeRequest: function () {
    $(this.target).html($('<img/>').attr('src', '/static/images/indicator.gif'));
  },

  facetLinks: function (facet_field, facet_values) {
    var links = [];
    if (facet_values) {
      for (var i = 0, l = facet_values.length; i < l; i++) {
        links.push(AjaxSolr.theme('facet_link', facet_values[i], this.facetHandler(facet_field, facet_values[i])));
      }
    }
    return links;
  },

  facetHandler: function (facet_field, facet_value) {
    var self = this;
    return function () {
      self.manager.store.remove('fq');
      self.manager.store.addByValue('fq', facet_field + ':' + AjaxSolr.Parameter.escapeValue(facet_value));
      self.manager.doRequest(0);
      return false;
    };
  },

  afterRequest: function () {
    $(this.target).empty();
    for (var i = 0, l = this.manager.response.response.docs.length; i < l; i++) {
      var doc = this.manager.response.response.docs[i];
      // kmf added l as a passed parameter to the following call
      $(this.target).append(AjaxSolr.theme('result', doc, l, AjaxSolr.theme('snippet', doc)));

      var items = [];
      items = items.concat(this.facetLinks('species', doc.species_name));
      items = items.concat(this.facetLinks('species short name', doc.species_short_name));
      items = items.concat(this.facetLinks('condition name', doc.condition_name));
      items = items.concat(this.facetLinks('network name', doc.network_name));
      items = items.concat(this.facetLinks('influence name', doc.influence_name));
      items = items.concat(this.facetLinks('influence type', doc.influence_type));
      items = items.concat(this.facetLinks('gene common name', doc.gene_common_name));
      items = items.concat(this.facetLinks('gene name', doc.gene_name));
      AjaxSolr.theme('list_items', '#links_' + doc.id, items);
    }
  },

  init: function () {
    $('a.more').livequery(function () {
      $(this).toggle(function () {
        $(this).parent().find('span').show();
        $(this).text('less');
        return false;
      }, function () {
        $(this).parent().find('span').hide();
        $(this).text('more');
        return false;
      });
    });
  }
});

})(jQuery);