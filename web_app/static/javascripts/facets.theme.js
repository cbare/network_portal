(function ($) {

// kmf has added functionality to get unique items within an array

var count = 0;
var total_output = '';
// end kmf 

AjaxSolr.theme.prototype.result = function (doc, l, snippet) {
  var output_header = '<table><tr><th>Gene Name</th><th>Common Name</th><th>Function</th><th>Type</th></tr>';

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
    var new_total_output = total_output;

    total_output = '';

    if (count == l) {
      count = 0;
    }

    return output_header + new_total_output;
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

AjaxSolr.theme.prototype.tag = function (value, weight, handler) {
  return $('<a href="#" class="tagcloud_item"/>').text(value).addClass('tagcloud_size_' + weight).click(handler);
};

AjaxSolr.theme.prototype.facet_link = function (value, handler) {
  return $('<a href="#"/>').text(value).click(handler);
};

AjaxSolr.theme.prototype.no_items_found = function () {
  return 'no items found in current selection';
};

})(jQuery);