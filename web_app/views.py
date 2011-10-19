from django.template.loader import get_template
from django.template import Context
from django.http import HttpResponse
from django.shortcuts import render_to_response
import search as s

def home(request):
    return render_to_response('home.html', locals())

def about(request):
    version = "0.0.1"
    return render_to_response('about.html', locals())

def search(request):
    if request.GET.has_key('q'):
        q = request.GET['q']
        results = s.search(q)
        bicluster_ids = [result['bicluster_id'] for result in results if 'bicluster_id' in result]
    return render_to_response('search.html', locals())
