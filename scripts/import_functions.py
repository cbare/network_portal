"""
A script for importing function related data from various sources into the
network portal database.
"""

import argparse
import psycopg2
from species import species_dict
from open_struct import OpenStruct
import re


def read_kegg_pathways(filename):
    """
    Kegg has a "Download htext" button on the KEGG Orthology page. here, we're
    parsing that horrible format and extracting the pathways, their names and
    category and subcategory.
    Returns a nested list structure. At the top level are categories which are
    dictionaries with name and subcategories. Subcategories are dictionaries
    with name and pathways, which is a list containing dictionaries with a name
    and native_id.
    
    Example:
    [ {'name':'Metabolism',
       'subcategories': [
         {'name':'Carbohydrate Metabolism',
          'pathways':[
            {'native_id':'00010', 'name':'Glycolysis / Gluconeogenesis'},
            {'native_id':'00020', 'name':'Citrate cycle (TCA cycle)'},
            ...more pathways...
          ]},
         ...more subcategories...
       ]},
      ...more categories...
    ]
    """

    category_re = re.compile(r'A\s*<b>(.*)</b>\s*')
    subcategory_re = re.compile(r'B\s*<b>(.*)</b>\s*')
    pathway_re = re.compile(r'C\s*(\d+)\s+(.*)\s+(\[\w+:\w+\d+\])?')
    
    pathways = []
    category = None
    subcategory = None
    with open(filename, 'r') as f:
        for line in f:
            # skip header and footer junk
            if line.startswith('#') or line.startswith('!') or line.startswith('+'):
                continue

            # ignore spacer lines
            if len(line.strip()) <= 1:
                continue
            
            # NOTE: we remove commas 'cause the pathway names in the organism specific
            # file dvu_kegg_module_description.csv didn't have commas in them, for
            # example: Valine leucine and isoleucine biosynthesis vs.
            #          Valine, leucine and isoleucine biosynthesis
            # what a PITA
            
            line = line.rstrip('\n')
            if line.startswith('A'):
                m = category_re.match(line)
                if m:
                    category = {'name':m.group(1).replace(',', ''), 'subcategories':[]}
                    pathways.append(category)
                else:
                    raise Exception("Can't parse line: %s" % (line,))
            elif line.startswith('B'):
                m = subcategory_re.match(line)
                if m:
                    subcategory = {'name':m.group(1).replace(',', ''), 'pathways':[]}
                    category['subcategories'].append(subcategory)
                else:
                    raise Exception("Can't parse line: %s" % (line,))
            elif line.startswith('C'):
                m = pathway_re.match(line)
                if m:
                    subcategory['pathways'].append({'native_id':m.group(1), 'name':m.group(2).replace(',', '')})
                else:
                    raise Exception("Can't parse line: %s" % (line,))
    return pathways


def read_gene_kegg_pathways(filename):
    """
    Returns a map from gene name to a list of pathway names.
    """
    
    genes = {}
    with open(filename, 'r') as f:

        #skip header
        line = f.next()

        # read gene -> pathway mappings
        for line in f:
            line = line.rstrip('\n')
            fields = line.split(',')
            functions = [ field for field in fields[1:] if field != 'NA' ]
            if len(functions) > 0:
                genes[fields[0]] = functions

    return genes


def read_kegg_pathway_ids(filename):
    """
    Read kegg_pathway_ids.csv, which holds pathways for a particular organism.
    Return map from pathway name to pathway object
    """

    pathways = {}
    with open(filename, 'r') as f:

        #skip header
        line = f.next()

        # read gene -> pathway mappings
        for line in f:
            line = line.rstrip('\n')
            fields = line.split(',')
            m = re.match(r'path:(dvu\d+)', fields[0])
            if m:
                pathway = OpenStruct()
                pathway.native_id = m.group(1)
                pathway.name = fields[1]
                pathway.subcategory = fields[2]
                pathway.category = fields[3]
                pathways[pathway.name] = pathway
            else:
                raise Exception("Can't parse line: %s" % (line,))

    return pathways


