# Create your views here.
#from django.shortcuts import get_object_or_404, render_to_response
#from django.http import HttpResponseRedirect, HttpResponse
#from django.core.urlresolvers import reverse
#from django.template import RequestContext 
from web_app.networks.models import Gene

from django.template import RequestContext
from django.http import HttpResponse
from django.http import Http404
from django.core.exceptions import ObjectDoesNotExist
from django.shortcuts import render_to_response
from django.db.models import Q
from web_app.networks.models import Network
from web_app.networks.models import Species
from web_app.networks.models import Bicluster
import networkx as nx
import re
import sys, traceback


class Object(object):
    pass

def gene(request):
    #return render_to_response('analysis/gene.html')
    return render_to_response('analysis/gene.html', {}, context_instance=RequestContext(request))

# def network(request):
#     return HttpResponse("testing network")

def motif(request):
    return HttpResponse("testing motif")

def function(request):
    return HttpResponse("testing function")


def networks(request):
    networks = Network.objects.all()
    return render_to_response('networks.html', locals())

def network(request, network_id=None):
    network = Network.objects.get(id=network_id)
    biclusters = network.bicluster_set.all()
    return render_to_response('network.html', locals())

def network_cytoscape_web_test(request):
    network = Object()
    network.name = "Test Network"
    network.bicluster_ids = [2,152,299]
    return render_to_response('network_cytoscape_web.html', locals())

def network_cytoscape_web(request):
    network = Object()
    network.name = "Test Network"
    if request.GET.has_key('biclusters'):
        network.bicluster_ids = re.split( r'[\s,;]+', request.GET['biclusters'] )
    return render_to_response('network_cytoscape_web.html', locals())

def network_as_graphml(request):
    if request.GET.has_key('biclusters'):
        bicluster_ids = re.split( r'[\s,;]+', request.GET['biclusters'] )
    biclusters = Bicluster.objects.filter(id__in=bicluster_ids)

    # compile set of genes in all requested biclusters
    genes = set()
    influences = set()
    for b in biclusters:
        genes.update(b.genes.all())
        influences.update(b.influences.all())
        print "influences = %d" % (len(influences),)
        print influences

    # build networkx graph
    graph = nx.Graph()
    for gene in genes:
        graph.add_node(gene, {'type':'gene', 'name':str(gene)})
    for inf in influences:
        graph.add_node("inf:%d" % (inf.id), {'type':'regulator', 'name':inf.name})
    for bicluster in biclusters:
        graph.add_node(bicluster, {'type':'bicluster', 'name':str(bicluster)})
        for gene in bicluster.genes.all():
            graph.add_edge(bicluster, gene)
        for inf in bicluster.influences.all():
            graph.add_edge(bicluster, "inf:%d" % (inf.id))
            print ">>> " + str(inf)

    # write graphml to response
    writer = nx.readwrite.graphml.GraphMLWriter(encoding='utf-8',prettyprint=True)
    writer.add_graph_element(graph)
    response = HttpResponse(content_type='application/xml')
    writer.dump(response)

    return response

def species(request, species=None, species_id=None):
    try:
        if species:
            try:
                species_id = int(species)
                species = Species.objects.get(id=species_id)
            except ValueError:
                species = Species.objects.get(Q(name=species) | Q(short_name=species))
                # try aliases, too?
        elif species_id:
            species = Species.objects.get(id=species_id)
        elif request.GET.has_key('id'):
            species_id = request.GET['id']
            species = Species.objects.get(id=species_id)
        else:
            species = Species.objects.all()
            return render_to_response('species_list.html', locals())
        gene_count = species.gene_set.count()
        transcription_factors = species.gene_set.filter(transcription_factor=True)
        chromosomes = species.chromosome_set.all()
        return render_to_response('species.html', locals())
    except (ObjectDoesNotExist, AttributeError):
        exc_type, exc_value, exc_traceback = sys.exc_info()
        traceback.print_stack()
        traceback.print_exception(exc_type, exc_value, exc_traceback,
                              limit=2, file=sys.stdout)
        if species:
            raise Http404("Couldn't find species: " + str(species))
        elif species_id:
            raise Http404("Couldn't find species with id=" + species_id)
        else:
            raise Http404("No species specified.")

def genes(request, species=None, species_id=None):
    try:
        if species:
            try:
                species_id = int(species)
                species = Species.objects.get(id=species_id)
            except ValueError:
                species = Species.objects.get(Q(name=species) | Q(short_name=species))
                # try aliases, too?
        elif request.GET.has_key('id'):
                species_id = request.GET['id']
                species = Species.objects.get(id=species_id)
        genes = species.gene_set.all()
        gene_count = len(genes)
        return render_to_response('genes.html', locals())
    except (ObjectDoesNotExist, AttributeError):
        if species:
            raise Http404("Couldn't find genes for species: " + species)
        elif species_id:
            raise Http404("Couldn't find genes for species with id=" + species_id)
        else:
            raise Http404("No species specified.")

def bicluster(request, bicluster_id=None):
    bicluster = Bicluster.objects.get(id=bicluster_id)
    genes = bicluster.genes.all()
    gene_count = len(genes)
    influences = bicluster.influences.all()
    conditions = bicluster.conditions.all()
    return render_to_response('bicluster.html', locals())
