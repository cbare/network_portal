##
## A script to take cMonkey output and extract biclusters into a database
##
## To use this script, you'll need:
##
## * R with cMonkey installed (see:
##   http://baliga.systemsbiology.net/drupal/content/new-cmonkey-r-package-and-code)
##
## * a cMonkey cm_session.RData file
##
## * MySQL with a schema created by db/create_tables.sql, like this:
##   mysql -p -u network_portal < db/create_tables.sql
##
## * an entry in the species table
##
## * gene annotations for your species
##   see: script/genes_from_ncbi.rb and script/dvu_discontinued_genes.rb
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

  species.id <- get.species.id(con, e)

  # insert row in network table
  sql <- sprintf("insert into networks (species_id, name, data_source, description, created_at) values (%d, '%s', '%s', '%s', NOW());", species.id, network.name, data.source, description)
  cat(sql, "\n")
  db.result <- dbSendQuery(con, sql)
  dbClearResult(db.result)

  # get the ID of the newly inserted row
  network.id <- dbGetQuery(con, "select last_insert_id();")[1,1]

  cat('inserted network ID: ', network.id, "\n")
  
  # insert conditions
  extract.conditions(con, e)

  # extract each bicluster and put it in the db
  for (k in 1:e$k.clust) {
    extract.bicluster(con, e, k, network.id, species.id)
  }

}


# extract bicluster number k
extract.bicluster <- function(con, e, k, network.id, species.id) {
  
  cat("~~~~~~~~~~~~~~~~  extracting cluster ", k, "\n")
  
  b <- e$get.clust(k)

  # insert row into biclusters table
  sql <- sprintf("insert into biclusters (network_id, k, residual) values (%d, %d, %f);", network.id, k, b$resid)
  cat(sql, "\n")
  db.result <- dbSendQuery(con, sql)
  dbClearResult(db.result)

  # get the ID of the newly inserted bicluster
  bicluster.id <- dbGetQuery(con, "select last_insert_id();")[1,1]

  genes <- b$rows
  for (gene in genes) {
    sql <- sprintf("select id, name, common_name from genes where species_id = %d and (name = '%s' or common_name = '%s');", species.id, gene, gene)
    tmp <- dbGetQuery(con, sql)
    if (nrow(tmp) < 1) {
      warning(sprintf("Gene \"%s\" not found in db.", gene))
    }
    else {
      if (nrow(tmp) > 1) {
        if (nrows(tmp) <= 12) {
          ambiguous.names <- paste( sapply(1:nrow(tmp), function(i) { paste(tmp[i,2], '/', tmp[i,3], sep='') } ) , collapse=', ')
          warning(sprintf("Gene \"%s\" maps ambiguously to %d genes: %s", gene, nrows(tmp), ambiguous.names))
        }
        else {
          warning(sprintf("Gene \"%s\" maps ambiguously to %d genes.", gene, nrows(tmp)))
        }
      }
      gene.id <- tmp[1,1]
      sql <- sprintf("insert into bicluster_genes (bicluster_id, gene_id) values (%d, %d);", bicluster.id, gene.id)
    }
  }
  cat(length(genes), "genes\n")

  conditions <- b$cols
  for (condition in conditions) {
    sql <- sprintf("select id from conditions where name='%s';", condition)
    condition.id <- dbGetQuery(con, sql)[1,1]
    sql <- sprintf("insert into biclusters_conditions values(%d, %d);", bicluster.id, condition.id)
    dbGetQuery(con, sql)
  }
  cat(length(conditions), "conditions\n")
  
  # motifs and PSSMs

  cat('~~~~~~~~~~~~~~~~  inserted bicluster: ', bicluster.id, "\n")
}

extract.genes <- function(e) {
  # I started to write this then abandoned it, because I realized all the genes in the
  # ratios matrix aren't represented in the feature names table:

  # > setdiff(rownames(env$ratios[[1]]), as.character(env$genome.info$feature.names$name))
  #  [1] "DVU0699"      "DVU1831"      "DVU2001"      "DVU2049"      "DVU2950"     
  #  [6] "DVU3126"      "DVU3280"      "DVU3304"      "VIMSS_208926" "DVU0490"     
  # [11] "DVU0557"     

  # I eventually got the genes from
  # NCBI, including an extra step to get discontinued and pseudo genes. See:
  # script/genes_from_ncbi.rb
  # script/dvu_discontinued_genes.rb
}

extract.conditions <- function(con, e) {
  conditions <- rownames(e$col.membership)
  for (condition in conditions) {
    dbGetQuery(con, sprintf("insert into conditions (name) values ('%s');", condition))
  }
  cat('inserted', length(conditions), 'conditions', "\n")
}


get.species.id <- function(con, e) {
  species <- e$organism
  sql <- sprintf("select id from species where name = '%s' or short_name = '%s';", species, species)
  # cat(sql, "\n")
  return( dbGetQuery(con, sql)[1,1] )
}

# extract.network(env, network.name="Desulfovibrio network", data.source="MO & cMonkey 4.8.2", description="testing...")

