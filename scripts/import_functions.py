"""
A collection of utilities controlled by command-line args for importing
function related data from various sources into the network portal database.

This script populates the tables: networks_function, networks_gene_function,
and networks_function_relationships. It's structured as a bunch of methods
that read particular file formats and return lists or hierarchies of
objects. Then, there are a corresponding bunch of methods that take the
objects produced by the readers and insert them into the database.

examples:
python import_functions.py --kegg-pathways ../../data/ko00001.keg
python import_functions.py --go-terms ../../data/gene_ontology_ext.obo.txt
python import_functions.py --cogs ../../data/COG_whog
python import_functions.py --tigrfams-by-role ../../data/tigrfams_by_role.txt
python import_functions.py --tigrfams ../../data/cmr_tigrfam_table.txt
python import_functions.py --species dvu --kegg-gene-pathways ../../data/dvu/DvH_Annotations_kegg/dvu_gene_kegg_pathway2_attributes.csv
python import_functions.py --species dvu --genome-info ../../data/dvu/genomeInfo.microbesonline.txt
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
    count_pathways = 0
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
                    count_pathways += 1
                else:
                    raise Exception("Can't parse line: %s" % (line,))
    
    print "Read %d kegg pathways" % (count_pathways,)
    
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


def read_microbes_online_genome_info(filename):
    """
    Read a genomeInfo.txt file from microbes online.
    Return a list of gene objects.
    """
    with open(filename, 'r') as f:
        
        # we'll be making and returning a list of gene objects
        genes = []
        
        # read header and create map from column name to index
        # these files have these columns: locusId, accession, GI, scaffoldId, start, stop, strand,
        # sysName, name, desc, COG, COGFun, COGDesc, TIGRFam, TIGRRoles, GO, EC, ECDesc
        column_names = f.next().rstrip("\n").split("\t")
        column = { column_names[index]:index for index in range(0,len(column_names)) }
        
        for line in f:
            fields = line.rstrip("\n").split("\t")
            
            # create an object for each row
            gene = OpenStruct()
            for column_name in column_names:
                gene[column_name] = fields[ column[column_name] ]
            genes.append(gene)
        
    return genes


def read_go_terms(filename):
    """
    Read a file of GO (gene ontology) terms and return a list of term objects.
    Based on the ontology file OBO v1.2 downloaded from http://www.geneontology.org/.
    format-version: 1.2
    date: 27:10:2011 14:45
    saved-by: gwg
    auto-generated-by: OBO-Edit 2.1-rc2
    remark: cvs version: $Revision: 1.2357 $
    keys are in { id, alt_id,
                  name, namespace,
                  def, comment,
                  created_by, creation_date,
                  is_obsolete, replaced_by, consider,
                  synonym, is_a, subset, disjoint_from, relationship, intersection_of,
                  xref }
    """

    # See format description: http://www.geneontology.org/GO.format.obo-1_2.shtml#S.1.1
    # Tag-Value Pairs:
    #   <tag>: <value> {<trailing modifiers>} ! <comment>
    # Trailing Modifiers
    # {<name>=<value>, <name=value>, <name=value>}

    # we'll be making and returning a list of term objects
    terms = []

    with open(filename, 'r') as f:
        
        in_term_stanza = False
        # match quoted string values
        quoted_string_re = re.compile(r'"((?:[^"\\]|\\.)*)"(?:\s+(.*?))?')
        
        for line in f:
            
            line = line.rstrip("\n")
            if in_term_stanza:
                if line=="":
                    # blank line ends stanza
                    in_term_stanza = False
                else:
                    # capture a key/value pair
                    [key,rest] = line.split(': ',1)
                    # remove comments
                    comment_index = rest.rfind(' ! ')
                    if comment_index > -1:
                        value = rest[0:comment_index]
                    else:
                        value = rest
                    
                    # deal with quoted strings
                    # here, we're implicitely dropping suffixes from synonym and def
                    # lines that look like these:
                    # EXACT [GOC:obol]
                    # EXACT [EC:4.1.1.18]
                    # BROAD [EC:1.1.5.4]
                    # NARROW [EC:2.7.8.7]
                    # [GOC:bf, GOC:signaling, PMID:15084302, PMID:17662591]
                    m = quoted_string_re.match(value)
                    if m:
                        value = m.group(1)
                    
                    term.set_or_append(key,value)
            
            elif line=="[Term]":
                in_term_stanza = True
                term = OpenStruct()
                terms.append(term)

    return terms


def read_tigrfams_by_role(filename):
    """
    Reads the hierarchical structure of TIGRFams organized into categories called roles.
    Returns a nested list structure of roles and sub-roles that hold tigrfams.
    Downloaded file from here: http://cmr.jcvi.org/tigr-scripts/CMR/shared/EvidenceList.cgi?ev_type=TIGRFAM&order_type=role
    Note the TIGRFams flat file is more complete than the TIGRFams by role file.
    """
    # we'll be making and returning a nested list of tigr roles holding tigrfams
    tigrfams_by_role = []

    with open(filename, 'r') as f:
        
        category = None
        subcategory = None
        
        for line in f:
            
            # skip blank lines
            if len(line.strip())==0:
                continue
            
            if line.startswith("      "):
                fields = line.lstrip(' ').rstrip("\n").split("\t")
                # skip column headers
                if fields[0] == 'Accession':
                    continue
                tigrfam = OpenStruct()
                tigrfam.id = fields[0]
                tigrfam.name = fields[1]
                tigrfam.description = fields[2]
                subcategory['tigrfams'].append(tigrfam)
            elif line.startswith("   "):
                name = line.strip()
                subcategory = {'name':name, 'tigrfams':[]}
                category['roles'].append(subcategory)
            else:
                name = line.strip()
                category = {'name':name, 'roles':[]}
                tigrfams_by_role.append(category)
        
    return tigrfams_by_role


def read_tigrfams(filename):
    """
    Read the flat listing of TIGRFams.
    Note the TIGRFams flat file is more complete than the TIGRFams by role file.
    The flat file is a superset of the by-role file.
    """
    tigrfams = []
    with open(filename, 'r') as f:

        #skip header
        line = f.next()

        for line in f:
            fields = line.rstrip("\n").split("\t")
            tigrfam = OpenStruct()
            tigrfam.id = fields[0]
            tigrfam.name = fields[1]
            tigrfam.description = fields[2]
            tigrfams.append(tigrfam)

    return tigrfams


def read_cogs(filename):
    """
    Read COG functions.
    """
    cog_re = re.compile(r'\[\w+\]\s+(COG\d+)\s+(.*)')
    cogs = []
    with open(filename, 'r') as f:
        for line in f:
            m = cog_re.match(line)
            if m:
                cog = OpenStruct()
                cog.id = m.group(1)
                cog.description = m.group(2)
                cogs.append(cog)
    return cogs


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

def get_species_id(cur, name):
    cur.execute("""
        select id from networks_species where name = %s;
        """,
        (name,))
    return cur.fetchone()[0]


def get_gene_id_lookup_table(cur, species_id):
    """
    create lookup table for finding gene id by name
    """
    cur.execute("""
        select id, name from networks_gene where species_id=%s;
        """,
        (species_id,))
    gene_ids = {}
    for row in cur:
        gene_ids[row[1]] = row[0]
    return gene_ids


def get_function_id_lookup_table(cur, type):
    """
    Create a dictionary for looking up function IDs by their native_id, the ID
    used within the system, for example 'GO:0001934'.
    """
    cur.execute("""
        select id, native_id from networks_function where type = %s;
        """, (type,))
    function_ids = {}
    for row in cur:
        function_ids[row[1]] = row[0]
    return function_ids


def get_go_function_id_lookup_table(cur):
    """
    Create a dictionary for looking up GO function IDs by their native_id or alt_id
    """
    function_ids = get_function_id_lookup_table(cur, 'go')   
    cur.execute("""
        select target_id, name from networks_synonym where target_type='function' and type = 'go:alt_id';
        """, (type,))
    for row in cur:
        # it should never happen that an alt_id is also an id, but check anyway.
        if row[1] not in function_ids:
            function_ids[row[1]] = row[0]
        else:
            print "Warning: duplicate function ID " + row[1]
    return function_ids


class Lookup:
    """
    A lookup is a function that can translate its argument or leave it alone.
    Substitutions are passed into the constructor as a dictionary.
    """
    
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
    """
    Insert mappings from genes to KEGG pathways.
    gene_kegg_pathways: a map from gene name to a list of pathways as returned by read_gene_kegg_pathways
    species: the name of a species in the database
    translate_genes: a function that takes a gene name and returns the name of
    a gene in the database. Some gene names will need to be translated.
    """

    con = psycopg2.connect("dbname=network_portal user=dj_ango password=django")
    cur = None

    try:
        cur = con.cursor()
        
        species_id = get_species_id(cur, species)
        
        # create functions id lookup table
        cur.execute("""
            select id, name from networks_function where type = 'kegg';
            """)
        functions = {}
        for row in cur:
            functions[row[1]] = row[0]
        
        # create gene id lookup table
        genes = get_gene_id_lookup_table(cur, species_id)
        
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


def insert_go_terms(terms):
    """
    Takes a list of term objects as returned by read_go_terms and inserts
    them into the DB. Also inserts relationships.
    """
    con = psycopg2.connect("dbname=network_portal user=dj_ango password=django")
    cur = None

    try:
        cur = con.cursor()
        
        # insert go terms
        ids = {}
        for term in terms:
            cur.execute("""
                insert into networks_function 
                (native_id, name, namespace, description, type)
                values (%s, %s, %s, %s, %s) RETURNING id;""",
                (term.id,
                 term.name,
                 term.namespace,
                 term['def'],
                 'go',))
            function_id = cur.fetchone()[0]
            ids[term.id] = function_id
        
        # second pass to insert relationships
        # keys are in { id, alt_id,
        #               name, namespace,
        #               def, comment,
        #               created_by, creation_date,
        #               is_obsolete, replaced_by, consider,
        #               synonym, is_a, subset, disjoint_from, relationship, intersection_of,
        #               xref }
        count_is_a = 0
        count_relationships = 0
        for term in terms:
            function_id = ids[term.id]
            if 'is_a' in term:
                for parent in term.get_as_list('is_a'):
                    target_id = ids[parent]
                    cur.execute("""
                        insert into networks_function_relationships
                        (function_id, target_id, type)
                        values (%s, %s, %s)
                        """,
                        (function_id, target_id, 'is_a',))
                    count_is_a += 1
            if 'relationship' in term:
                for value in term.get_as_list('relationship'):
                    # so far as I've seen, relationships are of the form: [relation] GO:\d+
                    [relation, target] = value.split(' ', 1)
                    target_id = ids[target]
                    cur.execute("""
                        insert into networks_function_relationships
                        (function_id, target_id, type)
                        values (%s, %s, %s)
                        """,
                        (function_id, target_id, relation,))
                    count_relationships += 1
            if 'alt_id' in term:
                for alt_id in term.get_as_list('alt_id'):
                    cur.execute("""
                        insert into networks_synonym
                        (target_id, target_type, name, type)
                        values (%s, %s, %s, %s)
                        """,
                        (function_id, 'function', alt_id, 'go:alt_id',))

        con.commit()
        print "Inserted %d is_a relationships and %d other relationships." % (count_is_a, count_relationships,)

    finally:
        if (cur): cur.close()
        if (con): con.close()


def insert_tigrfams_by_role(tigrfams):
    """
    Insert TIGRFams organized by role.
    tigrfams: a nested list structure as returned by read_tigrfams_by_role(...).
    Note that we overload the namespace to distinguish between TIGRFams and roles.
    Note the TIGRFams flat file is more complete than the TIGRFams by role file.
    """

    con = psycopg2.connect("dbname=network_portal user=dj_ango password=django")
    cur = None

    try:
        cur = con.cursor()

        added_count = 0
        for category in tigrfams:

            cur.execute("""
                insert into networks_function 
                (name, type, namespace)
                values (%s, %s, %s) RETURNING id;""",
                (category['name'],
                 'tigr',
                 'tigr category' ,))
            category_id = cur.fetchone()[0]

            for subcategory in category['roles']:

                cur.execute("""
                    insert into networks_function 
                    (name, type, namespace)
                    values (%s, %s, %s) RETURNING id;""",
                    (subcategory['name'],
                     'tigr',
                     'tigr role' ,))
                subcategory_id = cur.fetchone()[0]

                # link role to category
                cur.execute("""
                    insert into networks_function_relationships
                    (function_id, target_id, type)
                    values (%s, %s, %s)
                    """,
                    (subcategory_id, category_id, 'parent'))

                for tigrfam in subcategory['tigrfams']:

                    cur.execute("""
                        insert into networks_function 
                        (native_id, name, description, type, namespace)
                        values (%s, %s, %s, %s, %s) RETURNING id;""",
                        (tigrfam.id,
                         tigrfam.name,
                         tigrfam.description,
                         'tigr',
                         'tigrfam' ,))
                    function_id = cur.fetchone()[0]

                    # link TIGRFam to role
                    cur.execute("""
                        insert into networks_function_relationships
                        (function_id, target_id, type)
                        values (%s, %s, %s)
                        """,
                        (function_id, subcategory_id, 'parent'))

                    added_count += 1

        print "Added %d TIGRFams to the DB." % (added_count,)

        con.commit()

    finally:
        if (cur): cur.close()
        if (con): con.close()


def insert_tigrfams(tigrfams):
    """
    Insert the flat list of TIGRFams as returned by read_tigrfams.
    Note the TIGRFams flat file is more complete than the TIGRFams by role file.
    """
    con = psycopg2.connect("dbname=network_portal user=dj_ango password=django")
    cur = None

    try:
        cur = con.cursor()
        
        tigr_function_ids = get_function_id_lookup_table(cur, 'tigr')

        added_count = 0
        for tigrfam in tigrfams:
            # since this may be used after insert_tigrfams_by_role, we
            # check if each term is in the DB first.
            if tigrfam.id not in tigr_function_ids:
                cur.execute("""
                    insert into networks_function 
                    (native_id, name, description, type, namespace)
                    values (%s, %s, %s, %s, %s);""",
                    (tigrfam.id,
                     tigrfam.name,
                     tigrfam.description,
                     'tigr',
                     'tigrfam' ,))
                added_count += 1

        print "Added %d TIGRFams to the DB." % (added_count,)

        con.commit()

    finally:
        if (cur): cur.close()
        if (con): con.close()


def insert_cogs(cogs):
    """
    Takes a list of COG objects as returned by read_cogs with an id and a
    description and inserts them into the networks_function table in the DB.
    """
    con = psycopg2.connect("dbname=network_portal user=dj_ango password=django")
    cur = None
    
    try:
        cur = con.cursor()

        cog_function_ids = get_function_id_lookup_table(cur, 'cog')
        if len(cog_function_ids) > 0:
            raise Exception("%d COG functions already exists in the database!" % (len(cog_function_ids),))

        count_inserts = 0
        for cog in cogs:
            cur.execute("""
                insert into networks_function 
                (native_id, name, description, type)
                values (%s, %s, %s, %s);""",
                (cog.id,
                 cog.id,
                 cog.description,
                 'cog',))
            count_inserts += 1

        con.commit()
        print "Inserted %d COG functions." % (count_inserts,)

    finally:
        if (cur): cur.close()
        if (con): con.close()



def map_genes_to_go_cog_and_tigr_terms(genes, species):
    """
    Takes a list of gene objects as returned by the function read_microbes_online_genome_info
    and creates associations between genes and GO terms.
    Microbes Online genome info files have these columns:
    locusId, accession, GI,
    scaffoldId, start, stop, strand,
    sysName, name, desc,
    COG, COGFun, COGDesc, TIGRFam, TIGRRoles, GO, EC, ECDesc
    """
    con = psycopg2.connect("dbname=network_portal user=dj_ango password=django")
    cur = None

    try:
        cur = con.cursor()

        # create lookup tables for IDs
        species_id = get_species_id(cur, species)
        gene_ids = get_gene_id_lookup_table(cur, species_id)
        go_function_ids = get_go_function_id_lookup_table(cur)
        cog_function_ids = get_function_id_lookup_table(cur, 'cog')
        tigr_function_ids = get_function_id_lookup_table(cur, 'tigr')
        
        count_inserts = 0
        for gene in genes:

            # find the gene ID
            if gene.sysName in gene_ids:
                gene_id = gene_ids[gene.sysName]
            else:
                # There are features in microbes online genome info files that aren't in other
                # sources. We should probably import these as well, but I'm leaving it for later.
                print "Warning: unknown gene: " + gene.sysName + " - " + gene.name
                continue
                # raise Exception("Unknown gene: " + gene.sysName + " " + gene.name)
            
            if len(gene.GO.strip()) > 0:
                # multiple go terms are comma-separated, far example: GO:0009306,GO:0019861,GO:0016021
                gene_go_ids = gene.GO.split(',')
                for id in gene_go_ids:
                    if id in go_function_ids:
                        function_id = go_function_ids[id]
                    else:
                        raise Exception("Unknown GO ID: " + id)
                    cur.execute("""
                        insert into networks_gene_function
                        (function_id, gene_id, source)
                        values (%s, %s, %s)
                        """,
                        (function_id, gene_id, 'microbes online'))
                    count_inserts += 1
            
            if len(gene.COG.strip()) > 0:
                gene_cog_ids = gene.COG.split(',')
                for id in gene_cog_ids:
                    # fix broken COG ids, dammit!
                    m = re.match(r'COG(\d+)', id)
                    if m:
                        fixed_id = "COG%04d" % (int(m.group(1)))
                    else:
                        raise Exception("Don't understand COG ID: " + id)
                    if fixed_id in cog_function_ids:
                        function_id = cog_function_ids[fixed_id]
                    else:
                        raise Exception("Unknown COG ID: " + id + "/" + fixed_id)
                    cur.execute("""
                        insert into networks_gene_function
                        (function_id, gene_id, source)
                        values (%s, %s, %s)
                        """,
                        (function_id, gene_id, 'microbes online'))
                    count_inserts += 1

            if len(gene.TIGRFam.strip()) > 0:
                tigrfam_id = gene.TIGRFam.split(' ', 1)[0]
                if tigrfam_id in tigr_function_ids:
                    function_id = tigr_function_ids[tigrfam_id]
                else:
                    raise Exception("Unknown TIGRFam ID: " + tigrfam_id)
                cur.execute("""
                    insert into networks_gene_function
                    (function_id, gene_id, source)
                    values (%s, %s, %s)
                    """,
                    (function_id, gene_id, 'microbes online'))
                count_inserts += 1

        con.commit()
        print "Inserted %d functions for %d genes." % (count_inserts,len(genes),)

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


def print_tigrfams_by_role(tigrfams):
    """
    Print TIGRFams hierarchically by role
    """
    for category in tigrfams:
        #print category['name']
        for subcategory in category['roles']:
            #print "  " + subcategory['name']
            for tigrfam in subcategory['tigrfams']:
                #print "    " + tigrfam.id + " " + tigrfam.name
                print tigrfam.id + " " + tigrfam.name


def main():
    parser = argparse.ArgumentParser(description='Import gene functions into the network portal\'s DB')
    #parser.add_argument('filenames', metavar='FILE', nargs='*', help='filenames containing function data')
    #parser.add_argument('--kegg', nargs=2, metavar=('GENE_KEGG_PATHWAY_FILE','KEGG_PATHWAY_IDS_FILE',), help='import KEGG pathways')
    parser.add_argument('--kegg-pathways', metavar='KEGG_PATHWAY_FILE', help='import all KEGG pathways')
    parser.add_argument('--kegg-gene-pathways', metavar='GENE_KEGG_PATHWAY_FILE', help='map genes to KEGG pathways')
    parser.add_argument('--go-terms', metavar='GO_TERMS_FILE', help='Gene Ontology OBO file')
    parser.add_argument('--genome-info', metavar='MICROBES_ONLINE_GENOME_INFO_FILE', help='map genes to COG, GO and TIGR functions')
    parser.add_argument('--tigrfams-by-role', metavar='TIGRFAMS_FILE', help='import TIGRFams by role file')
    parser.add_argument('--tigrfams', metavar='TIGRFAMS_FILE', help='import TIGRFams from flat file file')
    parser.add_argument('--cogs', metavar='COGS_FILE', help='import COG functions')
    parser.add_argument('-s', '--species', help='for example, hal for halo')
    parser.add_argument('--test', action='store_true', help='Print list functions, rather than adding them to the db')
    parser.add_argument('--list-species', action='store_true', help='Print list of known species. You might have to add one.')
    args = parser.parse_args()
    
    if not ( args.kegg_pathways or args.kegg_gene_pathways or args.go_terms or 
             args.genome_info or args.tigrfams or args.tigrfams_by_role or args.cogs or args.list_species ):
        print parser.print_help()
        return
    
    if args.species:
        print "species = " + args.species
        if args.species in species_dict:
            chromosome_map = species_dict[args.species].chromosome_map
            species = species_dict[args.species].name
        else:
            raise Exception("Don't know species: %s", args.species)
    elif args.kegg_gene_pathways or args.genome_info:
        parser.print_help()
        print "\nPlease specify a species.\n"
        return
    
    # list known species and quit
    if args.list_species:
        for key in species_dict:
            print "%s => %s, %s" % (str(key), str(species_dict[key].name), str(species_dict[key].chromosome_map))
        return
    
    # read and insert the master list of all KEGG pathways plus the global pathways
    if args.kegg_pathways:
        kegg_pathways = read_kegg_pathways(args.kegg_pathways)
        if args.test:
            print_hierarchically(kegg_pathways)
        else:
            insert_kegg_pathways(kegg_pathways)
            insert_global_kegg_pathways()

    # import GO gene ontology terms
    if args.go_terms:
        terms = read_go_terms(args.go_terms)
        print "Read %d GO terms." % (len(terms),)
        if args.test:
            for term in terms:
                print str(term)
        else:
            insert_go_terms(terms)

    # import TIGRFams from hierarchical file
    if args.tigrfams_by_role:
        tigrfams = read_tigrfams_by_role(args.tigrfams_by_role)
        if args.test:
            print_tigrfams_by_role(tigrfams)
        else:
            insert_tigrfams_by_role(tigrfams)
    
    # import TIGRFams from flat file
    if args.tigrfams:
        tigrfams = read_tigrfams(args.tigrfams)
        if args.test:
            for tigrfam in tigrfams:
                print tigrfam.id + " " + tigrfam.name
        else:
            insert_tigrfams(tigrfams)

    # import COG functional classes
    if args.cogs:
        cogs = read_cogs(args.cogs)
        if args.test:
            for cog in cogs:
                print "%s %s" % (cog.id, cog.description)
        else:
            insert_cogs(cogs)

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

    # map genes to GO COG and TIGR functions
    if args.genome_info:
        genes = read_microbes_online_genome_info(args.genome_info)
        if args.test:
            for gene in genes:
                print str(gene)
        else:
            map_genes_to_go_cog_and_tigr_terms(genes, species)


if __name__ == "__main__":
    main()
