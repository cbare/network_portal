from django.template.loader import get_template
from django.template import Context
from django.http import HttpResponse
from django.http import Http404
from django.core.exceptions import ObjectDoesNotExist
from django.http import HttpResponseRedirect
from django.shortcuts import render_to_response
from django.template import RequestContext
from django.contrib.auth import logout
from django.contrib.csrf.middleware import csrf_exempt

from web_app.networks.models import *
from web_app.networks.functions import functional_systems

import search as s
import itertools
import urllib2

class GeneResultEntry:
    def __init__(self, id, name, species,
                 description, bicluster_ids):
        self.id = id
        self.name = name
        self.species = species
        self.description = description
        self.bicluster_ids = bicluster_ids


def home(request):
    genes = Gene.objects.all()
    bicl_count = Bicluster.objects.count()
    sp_count = Species.objects.count()
    net_count = Network.objects.count()
    motif_count = Motif.objects.count()
    influence_count = Influence.objects.count()
    version = "0.0.1"
    return render_to_response('home.html', locals())

def about(request):
    version = "0.0.1"
    return render_to_response('about.html', locals()) 

def contact(request):
    return render_to_response('contact.html', locals())

def search(request):
    if request.GET.has_key('q'):
        try:
            q = request.GET['q']
            results = s.search(q)
            gene_ids= []
            for result in results:
                if result['doc_type'] == 'GENE':
                    gene_ids.append(result['id'])

            gene_objs = Gene.objects.filter(pk__in=gene_ids)
            genes = []
            for gene_obj in gene_objs:
                bicluster_ids = [b.id for b in gene_obj.bicluster_set.all()]
                genes.append(GeneResultEntry(gene_obj.id, gene_obj.name,
                                             gene_obj.species.id,
                                             gene_obj.description,
                                             bicluster_ids))
        except Exception as e:
            error_message = str(e)
            
    return render_to_response('search.html', locals())

def logout_page(request):
    """
    Log users out and re-direct them to the main page.
    """
    logout(request)
    return HttpResponseRedirect('/')

def help(request):
    return render_to_response('help.html', locals())

def sviewer_cgi(request):
    """Proxy for the NCBI data CGIs"""
    def allowed_header(header):
        return header != 'transfer-encoding' and header != 'connection'
    base_url = 'http://www.ncbi.nlm.nih.gov/projects/sviewer/'
    script_name = request.path.split('/')[-1]
    proxied_url = base_url + script_name
    data = ''
    count = 0
    for key,value in request.REQUEST.items():
        if count > 0:
            data += '&'
        data += ("%s=%s" % (key, value))
        count += 1

    req = urllib2.Request(proxied_url)

    cookies = ''
    count = 0
    for key, value in request.COOKIES.items():
        if count > 0:
            cookies += '; '
        cookies += ("%s=%s" % (key, value))
   # if len(cookies) > 0:
   #     req.addHeader('Cookie', cookies)
    response = urllib2.urlopen(req, data)
    info = response.info()
    retresponse = HttpResponse(response.read())
    for key, value in info.items():
        if allowed_header(key.lower()):
            retresponse[key] = value
    return retresponse

sviewer_cgi = csrf_exempt(sviewer_cgi)
