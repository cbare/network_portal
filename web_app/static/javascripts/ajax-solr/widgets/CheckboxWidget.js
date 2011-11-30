(function ($) {

AjaxSolr.CheckboxWidget = AjaxSolr.AbstractFacetWidget.extend({
  field: null,
  multivalue: true,
  init: function () {
    this.initStore();
  },

  initStore: function () {
    var parameters = [
      'facet.prefix',
      'facet.sort',
      'facet.limit', 
      'facet.offset', 
      'facet.mincount', 
      'facet.missing', 
      'facet.method', 
      'facet.enum.cache.minDf' 
    ]; 
    
    this.manager.store.addByValue('facet', true); 
    if (this['facet.field'] !== undefined) { 
      this.manager.store.add('facet.field', new 
      AjaxSolr.Parameter({ name: 'facet.field', value: this.field, locals: { ex: this.field } })); 
    } 
    else if (this['facet.date'] !== undefined) { 
      this.manager.store.addByValue('facet.date', this.field); 
      parameters = parameters.concat([ 
        'facet.date.start', 
        'facet.date.end', 
        'facet.date.gap', 
        'facet.date.hardend', 
        'facet.date.other', 
        'facet.date.include' 
      ]); 
    } 
    else if (this['facet.range'] !== undefined) { 
      this.manager.store.addByValue('facet.range', this.field); 
      parameters = parameters.concat([ 
        'facet.range.start', 
        'facet.range.end', 
        'facet.range.gap', 
        'facet.range.hardend', 
        'facet.range.other', 
        'facet.range.include' 
      ]); 
    } 

    for (var i = 0, l = parameters.length; i < l; i++) { 
      if (this[parameters[i]] !== undefined) { 
      	 this.manager.store.addByValue('f.' + this.field + '.' + 
	 parameters[i], this[parameters[i]]); 
      } 
    } 
  },
  isEmpty: function() {
    return !this.manager.store.find('fq', new RegExp('^-?' + this.field + ':'));
  }, 
  
  set: function (value) { 
       return this.changeSelection(function () { 
         var indices = this.manager.store.find('fq', new RegExp('^-?' + this.field + ':')); 
         if (indices) { 
            this.manager.store.params['fq'][indices[0]] = new 
	    AjaxSolr.Parameter({ name: 'fq', value: this.manager.store.params['fq'] 
	    [indices[0]].val() + ' OR ' + this.fq(value), locals: { tag: 
	    this.field } }); 
            return true; 
         } 
         else { 
	    return this.manager.store.add('fq', new 
	    AjaxSolr.Parameter({ name: 'fq', value: this.fq(value), locals: { tag: 
	    this.field } })); 
         } 
       }); 
  }, 
  
  add: function (value) { 
       return this.changeSelection(function () { 
         return this.manager.store.add('fq', new 
	 AjaxSolr.Parameter({ name: 'fq', value: this.fq(value), locals: { tag: 
	 this.field } })); 
       }); 
  }, 

  remove: function (value, field) { 
          var self = this; 
          return this.changeSelection(function () { 
            for (var i = 0, l = this.manager.store.params['fq'].length; i < l; i++) { 
                var mySplitResult = this.manager.store.params['fq'] [i].value.split(" OR "); 
                var count = mySplitResult.length; 
                for(var j = 0; j < mySplitResult.length; j++){ 
                   var v = field + ":" + value; 
                   if (value.match(" ") != null && mySplitResult[j].localeCompare(v) != 0 && mySplitResult[j].split(":") [0].localeCompare(field)===0) { 
                      value = '"' + value + '"'; 
                   } 
                   v = field + ":" + value; 
                   if (mySplitResult[j].localeCompare(v) == 0) { 
                      mySplitResult.splice(j,1); 
                      var str = mySplitResult.join(" OR "); 
                      if (count > 1) { 
                         this.manager.store.params['fq'][i].value = str; 
                      } else { 
                        this.manager.store.params['fq'].splice(i,1); 
                      } 
                      return true; 
                   } 
                } 
            } 
            return false; 
          }); 
  }, 

  clear: function () { 
         return this.changeSelection(function () { 
           return this.manager.store.removeByValue('fq', new RegExp('^-?' + this.field + ':')); 
         }); 
  }, 
  
  changeSelection: function (func) { 
                   changed = func.apply(this); 
                   if (changed) { 
                      this.afterChangeSelection(); 
                   } 
                   return changed; 
  }, 

  afterChangeSelection: function () {}, 

  getFacetCounts: function () { 
     var property; 
     if (this['facet.field'] !== undefined) { 
        property = 'facet_fields'; 
     } 
     else if (this['facet.date'] !== undefined) { 
       property = 'facet_dates'; 
     } 
     else if (this['facet.range'] !== undefined) { 
       property = 'facet_ranges'; 
     } 
     
     if (property !== undefined) { 
        switch (this.manager.store.get('json.nl').val()) { 
          case 'map': 
            return this.getFacetCountsMap(property); 
          case 'arrarr': 
            return this.getFacetCountsArrarr(property); 
          default: 
            return this.getFacetCountsFlat(property); 
     } 
  } 
  throw 'Cannot get facet counts unless one of the following properties is set to "true" on widget "' 
  + this.id + '":"facet.field", "facet.date", or "facet.range".'; 
  }, 

  getFacetCountsMap: function (property) { 
    var counts = []; 
    for (var facet in this.manager.response.facet_counts[property] [this.field]) { 
        counts.push({ 
	  facet: facet, 
          count: 
	  parseInt(this.manager.response.facet_counts[property][this.field] [facet]) 
        }); 
    } 
        return counts; 
  }, 

  getFacetCountsArrarr: function (property) { 
    var counts = []; 
    for (var i = 0, l = this.manager.response.facet_counts[property][this.field].length; i < l; i++) { 
        counts.push({ 
        	      facet: this.manager.response.facet_counts[property] [this.field][i][0], 
                      count: parseInt(this.manager.response.facet_counts[property][this.field][i] [1]) 
        }); 
    } 
        return counts; 
    }, 

    getFacetCountsFlat: function (property) { 
      var counts = []; 
      for (var i = 0, l = this.manager.response.facet_counts[property][this.field].length; i < l; i += 2) { 
          counts.push({ 
	  		facet: this.manager.response.facet_counts[property] [this.field][i], 
                        count: parseInt(this.manager.response.facet_counts[property][this.field][i+1]) 
          }); 
      } 
          return counts; 
    }, 

    clickHandler: function (value) { 
         var self = this, meth = this.multivalue ? 'add' : 'set'; 
         return function () { 
            if (self[meth].call(self, value)) { 
               self.manager.doRequest(0); 
            } 
               return false; 
         } 
    }, 

    unclickHandler: function (value, field) { 
         var self = this; 
         return function () { 
            if (self.remove(value, field)) { 
               self.manager.doRequest(0); 
            } 
               return false; 
            } 
    }, 

    fq: function (value, exclude) { 
        return (exclude ? '-' : '') + this.field + ':' + AjaxSolr.Parameter.escapeValue(value); 
    }, 

    init: function () { 
          this.manager.store.add('facet.field', new AjaxSolr.Parameter({ name: 
	  'facet.field', value: this.field, locals: { ex: this.field } })); 
    }, 


  afterRequest: function () {
    var links = [], selected = [], unselected = [];

    for (var facet in this.manager.response.facet_counts.facet_fields[this.field]) { 
        var count = parseInt(this.manager.response.facet_counts.facet_fields[this.field][facet]); 
        if (this.manager.store.find('fq', new RegExp(this.fq(facet)))) { 
                                   selected.push({ 
                                                   facet : facet, 
                                                   field : this.field, 
                                                   count : count 
                                   }); 
        } 
        else if (facet) { 
                                   unselected.push({ 
                                                   facet : facet, 
                                                   field : this.field, 
                                                   count : count 
                                   }); 
        } 
    } 
    selected.sort(); 
    for (var i = 0, l = selected.length; i < l; i++) { 
        links.push(AjaxSolr.theme('unselect_link', selected[i].facet + " (" + selected[i].count+ ")", 
	this.unclickHandler(selected[i].facet,selected[i].field))); 
    } 
    unselected.sort(); 
    for (var i = 0, l = unselected.length; i < l; i++) { 
        links.push(AjaxSolr.theme('select_link', unselected[i].facet +" (" + unselected[i].count + ")", this.clickHandler(unselected[i].facet))); 
    } 
    AjaxSolr.theme('list_items', this.target, links); // target is a <ul> 

/*
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
*/
  }
});

})(jQuery);