(function ($) {

AjaxSolr.CheckboxWidget = AjaxSolr.AbstractFacetWidget.extend({
  afterRequest: function () {
    var links = [], selected = [], unselected = [];

/*
    var maxCount = 0;
    var objectedItems = [];
    for (var facet in this.manager.response.facet_counts.facet_fields[this.field]) {
      var count = parseInt(this.manager.response.facet_counts.facet_fields[this.field][facet]);
      if (count > maxCount) {
        maxCount = count;
      }
      objectedItems.push({ facet: facet, count: count });
    }
    objectedItems.sort(function (a, b) {
      return a.facet < b.facet ? -1 : 1;
    });

    $(this.target).empty();
    for(var i = 0, l = objectedItems.length; i < l; i++) {
      var value = objectedItems[i].facet + " (" + objectedItems[i].count + ")";
      var facet = objectedItems[i].facet;
      $(this.target).append(AjaxSolr.theme('list_items', value, parseInt(objectedItems[i].count/maxCount*10), self.clickHandler(facet)));
    }
*/

    for (var facet in this.manager.response.facet_counts.facet_fields[this.field]) {
      if (this.manager.store.find('fq', this.fq(facet))) {
        selected.push(facet);
      }
      else if (facet) {
        unselected.push(facet);
      }
    }

    selected.sort();
    for (var i = 0, l = selected.length; i < l; i++) {
      links.push(AjaxSolr.theme('unselect_link', selected[i], this.unclickHandler(selected[i])));
    }

    unselected.sort();
      for (var i = 0, l = unselected.length; i < l; i++) {
        links.push(AjaxSolr.theme('select_link', unselected[i], this.clickHandler(unselected[i])));
      }

    AjaxSolr.theme('list_items', this.target, links); // target is a <ul>
  }
});

})(jQuery);