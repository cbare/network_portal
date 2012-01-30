import urllib2
import urllib
from django.utils import simplejson

def make_query_string(q):
    """each search term automatically includes a wildcard at the end now"""
    return '+'.join([urllib.quote((comp + '*').encode('utf-8')) for comp in q.split(' ')])

def search(q):
    """We send our query directly to Solr without going through the sunburnt library.
    Sunburnt creates funny query strings which can lead to less than optimal results.
    """
    solr_url = 'http://localhost:8983/solr/select/'
    req = urllib2.Request(solr_url)
    query_string = make_query_string(q)
    response = urllib2.urlopen(solr_url, 'wt=json&q=' + query_string)
    resp = simplejson.loads(response.read())['response']
    start = resp['start']
    num_found = resp['numFound']
    docs = resp['docs']
    return docs
