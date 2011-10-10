from django.http import HttpResponse
from django.http import Http404
from django.core.exceptions import ObjectDoesNotExist
from django.shortcuts import render_to_response
from django.db.models import Q
from web_app.networks.models import Network
from web_app.networks.models import Species
from web_app.networks.models import Bicluster


def networks(request):
    networks = Network.objects.all()
    return render_to_response('networks.html', locals())

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
        chromosomes = species.chromosome_set.all()
        return render_to_response('species.html', locals())
    except (ObjectDoesNotExist, AttributeError):
        if species:
            raise Http404("Couldn't find species: " + species)
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


