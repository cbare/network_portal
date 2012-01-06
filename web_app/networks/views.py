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
from web_app.networks.models import *
from web_app.networks.functions import functional_systems
from web_app.networks.helpers import nice_string
from pprint import pprint
import json
import networkx as nx
import re
import sys, traceback


class Object(object):
    pass

# I renamed this to make a gene page
def analysis_gene(request):
    #return render_to_response('analysis/gene.html')
    return render_to_response('analysis/gene.html', {}, context_instance=RequestContext(request))


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
        _network = Bicluster.objects.get(id=network.bicluster_ids[0]).network
        network.id = _network.id
    if request.GET.has_key('expand') and request.GET['expand']=='true':
        expand = "&expand=true"
    else:
        expand = ""
    return render_to_response('network_cytoscape_web.html', locals())

def network_as_graphml(request):
    if request.GET.has_key('biclusters'):
        bicluster_ids = re.split( r'[\s,;]+', request.GET['biclusters'] )
        biclusters = Bicluster.objects.filter(id__in=bicluster_ids)
    elif request.GET.has_key('gene'):
        biclusters = Bicluster.objects.filter(genes__name=request.GET['gene'])
    
    expand = request.GET.has_key('expand') and request.GET['expand']=='true'
    
    graph = nx.Graph()

    # compile sets of genes and influences from all requested biclusters
    genes = set()
    influences = set()
    for b in biclusters:
        genes.update(b.genes.all())
        influences.update(b.influences.all())

    # build networkx graph
    for gene in genes:
        graph.add_node(gene, {'type':'gene', 'name':gene.display_name()})
    for influence in influences:
        graph.add_node("inf:%d" % (influence.id,), {'type':'regulator', 'name':influence.name})
        
        # on request, we can add links for combiners (AND gates) to
        # the influences they're combining. This makes a mess of larger
        # networks, but works OK in very small networks (1-3 biclusters)
        if expand and influence.is_combiner():
            parts = influence.get_parts()
            for part in parts:
                if part not in influences:
                    graph.add_node("inf:%d" % (part.id,), {'type':'regulator', 'name':part.name, 'expanded':True})
                graph.add_edge("inf:%d" % (influence.id,), "inf:%d" % (part.id,), {'expanded':True})
        
    for bicluster in biclusters:
        graph.add_node("bicluster:%d" %(bicluster.id,), {'type':'bicluster', 'name':str(bicluster)})
        for gene in bicluster.genes.all():
            graph.add_edge("bicluster:%d" %(bicluster.id,), gene)
        for inf in bicluster.influences.all():
            graph.add_edge("bicluster:%d" %(bicluster.id,), "inf:%d" % (inf.id,))
            print ">>> " + str(inf)
        for motif in bicluster.motif_set.all():
            graph.add_node("motif:%d" % (motif.id,), {'type':'motif', 'consensus':motif.consensus(), 'e_value':motif.e_value, 'name':"motif:%d" % (motif.id,)})
            graph.add_edge("bicluster:%d" %(bicluster.id,), "motif:%d" % (motif.id,))

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
            network = Network.objects.all()
            return render_to_response('species_list.html', locals())

        networks = Network.objects.all()
        gene_count = species.gene_set.count()
        transcription_factors = species.gene_set.filter(transcription_factor=True)
        chromosomes = species.chromosome_set.all()
        organism_info = "organism_info/" + species.short_name + ".html"
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
        else:
            gene_count = Gene.objects.count()
            species_count = Species.objects.count()
            return render_to_response('genes_empty.html', locals())
        
        # handle filters or just get all genes for the species
        if request.GET.has_key('filter'):
            filter = request.GET['filter']
            if filter == 'tf':
                genes = species.gene_set.filter(transcription_factor=True)
        else:
            genes = species.gene_set.all()
        
        if request.GET.has_key('format'):
            format = request.GET['format']
            if format=='tsv':
                response = HttpResponse(content_type='application/tsv')
                for gene in genes:
                    response.write("\t".join([nice_string(field) for field in (gene.name, gene.common_name, gene.geneid, gene.type, gene.description, gene.location(),)]) + "\n")
                return response
        
        gene_count = len(genes)
        return render_to_response('genes.html', locals())
    except (ObjectDoesNotExist, AttributeError):
        raise
        # if species:
        #     raise Http404("Couldn't find genes for species: " + str(species))
        # elif species_id:
        #     raise Http404("Couldn't find genes for species with id=" + species_id)
        # else:
        #     raise Http404("No species specified.")

