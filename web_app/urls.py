from django.conf.urls.defaults import patterns, include, url

# Uncomment the next two lines to enable the admin:
from django.contrib import admin
admin.autodiscover()

urlpatterns = patterns('',
    # Examples:
    url(r'^$', 'web_app.views.home', name='home'),
    url(r'^about$', 'web_app.views.about', name='about'),
    url(r'^search', 'web_app.views.search', name='search'),

    url(r'^network/test/$', 'web_app.networks.views.network_cytoscape_web_test', name='network'),
    url(r'^network/xmltest/$', 'web_app.networks.views.network_as_graphml', name='network'),

    url(r'^networks/$', 'web_app.networks.views.networks', name='networks'),
    url(r'^network/graphml', 'web_app.networks.views.network_as_graphml', name='network'),
    url(r'^network', 'web_app.networks.views.network_cytoscape_web', name='network'),

    url(r'^species/(?P<species>.*)$', 'web_app.networks.views.species', name='species'),
    url(r'^species/$', 'web_app.networks.views.species', name='species'),
    url(r'^genes/(?P<species>.*)$', 'web_app.networks.views.genes', name='genes'),
    url(r'^genes/', 'web_app.networks.views.genes', name='genes'),
    url(r'^bicluster/(?P<bicluster_id>\d+)$', 'web_app.networks.views.bicluster', name='biclusters'),

    # Uncomment the admin/doc line below to enable admin documentation:
    # url(r'^admin/doc/', include('django.contrib.admindocs.urls')),

    # Uncomment the next line to enable the admin:
    url(r'^admin/', include(admin.site.urls)),
)
