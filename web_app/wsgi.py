import os
import sys
import django

# print >> sys.stderr,"\n"*4                                                                              
# print >> sys.stderr,"~"*100                                                                             
# print >> sys.stderr,"Django version = " + str(django.VERSION)                                           
# print >> sys.stderr,"Python version = " + str(sys.version_info)                                         
# print >> sys.stderr,"~"*100                                                                             

path = os.path.dirname(os.path.dirname(__file__)).replace('\\','/')
if path not in sys.path:
    sys.path.append(path)

os.environ['DJANGO_SETTINGS_MODULE'] = 'web_app.settings'

import django.core.handlers.wsgi
application = django.core.handlers.wsgi.WSGIHandler()