def gene(request, gene=None, network_id=None):
    if gene:
        try:
            gene_id = int(gene)
            gene = Gene.objects.get(id=gene_id)

        except ValueError:
            gene = Gene.objects.get(name=gene)
    elif request.GET.has_key('id'):
        gene_id = request.GET['id']
        gene = Gene.objects.get(id=gene_id)
    else:
        gene_count = Gene.objects.count()
        species_count = Species.objects.count()
        return render_to_response('genes_empty.html', locals())
    
    # TODO: need to figure out how to handle cases where there's more than one network
    if network_id:
        network_id = int(network_id)
    else:
        network = gene.species.network_set.all()[:1].get()
        network_id = network.id

    # get all biclusters that the gene is a member of
    member_bicluster = gene.bicluster_set.all()
    
    # list of IDs for biclusters that this gene belongs to
    bicluster_ids = [ b.id for b in gene.bicluster_set.all() ]

    # get regulatory influences for this gene
    influence_biclusters = []
    for bicluster in member_bicluster:
        for influence in bicluster.influences.all():
            influence_biclusters.append( (bicluster.id, influence) )
    influence_biclusters = sorted(influence_biclusters, key=lambda bi: (bi[0], bi[1].name) )
    
    # get neighbor genes
    neighbor_genes = gene.neighbor_genes(network_id)

    # compile functions into groups by functional system
    systems = []
    for key, functions in gene.functions_by_type().items():
        system = {}
        system['name'] = functional_systems[key].display_name
        system['functions'] = [ "(<a href=\"%s\">%s</a>) %s" % (function.link_to_term(), function.native_id, function.name,) \
                                for function in functions ]
        systems.append(system)
    
    # if the gene is a transcription factor, how many biclusters does it regulate?
    count_regulated_biclusters = gene.count_regulated_biclusters(network_id)
    
    if request.GET.has_key('format'):
        format = request.GET['format']
        if format == 'html':
            return render_to_response('gene_snippet.html', locals())
    
    return render_to_response('gene.html', locals())

def bicluster(request, bicluster_id=None):
    bicluster = Bicluster.objects.get(id=bicluster_id)
    genes = bicluster.genes.all()
    motifs = bicluster.motif_set.all()
    gene_count = len(genes)
    influences = bicluster.influences.all()
    conditions = bicluster.conditions.all()
    inf_count = len(influences)
    
    species_sh_name =  bicluster.network.species.short_name
    if (species_sh_name == "dvu"):
        img_url_prefix = "http://baliga.systemsbiology.net/cmonkey/enigma/cmonkey_4.8.2_dvu_3491x739_11_Mar_02_17:37:51/svgs/"
    elif (species_sh_name == "mmp"):
        img_url_prefix = "http://baliga.systemsbiology.net/cmonkey/enigma/mmp/cmonkey_4.8.8_mmp_1661x58_11_Oct_11_16:14:07/svgs/"
    else:
        img_url_prefix = "http://baliga.systemsbiology.net/cmonkey/enigma/hal/cmonkey_4.5.4_hal_2072x268_10_Jul_13_11:04:39_EGRIN1_ORIGINAL_CLUSTERS/svgs/"

    if (len(str(bicluster.k)) <= 1):
        cluster_id = "cluster000" + str(bicluster.k) 
    elif (len(str(bicluster.k)) <= 2): 
        cluster_id = "cluster00" + str(bicluster.k) 
    else:
        cluster_id = "cluster0" + str(bicluster.k) 

    img_url = img_url_prefix + cluster_id + ".svgz"
    print img_url

    # create motif object to hand to wei-ju's logo viewer
    alphabet = ['A','C','T','G']
    pssm_logo_dict = {}
    for m in motifs:
        motif = Motif.objects.get(id=m.id)
        pssm_list = []
        for positions in motif.pssm():
            position_list = []
            for pos, val in positions.items():
                position_list.append(val)
            pssm_list.append(position_list)

        pssm_logo = {'alphabet':alphabet, 'values':pssm_list }
        pssm_logo_dict[m.id] = pssm_list
        ret_pssm = json.JSONEncoder().encode(pssm_logo)

    if request.GET.has_key('format'):
        format = request.GET['format']
        if format == 'html':
            return render_to_response('bicluster_snippet.html', locals())

    # get the functions for a bicluster, filtering on a bonferroni p value cutoff of 0.05
    bicluster_functions = bicluster.bicluster_function_set.all()
    ret_bicl_functions = {}
    for f in bicluster_functions:
        function = Function.objects.get(id=f.function_id)
        if f.p_b <= 0.05:
            ret_bicl_functions[function.name] = f.gene_count
            print ", ".join([ str(x) for x in (function.type,
                                               function.namespace, function.name, f.gene_count, f.m, f.n, f.k, f.p,
                                               f.p_bh, f.p_b)])

    variables = locals()
    variables.update({'functional_systems':functional_systems})
    
    return render_to_response('bicluster.html', variables )

def regulated_by(request, network_id, regulator):
    gene = Gene.objects.get(name=regulator)
    network = Network.objects.get(id=network_id)
    biclusters = gene.regulated_biclusters(network)
    bicluster_ids = [bicluster.id for bicluster in biclusters]
    return render_to_response('biclusters.html', locals())

def regulator(request, regulator=None):
    influence = Influence.objects.get(name=regulator)
    parts = influence.parts.all()
    biclusters = influence.bicluster_set.all()
    return render_to_response('influence_snippet.html', locals())

def functions(request, type):
    system = None
    if type in functional_systems:
        system = functional_systems[type]
    return render_to_response('functions.html', locals())

def function(request, name):
    function = None
    if re.match("\d+", name):
        function = Function.objects.get(id=name)
    if function is None:
        function = Function.objects.get(native_id=name)
    if function is None:
        function = Function.objects.get(name=name)
    return render_to_response('function.html', locals())

def motif(request, motif_id=None):
    motif = Motif.objects.get(id=motif_id)
    return render_to_response('motif_snippet.html', locals())
