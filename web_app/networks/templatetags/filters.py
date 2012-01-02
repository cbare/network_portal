from django import template

register = template.Library()

@register.filter
def id(value):
    try:
        return [o.id for o in value]
    except:
        return value
