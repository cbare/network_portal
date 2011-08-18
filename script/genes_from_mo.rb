##
## grab gene annotations from Microbes Online and import them to a MySQL DB
##

## NOTE: this is out of date, abandoned and won't work. See genes_from_ncbi.rb

require 'rubygems'
require 'open-uri'
require 'mysql'
require 'optparse'


# retrieve command line arguments
options = {}
OptionParser.new do |opts|
  opts.banner = "Transfer gene annotation from Microbes Online to a MySQL DB. See db/create_tables.sql for schema.\n" +
                "Usage: ruby genes_from_mo.rb --id [NCBI Taxonomy ID]\n" +
                "       ruby genes_from_mo.rb --file [filename]\n"

  opts.on("-i", "--id [ID]", "NCBI Taxonomy ID") do |id|
    options['tax_id'] = id
  end

  opts.on("-f", "--file [filename]", "filename from which to load annotations") do |filename|
    options['filename'] = filename
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

if options['tax_id'] then
  data_source = "http://www.microbesonline.org/cgi-bin/genomeInfo.cgi?tId=#{options['tax_id']};export=tab"
elsif options['filename']
  data_source = options['filename']
else
  raise "Please supply either a taxonomy id or a filename"
end

# open gene table from Microbes Online
file = open(data_source)

# set species ID, see db/create_tables.sql
species_id = 1

# column names, slightly changed from what MO gives you
columns = "id, species_id, name, common_name, accession, gi, scaffoldId, start, stop, strand, description, COG, COGFun, COGDesc, TIGRFam, TIGRRoles, GO, EC, ECDesc"

# MO gives these columns: locusId, accession, GI, scaffoldId, start, stop, strand, sysName, name, desc, COG, COGFun, COGDesc, TIGRFam, TIGRRoles, GO, EC, ECDesc

# connect to my_sql
db = Mysql.new("localhost", "network_portal", "monkey2us", "network_portal_development")

# prepare a query to insert rows into the genes table
sql = db.prepare "insert into genes (" + columns + ") values (" + ("?"*19).split("").join(",") + ")"

# read 1 line file header
line = file.readline
field_names = line.split("\t")

# for each line in the annotations file, insert a row into the genes table
while (line = file.gets)
  fields = line.split("\t")
  puts "#{fields[0]}\t#{fields[7]}\t#{fields[8]}"
  sql.execute(
    fields[0],         # id
    species_id,        # species_id
    fields[7],         # name
    fields[8],         # common name
    fields[1],         # accession
    fields[2].to_i,    # GI
    fields[3].to_i,    # scaffoldId
    fields[4].to_i,    # start
    fields[5].to_i,    # stop
    fields[6],         # strant
    fields[9],         # description
    fields[10],        # COG
    fields[11],        # COGFun
    fields[12],        # COGDesc
    fields[13],        # TIGRFam
    fields[14],        # TIGRRoles
    fields[15],        # GO
    fields[16],        # EC
    fields[17]         # ECDesc
  ) 
end

sql.close
db.close

file.close


