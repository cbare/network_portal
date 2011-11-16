# a start on a deploy script
import fileinput


def replace_in_file(filename, old, new):
    """
    Replace all occurrences of old in the named file with new.
    """
    for line in fileinput.input(filename, inplace=1):
        print line.replace(old,new),


# In production, Solr will be proxied through apache (see httpd.conf)
# Here we adjust a couple of URLs to reflect that
dev_solr_url = "solrUrl: 'http://' + window.location.hostname + ':8983/solr/'"
production_solr_url = "solrUrl: 'http://' + window.location.hostname + '/solr/'"
replace_in_file("web_app/static/javascripts/facets.js", dev_solr_url, production_solr_url)

dev_solr_url = '''"http://" + window.location.hostname + ":8983/solr/suggest/?wt=json&json.wrf=?"'''
production_solr_url = '''"http://" + window.location.hostname + "/solr/suggest/?wt=json&json.wrf=?"'''
replace_in_file("web_app/templates/search.html", dev_solr_url, production_solr_url)
