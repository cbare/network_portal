import datetime
from haystack.indexes import *
from haystack import indexes, site
from networks.models import Gene, Species, Chromosome

class GeneIndex(indexes.SearchIndex):
    # text = CharField(document=True, use_template=True)
    text = indexes.CharField(document=True, use_template=True)
    # species = CharField(model_attr='species__name')
    # species_short_name = CharField(model_attr='species__short_name')
    # chromosome = CharField(model_attr='chromosome__name')
    # chromosome_length = IntegerField(model_attr='chromosome__length')
    # chromosome_topology = CharField(model_attr='chromosome__topology')
    gene_name = CharField(model_attr='name')
    gene_common_name = CharField(model_attr='common_name', null=True)
    gene_type = CharField(model_attr='type')
    gene_strand = CharField(model_attr='strand')
    gene_description = CharField(model_attr='description', null=True)
    # species_name_species = indexes.MultiValueField()
    # chromosome_name_chromosome = indexes.MultiValueField()
    # network_name = CharField(model_attr='network__name')
    # network_description = CharField(model_attr='network__description')
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

    #def index_query(self):
    #    """Used when the entire index for model is updated."""
    #    return Gene.objects.filter(network_created_at__lte=datetime.datetime.now())

    # def prepare_chromosome_name_chromosome(self, obj):
    #    return [chromosome.chromosome_name_chromosome for chromosome in obj.chromosome_set.all()]

site.register(Gene, GeneIndex)

class SpeciesIndex(indexes.SearchIndex):
    text = indexes.CharField(document=True, use_template=True)
    species_name = CharField(model_attr='name')
    species_short_name = CharField(model_attr='short_name')
    #gene_name = indexes.MultiValueField()

    #def prepare_gene_name(self, obj):
    #    return [gene.gene_name for gene in obj.gene_set.all()]

site.register(Species, SpeciesIndex)

class ChromosomeIndex(indexes.SearchIndex):
    text = indexes.CharField(document=True, use_template=True)
    chromosome = CharField(model_attr='name')
    chromosome_length = IntegerField(model_attr='length')
    chromosome_topology = CharField(model_attr='topology')

site.register(Chromosome, ChromosomeIndex)
