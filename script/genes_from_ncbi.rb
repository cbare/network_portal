##
## get gene annotations from NCBI
##

require 'rubygems'
require 'open-uri'
require 'mysql'
require 'ostruct'


# Expected format, a tab separated file with these columns:
# Product Name, Start, End, Strand, Length, Gi, GeneID, Locus, Locus_tag, COG(s)
# 2 header lines, for example:
# Desulfovibrio vulgaris str. Hildenborough chromosome, complete genome
# Product Name	Start	End	Strand	Length	Gi	GeneID	Locus	Locus_tag	COG(s)


def dash_to_null(string)
  return string=='-' ? nil : string
end


def parse_gene_table(file)

  # read organism name
  organism = file.readline
  puts "organism = #{organism}"

  # read column names
  line = file.readline
  field_names = line.split("\t")

  genes = Array.new()

  # read genes
  while (line = file.gets)
    line.chomp!
    if (line.length == 0)
      next
    end
    fields = line.split("\t")
    gene = OpenStruct.new
    gene.description = fields[0]
    gene.start = fields[1].to_i
    gene.end = fields[2].to_i
    gene.strand = fields[3]
    gene.gi = fields[5].to_i
    gene.gene_id = fields[6].to_i
    gene.common_name = dash_to_null(fields[7])
    gene.name = dash_to_null(fields[8])
    gene.cogs = dash_to_null(fields[9])
    gene.gene_type = 'cds'
    genes << gene
  end

  return genes
end


def get_genes_from_ncbi(uids)
  genes = Array.new
  for uid in uids
    data_source = "http://www.ncbi.nlm.nih.gov/sites/entrez?db=genome&cmd=text&dopt=Protein+Table&list_uids=#{uid}"
    begin
      file = open(data_source)
      genes << parse_gene_table(file)
    ensure
      file.close
    end
  end
  return genes.flatten!
end


def get_genes_from_file(filename, sequence)
  begin
    file = open(filename)
    genes = parse_gene_table(file)
    genes.each { |gene| gene.sequence = sequence }
    return genes
  ensure
    file.close
  end
end


def insert_genes(genes, species_id)
  # connect to my_sql
  db = Mysql.new("localhost", "network_portal", "monkey2us", "network_portal_development")
  
  # build a map from sequence name to id
  sequence_ids = {}
  rs = db.query("select id, name from sequences where species_id=#{species_id};")
  rs.each { |row| sequence_ids[row[1]] = row[0] }
  
  # check sequence names
  genes.each do |gene|
    if (!sequence_ids.has_key?(gene.sequence))
      puts "Unknown sequence: #{gene.sequence}"
      puts "---> known sequences: #{sequence_ids.keys.join(', ')}"
      return
    end
  end

  # prepare a query to insert rows into the genes table
  sql = db.prepare "insert into genes ( species_id, sequence_id, name, common_name, geneid, type, start, end, strand, description ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"

  genes.each do |gene|
    sql.execute(
      species_id,
      sequence_ids[gene.sequence],
      gene.name,
      gene.common_name,
      gene.geneid,
      gene.gene_type,
      gene.start,
      gene.end,
      gene.strand,
      gene.description
    )
  end

  db.close
end



# DVU gene annotation files can be downloaded from NCBI at:
# http://www.ncbi.nlm.nih.gov/sites/entrez?db=genome&cmd=Retrieve&dopt=Protein+Table&list_uids=400
# http://www.ncbi.nlm.nih.gov/sites/genome?Db=genome&cmd=Retrieve&dopt=Protein+Table&list_uids=17670

ncbi_uids = [400, 17670]
genes_chromosome_file = '../data/dvu/proteins_chromosome.tsv'
genes_plasmid_file = '../data/dvu/proteins_pDV.tsv'
genes = get_genes_from_file(genes_chromosome_file, 'chromosome') + get_genes_from_file(genes_plasmid_file, 'pDV')

puts "genes.length = #{genes.length}"

dvu_species_id = 1

insert_genes(genes, dvu_species_id)