def insert_kegg_pathways(pathways):
    """
    Insert KEGG pathways into DB.
    pathways: a nested list structure as returned by read_kegg_pathways(...).
    Note that we overload the namespace to distinguish between KEGG pathways
    and its system of categories and subcategories.
    """

    con = psycopg2.connect("dbname=network_portal user=dj_ango password=django")
    cur = None

    try:
        cur = con.cursor()

        added_count = 0
        for category in pathways:
            
            cur.execute("""
                insert into networks_function 
                (name, type, namespace)
                values (%s, %s, %s) RETURNING id;""",
                (category['name'],
                 'kegg',
                 'kegg category' ,))
            category_id = cur.fetchone()[0]
            
            for subcategory in category['subcategories']:
                
                cur.execute("""
                    insert into networks_function 
                    (name, type, namespace)
                    values (%s, %s, %s) RETURNING id;""",
                    (subcategory['name'],
                     'kegg',
                     'kegg subcategory' ,))
                subcategory_id = cur.fetchone()[0]
                    
                cur.execute("""
                    insert into networks_function_relationships
                    (function_id, target_id, type)
                    values (%s, %s, %s)
                    """,
                    (subcategory_id, category_id, 'parent'))
                
                for pathway in subcategory['pathways']:
                
                    cur.execute("""
                        insert into networks_function 
                        (native_id, name, type, namespace)
                        values (%s, %s, %s, %s) RETURNING id;""",
                        (pathway['native_id'],
                         pathway['name'],
                         'kegg',
                         'kegg pathway' ,))
                    function_id = cur.fetchone()[0]
                    
                    cur.execute("""
                        insert into networks_function_relationships
                        (function_id, target_id, type)
                        values (%s, %s, %s)
                        """,
                        (function_id, subcategory_id, 'parent'))
                    
                    added_count += 1
                    
        print "Added %d KEGG pathways to the DB." % (added_count,)

        con.commit()

    finally:
        if (cur): cur.close()
        if (con): con.close()


def insert_global_kegg_pathways():
    """
    Global pathways are listed on the pathways page: http://www.genome.jp/kegg/pathway.html
    ...but are not in the file we're loading the rest of the pathways from, so let's add
    them as an extra step, here.
    """
    
    # define the nested structure holding three global pathways
    pathways = [ {'name':'Global', 'subcategories':[
        {'name':'Metabolism',
         'pathways':[
             {'native_id':'01100', 'name':'Metabolic pathways'},
             {'native_id':'01110', 'name':'Biosynthesis of secondary metabolites'},
             {'native_id':'01120', 'name':'Microbial metabolism in diverse environments'}
         ]}
    ]}]
    
    insert_kegg_pathways(pathways)

# a lookup is a function that can translate its argument or leave it alone.
# substitutions are passed into the constructor as a dictionary
class Lookup:
    def __init__(self, dictionary={}):
            self.dictionary = dictionary
    def __call__(self, x):
        if x in self.dictionary:
            return self.dictionary[x]
        return x
    def __str__(self):
        return "Lookup table: " + str(self.dictionary)
    def __repr__(self):
        return __str__(self)

