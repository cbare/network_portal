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
    Returns a map from kegg id to a pathway object.
    """

    category_re = re.compile(r'A\s*<b>(.*)</b>\s*')
    subcategory_re = re.compile(r'B\s*<b>(.*)</b>\s*')
    pathway_re = re.compile(r'C\s*(\d+)\s+(.*)\s+(\[\w+:\w+\d+\])?')
    
    pathways = {}
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
            
            line = line.rstrip('\n')
            if line.startswith('A'):
                m = category_re.match(line)
                if m:
                    category = m.group(1)
                else:
                    raise Exception("Can't parse line: %s" % (line,))
            elif line.startswith('B'):
                m = subcategory_re.match(line)
                if m:
                    subcategory = m.group(1)
                else:
                    raise Exception("Can't parse line: %s" % (line,))
            elif line.startswith('C'):
                m = pathway_re.match(line)
                if m:
                    pathway = OpenStruct()
                    pathway.native_id = m.group(1)
                    pathway.name = m.group(2)
                    pathway.category = category
                    pathway.subcategory = subcategory
                    pathways[pathway.native_id] = pathway
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
    Read kegg_pathway_ids.csv
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


def insert_kegg_pathways(pathways, namespace='kegg pathway'):
    """
    Insert KEGG pathways into DB.
    pathways: a dictionary whose values are pathway objects
    namespace: we overload the namespace to distinguish between 'normal'
    KEGG pathways and 'global' kegg pathways, such as these:
      path:dvu01100,Metabolic pathways
      path:dvu01110,Biosynthesis of secondary metabolites
      path:dvu01120,Microbial metabolism in diverse environments
    """

    con = psycopg2.connect("dbname=network_portal user=dj_ango password=django")
    cur = None

    try:
        cur = con.cursor()

        # get id for kegg pathways, if they already exists
        cur.execute("select id, native_id from networks_function where type='kegg pathway';")
        rows = cur.fetchall()
        existing_pathways = {}
        for row in rows:
            existing_pathways[row[1]] = row[0]

        print("Found %d existing KEGG pathways.\n" % (len(existing_pathways),))

        added_count = 0
        for native_id in pathways:
            pathway = pathways[native_id]
            if native_id in existing_pathways:
                print "KEGG pathway %s already in DB." % (native_id,)
            else:
                cur.execute("""
                    insert into networks_function 
                    (native_id, name, type, namespace)
                    values (%s, %s, %s, %s) RETURNING id;""",
                    (pathway.native_id,
                     pathway.name,
                     'kegg pathway',
                     namespace ,))
                function_id = cur.fetchone()[0]
                print("function_id = " + str(function_id))
                if pathway.category:
                    cur.execute("""
                        insert into networks_function_attributes
                        (function_id, type, value)
                        values (%s, %s, %s)
                        """,
                        (function_id, 'category', pathway.category))
                if pathway.subcategory:
                    cur.execute("""
                        insert into networks_function_attributes
                        (function_id, type, value)
                        values (%s, %s, %s)
                        """,
                        (function_id, 'subcategory', pathway.subcategory))
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
    pathways = {
        '01100': OpenStruct(native_id='01100', name='Metabolic pathways', category='Metabolism'),
        '01110': OpenStruct(native_id='01110', name='Biosynthesis of secondary metabolites', category='Metabolism'),
        '01120': OpenStruct(native_id='01120', name='Microbial metabolism in diverse environments', category='Metabolism') }
    
    insert_kegg_pathways(pathways, namespace='global kegg pathway')


def print_hierarchically(kegg_pathways):
    """
    KEGG pathways are organized into categories and subcategories. Print them
    as a hierarchy.
    """
    categories = {}
    sorted_ids = kegg_pathways.keys()
    sorted_ids.sort()
    for id in sorted_ids:
        pathway = kegg_pathways[id]
        if pathway.category not in categories:
            categories[pathway.category] = {}
        if pathway.subcategory not in categories[pathway.category]:
            categories[pathway.category][pathway.subcategory] = []
        categories[pathway.category][pathway.subcategory].append(pathway.native_id)
    for category in categories:
        print category
        for subcategory in categories[category]:
            print "  " + subcategory
            for id in categories[category][subcategory]:
                print "    " + id + " " + str(kegg_pathways[id].name)


def main():
    parser = argparse.ArgumentParser(description='Import gene functions into the network portal\'s DB')
    #parser.add_argument('filenames', metavar='FILE', nargs='*', help='filenames containing function data')
    parser.add_argument('--kegg', nargs=2, metavar=('GENE_KEGG_PATHWAY_FILE','KEGG_PATHWAY_IDS_FILE',), help='import KEGG pathways')
    parser.add_argument('--kegg-pathways', metavar='KEGG_PATHWAY_FILE', help='import all KEGG pathways')
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
    
    # read and insert the master list of all KEGG pathways
    if args.kegg_pathways:
        kegg_pathways = read_kegg_pathways(args.kegg_pathways)
        print "Read %d kegg pathways" % (len(kegg_pathways),)
        if args.test:
            print_hierarchically(kegg_pathways)
        else:
            insert_kegg_pathways(kegg_pathways)
            insert_global_kegg_pathways()
    
    if args.kegg:
        kegg_pathway_ids = read_kegg_pathway_ids(args.kegg[0])
        print "Read %d kegg pathway ids." % (len(kegg_pathway_ids,))
    
        gene_kegg_pathways = read_gene_kegg_pathways(args.kegg[1])
        for gene in gene_kegg_pathways:
            pathways = gene_kegg_pathways[gene]
            for p in pathways:
                print "%s : %s" % (gene, kegg_pathway_ids[p].native_id)


if __name__ == "__main__":
    main()
