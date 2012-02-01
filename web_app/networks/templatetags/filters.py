from django import template
from django.utils.safestring import mark_safe

register = template.Library()

@register.filter
def id(value):
    try:
        return [o.id for o in value]
    except:
        return value

@register.filter
def bicluster_links(biclusters):
    return mark_safe(", ".join([ "<a href=\"/bicluster/%d\">%d</a>" % (b.id,b.id) for b in biclusters]))

@register.filter
def bicluster_id_links(bicluster_ids):
    return mark_safe(", ".join(["<a href=\"/bicluster/%d\">%d</a>" % (bid, bid) for bid in bicluster_ids]))

@register.filter
def lookup(dict, key):
    if key in dict:
        return dict[key]
    return ''

@register.filter
def search_result_map(species_genes, species_names):
    result = '<ul>'
    for species_id, genes in species_genes.items():
        result += ("<li><a href=\"#species_%d\">%d results</a> for '%s'</li>" % (species_id, len(genes), species_names[species_id]))
    return mark_safe(result + '</ul>')
