from django.template.loader import get_template
from django.template import Context
from django.http import HttpResponse
from django.http import HttpResponseRedirect
from django.shortcuts import render_to_response
from django.template import RequestContext
from django.contrib.auth import logout

import search as s
import itertools

def home(request):
    #return render_to_response('home.html', locals())
    return render_to_response('home.html', {}, context_instance=RequestContext(request))

def about(request):
    version = "0.0.1"
    return render_to_response('about.html', locals())

def contact(request):
    return render_to_response('contact.html', locals())

def search(request):
    if request.GET.has_key('q'):
        q = request.GET['q']
        results = s.search(q)
        bicluster_ids = []
        biclusters = []
        genes = []
        gene_functions = {}
        terms = []
        for result in results:
            if result['doc_type']=='BICLUSTER':
                biclusters.append(result)
                if 'bicluster_id' in result and result['bicluster_id'] not in bicluster_ids:
                    bicluster_ids.append(result['bicluster_id'])
            elif result['doc_type']=='GENE':
                # create sorted list of functions per gene; 
                # use if user wants to display Gene: Functions
                functions = zip(result['gene_function_type'], result['gene_function_name'])
                gene_functions[result['gene_name']] = functions
                ret = sorted(gene_functions.items())
                # create a list of unique functions found among the collection
                # of genes queried by user
                terms.append(result['gene_function_name'])
                terms_list = list(itertools.chain.from_iterable(terms))
                terms_lc = map(lambda x:x.lower(), terms_list)
                unique = set(terms_lc)
                unique = list(unique)
                unique.sort()
                # all gene results together
                genes.append(result)

    return render_to_response('search.html', locals())

def logout_page(request):
    """
    Log users out and re-direct them to the main page.
    """
    logout(request)
    return HttpResponseRedirect('/')
