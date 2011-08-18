##
## insert discontinued genes
##

# Some genes used in the dvu network are discontinued in NCBI, so here's how we
# get the coordinates for those. Please, someone tell me how to get these automatically
# from NCBI!

require 'rubygems'
require 'mysql'
require 'ostruct'


discontinued_genes = [
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
  "DVUA0127 165260 168010 - 2781585"]

# pseudo
pseudo_genes = [
  "DVU0490 558218 559487 - 2793704",
  "DVU0557 624872 625726 + 2795340",
  "DVU0699 773972 775650 + 2794450",
  "DVU1831 1896865 1897691 + 2796465",
  "DVU2001 2082778 2084039 + 2793440",
  "DVU2049 2126385 2126851 + 2794545",
  "DVU2950 3054878 3056595 - 2796501",
  "DVU3126 3273316 3274547 + 2796618",
  "DVU3280 3455425 3456410 + 2796004",
  "DVU3304 3481262 3482740 + 2796039"]

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

def insert_weird_VIMSS_208926
  # connect to my_sql
  db = Mysql.new("localhost", "network_portal", "monkey2us", "network_portal_development")
  db.query("insert into genes (species_id, sequence_id, name, type, description) values (1,1,'VIMSS_208926','unknown','no idea what this is, but it\\'s in the ratios matrix');")
  db.close
end

def parse_genes(gene_strings, type)
  genes = Array.new
  gene_strings.each do |str|
    fields = str.split(' ')
    gene = OpenStruct.new
    gene.name   = fields[0]
    gene.start  = fields[1].to_i
    gene.end    = fields[2].to_i
    gene.strand = fields[3]
    gene.geneid = fields[4].to_i
    gene.gene_type   = type
    gene.sequence = (gene.name.start_with? "DVUA") ? "pDV" : "chromosome"
    genes << gene
  end
  return genes
end

insert_genes(parse_genes(discontinued_genes, 'discontinued'), 1)
insert_genes(parse_genes(pseudo_genes, 'pseudo'), 1)
insert_weird_VIMSS_208926()




