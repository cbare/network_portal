import datetime
from haystack.indexes import *
from haystack import indexes, site
from networks.models import Gene, Species, Chromosome, Network

class GeneIndex(indexes.SearchIndex):
    # text = CharField(document=True, use_template=True)
    text = indexes.CharField(document=True, use_template=True)
    species_name = CharField(model_attr='species__name')
    species_short_name = CharField(model_attr='species__short_name')
    chromosome = CharField(model_attr='chromosome__name')
    chromosome_length = IntegerField(model_attr='chromosome__length')
    chromosome_topology = CharField(model_attr='chromosome__topology')
    #gene_name = CharField(model_attr='name')
    gene_common_name = CharField(model_attr='common_name', null=True)
    gene_type = CharField(model_attr='type')
    gene_strand = CharField(model_attr='strand')
    gene_description = CharField(model_attr='description', null=True)
    # species_name_species = indexes.MultiValueField()
    # chromosome_name_chromosome = indexes.MultiValueField()
    # network_name = CharField(model_attr='network__name')
    # network_description = CharField(model_attr='network__description', null=True)
    # network_created_at = DateTimeField(model_attr='network__created_at')
    # condition_name = CharField(model_attr='condition__name')
    # influence_name = CharField(model_attr='influence__name')
    # influence_type = CharField(model_attr='influence__type')
    # bicluster_k = IntegerField(model_attr='bicluster__k')
    # bicluster_residual = IntegerField(model_attr='bicluster__residual')
    # motif_position = IntegerField(model_attr='motif__position')
    # motif_sites = IntegerField(model_attr='motif__sites')
    # motif_e_value = IntegerField(model_attr='motif__e_value')    
    # annotation_target_type = CharField(model_attr='annotation__target_type')
    # annotation_title = CharField(model_attr='annotation__title')
    # annotation_description = CharField(model_attr='annotation__description')
    # annotation_source = CharField(model_attr='annotation__source')

    def index_queryset(self):
        """Used when the entire index for model is updated."""
        return Gene.objects.all()

    # def prepare_chromosome_name_chromosome(self, obj):
    #    return [chromosome.chromosome_name_chromosome for chromosome in obj.chromosome_set.all()]

site.register(Gene, GeneIndex)

class SpeciesIndex(indexes.SearchIndex):
    text = indexes.CharField(document=True, use_template=True)
    species_name = indexes.CharField(model_attr='name')
    species_short_name = indexes.CharField(model_attr='short_name')
    gene_name = indexes.CharField(model_attr='gene__name')
    # name = indexes.CharField() #model_attr='network_name')
    #net_description = CharField(model_attr='network_description', null=True)
    #net_data_source = CharField(model_attr='network_data_source', null=True)
    #net_created_at = DateTimeField(model_attr='network_created_at')

    gene_name = indexes.MultiValueField()

    def prepare_gene_name(self, obj):
        return [Gene.name for Gene in obj.Gene.all()]

    #def prepare_name(self, obj):
    #    return obj.speciesfk.name
    #    return [gene.gene_name for gene in obj.gene_set.all()]

    #def prepare_net_description(self, obj):
    #    return obj.speciesfk.net_description

    #def prepare_net_data_source(self, obj):
    #    return obj.speciesfk.net_data_source

    #def prepare_net_created_at(self, obj):
    #    return obj.speciesfk.net_created_at

site.register(Species, SpeciesIndex)

class ChromosomeIndex(indexes.SearchIndex):
    text = indexes.CharField(document=True, use_template=True)
    chromosome = CharField(model_attr='name')
    chromosome_length = IntegerField(model_attr='length')
    chromosome_topology = CharField(model_attr='topology')

site.register(Chromosome, ChromosomeIndex)

class NetworkIndex(indexes.SearchIndex):
    text = indexes.CharField(document=True, use_template=True)
    network_name = CharField(model_attr='name')
    network_description = CharField(model_attr='description', null=True)
    network_data_source = CharField(model_attr='data_source', null=True)
    network_created_at = DateTimeField(model_attr='created_at')
#    species_name = CharField(model_attr='species__name')
#    species_short_name = CharField(model_attr='species__short_name')
   
site.register(Network, NetworkIndex)
