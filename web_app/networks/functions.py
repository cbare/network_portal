# Define the 4 functional systems we use: KEGG, COG, TIGRFam, and GO
# For each system, define a name, display_name, top_level_categories,
# link to home, link to term, citation?, version?,
from models import Function
import re

class FunctionalSystem(object):
    def __init__(self):
        self.show_subcategories = False
    
    def top_level(self):
        return []
    
    def linked_description(self):
        return self.description.replace(self.display_name, "<a href=\"%s\">%s</a>" % (self.link_to_home, self.display_name,))

class KEGG(FunctionalSystem):
    def __init__(self):
        self.name = "kegg"
        self.display_name = "KEGG Pathways"
        self.link_to_home = "http://www.genome.jp/kegg/pathway.html"
        self.show_subcategories = True
        self.description = ("KEGG Pathways is a collection of manually drawn pathway maps "
                           "representing knowledge on molecular interaction and reaction networks.")

    def top_level(self):
        return Function.objects.filter(type='kegg',namespace='kegg category')

class GO(FunctionalSystem):
    def __init__(self):
        self.name = "go"
        self.display_name = "GO Gene Ontology"
        self.link_to_home = "http://www.geneontology.org/"
        self.description = ("The Gene Ontology project is a a controlled vocabulary of terms with "
                           "the aim of standardizing the representation of gene and gene product "
                           "attributes across species and databases.")
    
    def top_level(self):
        return Function.objects.filter(native_id__in=['GO:0003674', 'GO:0005575', 'GO:0008150'])
    
    def linked_description(self):
        return self.description.replace("Gene Ontology", "<a href=\"%s\">Gene Ontology</a>" % (self.link_to_home,))

class COG(FunctionalSystem):
    def __init__(self):
        self.name = "cog"
        self.display_name = "COG Clusters of Orthologous Groups"
        self.link_to_home = "http://www.ncbi.nlm.nih.gov/COG/"
        self.show_subcategories = True
        self.description = ("Clusters of Orthologous Groups (COG) is a phylogenetic "
                           "classification of proteins encoded in complete genomes.")
    
    def top_level(self):
        return Function.objects.filter(type='cog',namespace='cog category')
    
    def linked_description(self):
        return self.description.replace("Clusters of Orthologous Groups", "<a href=\"%s\">Clusters of Orthologous Groups</a>" % (self.link_to_home,))

class TIGR(FunctionalSystem):
    def __init__(self):
        self.name = "tigr"
        self.display_name = "TIGRFAMs"
        self.link_to_home = "http://www.jcvi.org/cgi-bin/tigrfams/index.cgi"
        self.show_subcategories = True
        self.description = ("TIGRFAMs is a system for protein sequence classification designed to "
                           "support automated annotation of (mostly prokaryotic) proteins.")
    
    def top_level(self):
        return Function.objects.filter(type='tigr',namespace='tigr mainrole')

functional_systems = {'kegg':KEGG(), 'go':GO(), 'cog':COG(), 'tigr':TIGR()}
