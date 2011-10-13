from django.template.loader import get_template
from django.template import Context
from django.http import HttpResponse
from django.shortcuts import render_to_response


def home(request):
    return render_to_response('home.html', locals())

def about(request):
    return render_to_response('about.html', locals())

def search(request):
    if request.GET.has_key('q'):
        search_terms = request.GET['q']
        results=["...search results here...", "...more search results..."]
    return render_to_response('search.html', locals())
