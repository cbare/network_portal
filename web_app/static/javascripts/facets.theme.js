(function ($) {

// kmf has added functionality to get unique items within an array

var count = 0;
var total_output = '';
var total_output_sp = '';
var tab_output = '';
// end kmf 

AjaxSolr.theme.prototype.result = function (doc, l, snippet) {
  var output_header = '<table><tr><th>Gene Name</th><th>Common Name</th><th>Function</th><th>Type</th></tr>';
  var output_header_sp = '<table><tr><th>Species Name</th><th>Short Name</th></tr>';

  if (doc.doc_type == "GENE") {
     total_output += '<tr><td>' + doc.gene_name + '</td><td>' + doc.gene_common_name + '</td><td>' + doc.gene_description + '</td><td>' +  doc.gene_type + '</td></tr>';

/*
    var gene_name = doc.gene_name;
    var name = String(doc.gene_function_name).split(",");
    var type = String(doc.gene_function_type).split(",");
    var space = String(doc.gene_function_namespace).split(",");
    for (var x in name) {
    	total_output += '<tr><td>' + doc.gene_name + '</td><td>' + name[x] + '</td><td>' + type[x] + '</td><td>' +  space[x] + '</td></tr>';
    }
*/
  }

  if (doc.doc_type == "SPECIES") {
    total_output_sp += '<tr><td>' + doc.species_name + '</td><td>' + doc.species_short_name + '</td></tr>';
  }

  count++;

  if (count%10 == 0 || count == l) {

    var ncount = 0;
    if (count - 10 < 0) {
      ncount = 0;
    }
    else {
      ncount = count - 10;
    }

    total_output += '</table>';
    total_output_sp += '</table>';
    var new_total_output = total_output;
    var new_total_output_sp = total_output_sp;

    total_output = '';
    total_output_sp = '';

    if (count == l) {
      count = 0;
    }

    tab_output = '<script>$(function() {$("#results-tab").tabs();});</script><div id="results-tab"><ul><li><a href="#tabs-genes">Genes</a></li><li><a href="#tabs-species">Species</a></li></ul>'
                 + '<div id="tabs-genes"><div id="navigation"><ul id="pager"></ul><div id="pager-header"></div></div>' + output_header 
		 + new_total_output + '</div><div id="tabs-species">' + output_header_sp + new_total_output_sp + '</div></div>';

    return tab_output;

    //return output_header + new_total_output;
  }

};


AjaxSolr.theme.prototype.snippet = function (doc) {

  //console.debug("doc array = " + doc.toSource());

  var output = '';

  var condition_names = '';
  for (var i in doc.condition_name) {
    condition_names += doc.condition_name[i] + ',\n';
  }

  var influence_names = '';
  for (var i in doc.influence_name) {
    influence_names += doc.influence_name[i] + ',\n';
  }

  //if (doc.condition_name.length > 300) {
    output += '<div id="key">Network Name: </div><div id="result-value"><div id="value1">' + doc.network_name + '</div> - ' + doc.network_desc + '</div><br />';
    output += '<div id="key">Species Name (short name): </div><div id="result-value">' + doc.species_name + ' (' + doc.species_short_name + ')' + '</div><br />';
    output += '<span  style="display:none;"><div id="key">Condition Names: </div><div id="result-value">' + condition_names + '</div><br />';
    output += '<div id="key">Influence Names: </div><div id="result-value">' + influence_names + '</div><br />';
    output += '</span> <a href="#" class="more">more</a>';
    //output += '<span style="display:none;">' + doc.text; //name_auto
    //output += '</span> <a href="#" class="more">more</a>';
  //}
  //else {
  //  output += '<span id="key">Network Name: </span><span id="value1">' + doc.network_name + '</span> - ' + doc.network_desc + '><br />';
  //  output += '<span id="key">Species Name (short name): </span>' + doc.species_name + ' (' + doc.species_short_name + ')' + '<br />';
  //  output += '<span id="key">Condition Names: </span>' + '<div style="width:500px;">' + doc.condition_name.toString().split(",") + '</div><br />';
  //  output += '<span id="key">Influence Names: </span>' + '<div style="width:500px;">' + doc.influence_name.toString().split(",") + '</div><br />';

    //output += doc.dateline + ' ' + doc.text;
  //}
  return output;
};

AjaxSolr.theme.prototype.checkbox_l = function (text, handler, options) {
  options = options || {}, options.attributes = options.attributes || {};
  var attributes = '';
  for (var i in options.attributes) {
    attributes += ' '+ i +'="' + options.attributes[i] + '"';
  }
  return jQuery('<input type="checkbox" value="' + text + '"' + attributes + '/>').click(handler);
};

AjaxSolr.theme.prototype.select_link = function (facetText, handler) {
  var options = {};
  options.attributes = {};
  //facetText = facetText.escapeOnce();
  return jQuery('<label/>').append(AjaxSolr.theme('checkbox_l', facetText, handler, options)).append(facetText);
};

AjaxSolr.theme.prototype.unselect_link = function (facetText, handler) {
  var options = {};
  options.attributes = {};
  options.attributes.checked = 'checked';
  //facetText = facetText.escapeOnce();
  return jQuery('<label/>').append(AjaxSolr.theme('checkbox_l', facetText, handler, options)).append(facetText);
};

AjaxSolr.theme.prototype.facet_link = function (value, handler) {
  return $('<a href="#"/>').text(value).click(handler);
};

AjaxSolr.theme.prototype.no_items_found = function () {
  return 'no items found in current selection';
};  

})(jQuery);