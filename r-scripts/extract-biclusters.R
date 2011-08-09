##
## A script to take cMonkey output and extract biclusters into a database
##
## To use this script, you'll need:
## * R with cMonkey installed (see:
##   http://baliga.systemsbiology.net/drupal/content/new-cmonkey-r-package-and-code)
## * MySQL with a schema created by db/create_tables.sql, like this:
##   mysql -p -u network_portal < db/create_tables.sql
## * an entry in the species table
## * gene annotations for species
##   see: script/genes_from_mo.rb
##
## Christopher Bare

library(RMySQL)

# import a network from cMonkey output
# e            - the environment produced by cMonkey
# network.name - name of new network, set to species if omitted
# data.source  - automatically populated w/ cmonkey if omitted
# description  - textual description of the network
extract.network <- function(e, network.name=NULL, data.source=NULL, db.name="network_portal_development", description=NULL) {

  # connect ot database and disconnect on exit
  con <- dbConnect(MySQL(), user="network_portal", password="monkey2us", dbname=db.name, host="localhost", client.flag=CLIENT_MULTI_STATEMENTS)
  on.exit(dbDisconnect(con))

  # get the species id
  species <- e$organism
  sql <- sprintf("select id from species where name = '%s' or short_name = '%s';", species, species)
  cat(sql, "\n")
  species.id <- dbGetQuery(con, sql)[1,1]

  # insert row in network table
  sql <- sprintf("insert into networks (species_id, name, data_source, description, created_at) values (%d, '%s', '%s', '%s', NOW());", species.id, network.name, data.source, description)
  cat(sql, "\n")
  dbSendQuery(con, sql)
  select.last.insert.id <- "SELECT LAST_INSERT_ID();"
  tmp <- dbGetQuery(con, select.last.insert.id)
  cat("tmp = ", str(tmp), "\n");
  network.id <- tmp[1,1]
  
  cat('inserted network ID: ', network.id, "\n")

  # extract each bicluster and put it in the db
  for (k in 1:e$k.clust) {
    extract.bicluster(con, e, k, network.id)
  }

}


# extract bicluster number k
extract.bicluster <- function(con, e, k, network.id) {
  
  cat("extracting cluster ", k, "\n")
  
  b <- e$get.clust(k)

  # insert row into biclusters table
  sql <- sprintf("insert into biclusters (network_id, k, residual) values (%d, %d, %f);  SELECT LAST_INSERT_ID();", network.id, k, b$resid)
  cat(sql, "\n")
  bicluster.id <- dbGetQuery(con, sql)[1,1]
  cat('inserted bicluster: ', bicluster.id, "\n")

  # genes <- b$rows
  # for (gene in genes) {
  #   sql <- sprintf("select id from genes where name = '%s';", gene)
  #   tmp <- dbGetQuery(con, sql)
  #   if (nrow(tmp) < 1) {
  #     warning(sprintf("Gene \"%s\" not found in db.", gene))
  #   }
  #   else {
  #     gene.id <- tmp[1,1]
  #     sql <- sprintf("insert into bicluster_genes (bicluster_id, gene_id) values (%d, %d)", bicluster.id, gene.id)
  #   }
  # }

  conditions <- b$cols

  # for each motif (typically 2)
  # for (motif in e$meme.scores[[1]][[k]]$meme.out) {
  #   
  #   # get pssm
  #   motif$pssm
  #   
  #   # get positions
  # }
}



con <- dbConnect(MySQL(), user="network_portal", password="monkey2us", dbname='network_portal_development', host="localhost", client.flag=CLIENT_MULTI_STATEMENTS)
a <- dbSendQuery(con, "insert into networks (species_id, name, data_source, description, created_at) values ('1', 'test network', 'foo', 'foo foo description', NOW());")
dbClearResult(a)
b <- dbGetQuery(con, "select last_insert_id()");
dbDisconnect(con)

id <- dbGetQuery(con, "insert into networks (species_id, name, data_source, description, created_at) values ('1', 'test network', 'foo', 'foo foo description', NOW()); select last_insert_id();");

