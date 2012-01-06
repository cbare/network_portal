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
    return mark_safe(", ".join( [ "<a href=\"/bicluster/%d\">%d</a>" % (b.id,b.id) for b in biclusters ] ))
