(function ($) {

// kmf has added functionality to get unique items within an array
var bicl = new Array();
var species = new Array();
var network = new Array();

Array.prototype.getUnique = function() {
  var o = new Object();
  var i, e;

  for (i = 0; e = this[i]; i++) {
    o[e] = 1
  };
  
  var a = new Array();
  for (e in o) {
    a.push(e)
  };

  return a;
};


var count = 0;
// end kmf 

AjaxSolr.theme.prototype.result = function (doc, l, snippet) {

/*
  var output = '<div><h2>Bicluster ID ' + doc.bicluster_id + '</h2>';
  output += '<p id="links_' + doc.bicluster_id + '" class="links"></p>';
  output += snippet + '</div>';
*/

  bicl.push(doc.bicluster_id);
  species.push(doc.species_name);
  network.push(doc.network_name);

  count++;

  specu = species.getUnique(); 
  netwu = network.getUnique(); 
    
  var sp_length = specu.length;
  var ne_length = netwu.length;
  var bi_length = bicl.length;
  max = Math.max(sp_length, ne_length, bi_length);

  //console.debug("bicl array = " + bicl.toSource());
  //console.debug("spec array = " + specu.toSource());
  //console.debug("netw array = " + netwu.toSource());

  if (count%10 == 0 || count == l) {
    specu = species.getUnique(); 
    netwu = network.getUnique(); 
    
    var sp_length = specu.length;
    var ne_length = netwu.length;
    var bi_length = bicl.length;
    max = Math.max(sp_length, ne_length, bi_length);
    var ncount = 0;
    if (count - 10 < 0) {
      ncount = 0;
    }
    else {
      ncount = count - 10;
    }
    var total_output = '<table><tr><th>Bicluster ID</th><th>Species</th><th>Network</th></tr>';
    for (i = 0; i < max; i++) {
      // using species array instead of specu
      total_output += '<tr><td><a href="/bicluster/' + bicl[i] + '">' + bicl[i] + '</a></td><td><a href="/species/' + species[i] + '">' + species[i] + '</a></td><td>' +  netwu[i] + '</td></tr>';
    }

    total_output += '</table>';
    bicl.length = 0;
    species.length = 0;
    network.length = 0;

    if (count == l) {
      count = 0;
    }

    return total_output;
  }

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
    output += '<span  style="display:none;"><div id="key">Condition Names: </div><div id="result-value">' + condition_names + '</div><br />';
    output += '<div id="key">Influence Names: </div><div id="result-value">' + influence_names + '</div><br />';
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