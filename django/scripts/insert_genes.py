##
## load gene annotations from NCBI into postgres
##
import sys
import psycopg2

data_dir = '../../data/dvu'
genes_chromosome_file = 'proteins_chromosome.tsv'
genes_plasmid_file = 'proteins_pDV.tsv'

# files are tab delimited text with two header lines:
# Desulfovibrio vulgaris str. Hildenborough chromosome, complete genome
# Product Name    Start   End     Strand  Length  Gi      GeneID  Locus   Locus_tag       COG(s)


# like a javascript object, just assign any properties
class OpenStruct:
    def __init__(self, **dic):
        self.__dict__.update(dic)

    def __getattr__(self, key):
        if key in self.__dict__:
            return self.__dict__[key]
        else:
            return None
#            raise AttributeError, key

    def __setattr__(self, key, value):
        self.__dict__[key] = value
        return value


# read genes into objects
def read_genes(filename, genes=None, chromosome='chromosome'):
    if genes is None:
        genes = []
    with open(filename, 'r') as f:
        try:
            # skip 2 lines:
            for skip in range(0,2):
                f.next()

            # read line into objects
            for line in f:
                # strip leading and trailing whitespace
                line = line.strip()

                # skip blank lines
                if (len(line)==0): continue

                fields = line.split("\t")

                gene = OpenStruct()
                gene.name = fields[8]                          # locus tag
                if (fields[7] != '-'):
                    gene.common_name = fields[7]               # locus
                gene.geneid = int(fields[5])
                gene.strand = fields[3]                        # '+' or '-'
                gene.start = int(fields[1])
                gene.end = int(fields[2])
                gene.description = fields[0]
                gene.chromosome = chromosome
                gene.transcription_factor = False

                genes.append( gene )
        except Exception:
            print("Error reading line: " + line)
    return genes


# Some genes used in the dvu network are discontinued in NCBI, so here's how we
# get the coordinates for those. Please, someone tell me how to get these automatically
# from NCBI!
def missing_genes(genes=None):
    if genes is None:
        genes = []

    missing_genes = {
        'discontinued_genes': [
            "DVU0178 223139 223348 - 2795620",
            "DVU0287 333315 333497 - 2793493",
            "DVU0288 333685 333780 - 2793494",
            "DVU0559 626474 626626 - 2794779",
            "DVU0574 639801 640106 - 2793419",
            "DVU0695 771081 771278 + 2793635",
            "DVU0844 932093 932572 + 2795195",
            "DVU0860 951600 951704 + 2796157",
            "DVU1184 1274264 1274716 + 2796669",
            "DVU1293 1385742 1386158 - 2794746",
            "DVU1492 1570560 1571141 - 2794426",
            "DVU1565 1648604 1648873 + 2795739",
            "DVU1706 1782524 1782634 - 2795830",
            "DVU1800 1862684 1862782 + 2796709",
            "DVU2080 2166759 2167022 - 2793534",
            "DVU2311 2404951 2405085 - 2795271",
            "DVU2327 2424064 2424636 + 2793800",
            "DVU2393 2495688 2496071 - 2795296",
            "DVU2458 2564834 2564956 - 2795322",
            "DVU2601 2721679 2722539 + 2793897",
            "DVU2709 2816162 2816320 + 2793999",
            "DVU2726 2829475 2829594 + 2794016",
            "DVU2734 2834758 2835141 + 2795936",
            "DVU3345 3518609 3518980 + 2796357",
            "DVU3354 3525278 3525415 - 2795668",
            "DVU3390 3566461 3566997 + 2796409",
            "DVUA0127 165260 168010 - 2781585"],
        'pseudo_genes': [
            "DVU0490 558218 559487 - 2793704",
            "DVU0557 624872 625726 + 2795340",
            "DVU0699 773972 775650 + 2794450",
            "DVU1831 1896865 1897691 + 2796465",
            "DVU2001 2082778 2084039 + 2793440",
            "DVU2049 2126385 2126851 + 2794545",
            "DVU2950 3054878 3056595 - 2796501",
            "DVU3126 3273316 3274547 + 2796618",
            "DVU3280 3455425 3456410 + 2796004",
            "DVU3304 3481262 3482740 + 2796039"],
        'unknown': [
            "VIMSS_208926 0 0 ?"],
    }

    for k,v in missing_genes.items():
        for s in v:
            fields = s.split()
            gene = OpenStruct()
            gene.name   = fields[0]
            gene.start  = int(fields[1])
            gene.end    = int(fields[2])
            gene.strand = fields[3]
            if (len(fields) > 4):
                gene.geneid = int(fields[4])
            gene.gene_type   = k
            gene.chromosome = "pDV" if gene.name.startswith("DVUA") else "chromosome"
            gene.transcription_factor = False
            genes.append(gene)


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


# create user network_portal_user login password 'monkey2us';
# create user dj_ango login password 'django';
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
                 "CDS",
                 gene.start,
                 gene.end,
                 gene.strand,
                 gene.description,))
        con.commit()

        
    finally:
        if (cur): cur.close()
        if (con): con.close()



# user may specifying data directory on the command line
if ( len(sys.argv) > 1 ):
    data_dir = sys.argv[1]

print("\nreading genes...\n")

genes = []
read_genes( data_dir + '/' + genes_chromosome_file, genes=genes, chromosome='chromosome' )
read_genes( data_dir + '/' + genes_plasmid_file, genes=genes, chromosome='pDV' )
missing_genes( genes=genes )

print("finished reading %d genes.\n" % (len(genes)))

print("inserting genes...\n")

insert_genes_into_postgres(genes, "Desulfovibrio vulgaris Hildenborough")

print("finished inserting %d genes.\n" % (len(genes)))