def insert_gene_kegg_function_associations(gene_kegg_pathways, species, translate_genes=Lookup()):

    con = psycopg2.connect("dbname=network_portal user=dj_ango password=django")
    cur = None

    try:
        cur = con.cursor()
        
        cur.execute("""
            select id from networks_species where name = %s;
            """,
            (species,))
        species_id = cur.fetchone()[0]

        # create functions id lookup table
        cur.execute("""
            select id, name from networks_function where type = 'kegg';
            """)
        functions = {}
        for row in cur:
            functions[row[1]] = row[0]
        
        # create gene id lookup table
        cur.execute("""
            select id,name from networks_gene where species_id=%s;
            """,
            (species_id,))
        genes = {}
        for row in cur:
            genes[row[1]] = row[0]
        
        gene_count = 0
        pathway_count = 0
        for gene in gene_kegg_pathways:
            pathways = gene_kegg_pathways[gene]
            gene_count += 1
            for pathway in pathways:

                if pathway in functions:
                    function_id = functions[pathway]
                else:
                    raise Exception("Unknown KEGG pathway: " + pathway)

                gene = translate_genes(gene)
                if gene in genes:
                    gene_id = genes[gene]
                else:
                    raise Exception("Unknown gene: " + gene)
                    
                cur.execute("""
                    insert into networks_gene_function
                    (function_id, gene_id, source)
                    values (%s, %s, %s)
                    """,
                    (function_id, gene_id, 'kegg'))
                pathway_count += 1
        print "Added %d genes to %d pathways." % (gene_count, pathway_count,)
        
        con.commit()

    finally:
        if (cur): cur.close()
        if (con): con.close()
        


def print_hierarchically(kegg_pathways):
    """
    KEGG pathways are organized into categories and subcategories. Print them
    as a hierarchy.
    """
    for category in kegg_pathways:
        print category['name']
        for subcategory in category['subcategories']:
            print "  " + subcategory['name']
            for pathway in subcategory['pathways']:
                print "    " + pathway['native_id'] + " " + pathway['name']


def main():
    parser = argparse.ArgumentParser(description='Import gene functions into the network portal\'s DB')
    #parser.add_argument('filenames', metavar='FILE', nargs='*', help='filenames containing function data')
    #parser.add_argument('--kegg', nargs=2, metavar=('GENE_KEGG_PATHWAY_FILE','KEGG_PATHWAY_IDS_FILE',), help='import KEGG pathways')
    parser.add_argument('--kegg-pathways', metavar='KEGG_PATHWAY_FILE', help='import all KEGG pathways')
    parser.add_argument('--kegg-gene-pathways', metavar='GENE_KEGG_PATHWAY_FILE', help='map genes to KEGG pathways')
    parser.add_argument('-s', '--species', help='for example, hal for halo')
    parser.add_argument('--test', action='store_true', help='Print list functions, rather than adding them to the db')
    parser.add_argument('--list-species', action='store_true', help='Print list of known species. You might have to add one.')
    args = parser.parse_args()
    
    # list known species and quit
    if args.list_species:
        for key in species_dict:
            print "%s => %s, %s" % (str(key), str(species_dict[key].name), str(species_dict[key].chromosome_map))
        return
    
    if args.species:
        print "species = " + args.species
        if args.species in species_dict:
            chromosome_map = species_dict[args.species].chromosome_map
            species = species_dict[args.species].name
        else:
            raise Exception("Don't know species: %s", args.species)
    elif not args.kegg_pathways:
        parser.print_help()
        print "\nPlease specify a species.\n"
        return
    
    # read and insert the master list of all KEGG pathways plus the global pathways
    if args.kegg_pathways:
        kegg_pathways = read_kegg_pathways(args.kegg_pathways)
        print "Read %d kegg pathways" % (len(kegg_pathways),)
        if args.test:
            print_hierarchically(kegg_pathways)
        else:
            insert_kegg_pathways(kegg_pathways)
            insert_global_kegg_pathways()
    
    # map genes to kegg pathways
    if args.kegg_gene_pathways:
        gene_kegg_pathways = read_gene_kegg_pathways(args.kegg_gene_pathways)
        if args.test:
            for gene in gene_kegg_pathways:
                pathways = gene_kegg_pathways[gene]
                for p in pathways:
                    print "%s : %s" % (gene, str(p))
        else:
            if species=='Desulfovibrio vulgaris Hildenborough':
                translate_genes = Lookup({'DVU_tRNA-SeC_p_-1':'DVU_tRNA-SeC(p)-1'})
            else:
                translate_genes = Lookup()
            insert_gene_kegg_function_associations(gene_kegg_pathways, species, translate_genes)


if __name__ == "__main__":
    main()
