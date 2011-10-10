from django.template.loader import get_template
from django.template import Context
from django.http import HttpResponse
from django.shortcuts import render_to_response


def home(request):
    return render_to_response('home.html', locals())

def about(request):
    return render_to_response('about.html', locals())
