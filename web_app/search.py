import sunburnt

def search(q):
    solr = sunburnt.SolrInterface("http://localhost:8983/solr/")
    results = solr.query(q).execute()
    return results
