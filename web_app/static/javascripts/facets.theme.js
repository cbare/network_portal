(function ($) {

AjaxSolr.theme.prototype.result = function (doc, snippet) {
  var output = '<div><h2>Bicluster ID ' + doc.bicluster_id + '</h2>';
  output += '<p id="links_' + doc.bicluster_id + '" class="links"></p>';
  output += snippet + '</div>';
  return output;
};

AjaxSolr.theme.prototype.snippet = function (doc) {
  var output = '';
  var condition_names = '';
  for (var i in doc.condition_name) {
    condition_names += doc.condition_name[i] + ',\n';
  }

  var influence_names = '';
  for (var i in doc.influence_name) {
    influence_names += doc.influence_name[i] + ',\n';
  }

  if (doc.condition_name.length > 300) {
    output += '<div id="key">Network Name: </div><div id="result-value"><div id="value1">' + doc.network_name + '</div> - ' + doc.network_desc + '</div><br />';
    output += '<div id="key">Species Name (short name): </div><div id="result-value">' + doc.species_name + ' (' + doc.species_short_name + ')' + '</div><br />';
    output += '<span  style="display:none;"><div id="key">Condition Names: </div><div id="result-value">' + condition_names + '</div><br />'; //doc.condition_name.toString().split(",") + '</div><br />';
    output += '<div id="key">Influence Names: </div><div id="result-value">' + influence_names + '</div><br />'; //doc.influence_name.toString().split(",") + '</div><br />';
    output += '</span> <a href="#" class="more">more</a>';
    //output += '<span style="display:none;">' + doc.text; //name_auto
    //output += '</span> <a href="#" class="more">more</a>';
  }
  else {
    output += '<span id="key">Network Name: </span><span id="value1">' + doc.network_name + '</span> - ' + doc.network_desc + '><br />';
    output += '<span id="key">Species Name (short name): </span>' + doc.species_name + ' (' + doc.species_short_name + ')' + '<br />';
    output += '<span id="key">Condition Names: </span>' + '<div style="width:500px;">' + doc.condition_name.toString().split(",") + '</div><br />';
    output += '<span id="key">Influence Names: </span>' + '<div style="width:500px;">' + doc.influence_name.toString().split(",") + '</div><br />';

    //output += doc.dateline + ' ' + doc.text;
  }
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