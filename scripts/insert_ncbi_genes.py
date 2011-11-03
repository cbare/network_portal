##
## load gene annotations from NCBI into postgres
##
import sys
import psycopg2
import argparse
import re
from species import species_dict
from open_struct import OpenStruct


# the database table networks_gene looks like this:
# id                   | integer                | not null default nextval('networks_gene_id_seq'::regclass)
# species_id           | integer                | not null
# chromosome_id        | integer                | not null
# name                 | character varying(64)  | not null
# common_name          | character varying(100) | 
# geneid               | integer                | 
# type                 | character varying(64)  | 
# start                | integer                | not null
# end                  | integer                | not null
# strand               | character varying(1)   | not null
# description          | character varying(255) | 
# transcription_factor | boolean                | not null


def insert_genes_into_postgres(genes, species):
    con = psycopg2.connect("dbname=network_portal user=dj_ango password=django")
    cur = None

    try:
        cur = con.cursor()

        # get id for species
        cur.execute("select id from networks_species where name=%s;", (species,))
        species_id = cur.fetchone()[0]
        print("id for species %s = %d.\n" % (species, species_id))

        # get lookup table for chromosomes
        cur.execute("select name, id from networks_chromosome where species_id=%s", (species_id,))
        chromosomes = {}
        for row in cur:
            chromosomes[row[0]] = row[1]

        print("chromosome lookup table:")
        print(chromosomes)
        print("\n")

        for gene in genes:
            cur.execute("""
                insert into networks_gene 
                (species_id, chromosome_id, name, common_name, geneid, type, "start", "end", strand, description)
                values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s);""",
                (species_id,
                 chromosomes[gene.chromosome],
                 gene.name,
                 gene.common_name,
                 gene.geneid,
                 gene.type,
                 gene.start,
                 gene.end,
                 gene.strand,
                 gene.description,))
        con.commit()

    finally:
        if (cur): cur.close()
        if (con): con.close()


def guess_rna_gene_type(description):
    if description is None:
        return 'rna'
    elif description.lower().find('ribosomal rna') > -1:
        return 'rrna'
    elif description.lower().find('trna') > -1:
        return 'trna'
    elif description.lower().find('rrna') > -1:
        return 'rrna'
    else:
        return 'rna'


# read genes into objects
def read_genes(filename, chromosome=None, chromosome_map=None, rna=False):
    genes = []
    with open(filename, 'r') as f:
        try:
            # first two lines hold title and column headers:
            title = f.next()
            
            # figure out chromosome from title
            if chromosome is None:
                for key in chromosome_map:
                    if title.find(key) > -1:
                        chromosome = chromosome_map[key]
                        break
            
            if chromosome is None:
                raise Exception("Can't figure out chromosome for: %s\ntitle=%s", filename, title)
            
            # parse out column headers
            columns = {}
            i = 0
            for column in f.next().strip().split("\t"):
                columns[column] = i
                i += 1
        except Exception as e:
            print "Error reading file: " + filename
            print str(type(e)) + ": " + str(e)
            return None
            
        try:
            # read line into objects
            for line in f:
                # strip leading and trailing whitespace
                line = line.strip()

                # skip blank lines
                if (len(line)==0): continue

                fields = line.split("\t")

                gene = OpenStruct()
                gene.name = fields[columns['Locus_tag']]         # locus tag
                if (fields[columns['Locus']] != '-'):
                    gene.common_name = fields[columns['Locus']]  # locus
                if 'Gi' in columns:
                    gene.gi = int(fields[columns['Gi']])
                gene.geneid = int(fields[columns['GeneID']])
                gene.strand = fields[columns['Strand']]                        # '+' or '-'
                gene.start = int(fields[columns['Start']])
                gene.end = int(fields[columns['End']])
                if (fields[columns['Product Name']] != '-'):
                    gene.description = fields[columns['Product Name']]  # locus
                gene.chromosome = chromosome
                
                if rna:
                    gene.type = guess_rna_gene_type(gene.description)
                else:
                    gene.type = 'CDS'

                genes.append( gene )
        except Exception as e:
            print "Error reading line: " + line
            print str(type(e)) + ": " + str(e)
    return genes


def get_chromosome_names(species=None, species_id=None):
    con = psycopg2.connect("dbname=network_portal user=dj_ango password=django")
    cur = None

    try:
        cur = con.cursor()

        # get id for species
        if species_id==None:
            cur.execute("select id from networks_species where name=%s;", (species,))
            species_id = cur.fetchone()[0]

        # get lookup table for chromosomes
        cur.execute("select name, id from networks_chromosome where species_id=%s", (species_id,))
        chromosomes = {}
        for row in cur:
            chromosomes[row[0]] = row[1]
        return chromosomes

    finally:
        if (cur): cur.close()
        if (con): con.close()



def main():
    parser = argparse.ArgumentParser(description='Import genes in NCBI protein table format into the network portal\'s DB')
    parser.add_argument('filenames', metavar='FILE', nargs='*', help='an NCBI protein table file')
    parser.add_argument('-s', '--species', help='for example, hal for halo')
    parser.add_argument('--rna', action='store_true', help='genes are RNA genes')
    #parser.add_argument('-d', '--data-dir', help='location of data files')
    parser.add_argument('--test', action='store_true', help='Print lists of genes, rather than adding them to the db')
    parser.add_argument('--list-species', action='store_true', help='Print list of known species. You might have to add one.')
    args = parser.parse_args()

    # list known species and quit
    if args.list_species:
        for key in species_dict:
            print "%s => %s, %s" % (str(key), str(species_dict[key].name), str(species_dict[key].chromosome_map))
        return
    
    if args.filenames==None or len(args.filenames)==0:
        parser.print_help()
        print "\nPlease specify some gene files to read.\n"
        return

    print "filenames = " + str(args.filenames)
    print "species = " + args.species
    
    if args.species in species_dict:
        chromosome_map = species_dict[args.species].chromosome_map
        species = species_dict[args.species].name
    else:
        raise Exception("Can't find chromsome map for species: %s", args.species)
    
    for filename in args.filenames:
        genes = read_genes(filename, chromosome_map=chromosome_map, rna=args.rna)
        print "read %d genes" % (len(genes))
        
        if args.test:
            for gene in genes:
                print str(gene)
            continue
        
        insert_genes_into_postgres(genes, species)


if __name__ == "__main__":
    main()

