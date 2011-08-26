##
## A script to take cMonkey output and extract biclusters into a database
##
## This script will probably require tweeking on a case-by-case basis. It was
## developed for the Desulfovibrio network.
##
## To use this script, you'll need:
##
## * R with cMonkey installed (see:
##   http://baliga.systemsbiology.net/drupal/content/new-cmonkey-r-package-and-code)
##
## * a cMonkey cm_session.RData file
##     http://baliga.systemsbiology.net/cmonkey/enigma/cmonkey_4.8.2_dvu_3491x739_11_Mar_02_17:37:51/
##
## * inferelator output file:
##     http://baliga.systemsbiology.net//cmonkey/enigma/zzz_dvu_nwInf_coeffs.RData
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
  sql <- sprintf("insert into networks (species_id, name, data_source, description, created_at) values (%d, '%s', '%s', '%s', NOW());",
                 species.id, network.name, data.source, description)
  cat(sql, "\n")
  db.result <- dbSendQuery(con, sql)
  dbClearResult(db.result)

  # get the ID of the newly inserted row
  network.id <- dbGetQuery(con, "select last_insert_id();")[1,1]

  cat('inserted network ID: ', network.id, "\n")
  
  # insert conditions
  extract.conditions(con, e, network.id)

  # extract each bicluster and put it in the db
  for (k in 1:e$k.clust) {
    extract.bicluster(con, e, k, network.id, species.id)
  }

  # extract gene expression data from ratios matrix
  # extract.ratios(con, e, network.id, species.id)
}


# extract bicluster number k from environment e
# creating an entry in the biclusters table along with associations
# in biclusters_genes, biclusters_conditions
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

  # add genes to bicluster
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
      sql <- sprintf("insert into biclusters_genes (bicluster_id, gene_id) values (%d, %d);", bicluster.id, gene.id)
      dbGetQuery(con, sql)
    }
  }
  cat(length(genes), "genes\n")

  # add conditions to bicluster
  conditions <- b$cols
  for (condition in conditions) {
    sql <- sprintf("select id from conditions where name='%s';", condition)
    condition.id <- dbGetQuery(con, sql)[1,1]
    sql <- sprintf("insert into biclusters_conditions values(%d, %d);", bicluster.id, condition.id)
    dbGetQuery(con, sql)
  }
  cat(length(conditions), "conditions\n")
  
  # motifs and PSSMs
  extract.motifs.for.bicluster(con, e, k, bicluster.id)

  cat('~~~~~~~~~~~~~~~~  inserted bicluster: ', bicluster.id, "\n")
}

# Current versions of cMonkey are configured to find two motifs
# for each bicluster. This method extracts them from environment
# e and imports them into the DB, creating entries in two tables:
# motifs and PSSMs.
extract.motifs.for.bicluster <- function(con, e, k, bicluster.id) {
  # meme results are in e$meme.scores[[1]][[k]] where k is the bicluster number
  # that returns a list in which $pv.ev[[2]] has mast hits for both motifs
  # PSSMs are in $meme.out[[1]]$pssm and $meme.out[[2]]$pssm

  # some biclusters appear not to have meme output, so we check
  if ('meme.out' %in% names(e$meme.scores[[1]][[k]])) {
    for (m in 1:length(e$meme.scores[[1]][[k]]$meme.out)) {
      
      meme.out <- e$meme.scores[[1]][[k]]$meme.out[[m]]

      # insert motif
      sql <- sprintf("insert into motifs (bicluster_id, position, sites, e_value) values (%d, %d, %d, %f);",
                     bicluster.id, m, meme.out$sites, meme.out$e.value)
      db.result <- dbSendQuery(con, sql)
      dbClearResult(db.result)

      # get the ID of the newly inserted motif
      motif.id <- dbGetQuery(con, "select last_insert_id();")[1,1]

      # insert PSSM
      pssm <- meme.out$pssm
      for (i in 1:nrow(pssm)) {
        sql <- sprintf("insert into pssms (motif_id, position, a, c, g, t) values (%d, %d, %f, %f, %f, %f);",
                       motif.id, i, pssm[i,1], pssm[i,2], pssm[i,3], pssm[i,4])
        dbGetQuery(con, sql)
      }

      cat("inserted motif", motif.id, "\n")
    }
  }
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
  
  # note that genes table must contain an entry for each row in e$ratios
}

# populate conditions table
extract.conditions <- function(con, e, network.id) {
  conditions <- rownames(e$col.membership)
  for (condition in conditions) {
    dbGetQuery(con, sprintf("insert into conditions (name, network_id) values ('%s', %d);", condition, network.id))
  }
  cat('inserted', length(conditions), 'conditions', "\n")
}

# create a translation table between gene name and id for the given species
get.gene.ids <- function(con, species.id) {
  sql <- sprintf("select id, name from genes where species_id=%d order by name;", species.id)
  name.id.map <- dbGetQuery(con, sql)
  rownames(name.id.map) <- name.id.map$name
  return(name.id.map)
}

# create a translation table between condition name and id for the given network
get.condition.ids <- function(con, network.id) {
  sql <- sprintf("select id, name from conditions where network_id=%d order by name;", network.id)
  name.id.map <- dbGetQuery(con, sql)
  rownames(name.id.map) <- name.id.map$name
  return(name.id.map)
}

# import the ratios matrix into the expression table
# this takes a couple hours to finish adding 2.5 million rows
extract.ratios <- function(con=NULL, e, network.id, species.id) {

  # connect to db, if needed
  if (is.null(con)) {
    con <- dbConnect(MySQL(), user="network_portal", password="monkey2us", dbname="network_portal_development", host="localhost", client.flag=CLIENT_MULTI_STATEMENTS)
    on.exit(dbDisconnect(con))
  }

  ratios <- env$ratios[[1]]
  cat("Begin import of", nrow(ratios), "by", ncol(ratios), "matrix.\n")

  gene.name.id.map <- get.gene.ids(con, species.id)
  cond.name.id.map <- get.condition.ids(con, network.id)

  # Insert a gene at a time. All data for a given gene will be contiguous in the db,
  # making lookup by gene slightly faster.
  for (r in 1:nrow(ratios)) {
    gene.id <- gene.name.id.map[rownames(ratios)[r], 1]
    for (c in 1:ncol(ratios)) {
      if (!is.na(ratios[r,c])) {
        cond.id <- cond.name.id.map[colnames(ratios)[c], 1]
        sql <- sprintf("insert into expression (gene_id, condition_id, value) values (%d, %d, %f);", gene.id, cond.id, ratios[r,c])
        dbGetQuery(con, sql)
      }
    }
  }
  cat("inserted expression values for:", ncol(ratios),"conditions\n")
}

# get species_id for e$organism
get.species.id <- function(con, e) {
  species <- e$organism
  sql <- sprintf("select id from species where name = '%s' or short_name = '%s';", species, species)
  # cat(sql, "\n")
  return( dbGetQuery(con, sql)[1,1] )
}

# data is in files like: data/dvu/zzz_dvu_nwInf_coeffs.RData
#   e.coeffs
#   expMap
#   predictor.mats
#   predictors
#   ratios
#   tfs
extract.influences <- function(con=NULL, e.coeffs, network.id, species.id) {
  # connect to db, if needed
  if (is.null(con)) {
    con <- dbConnect(MySQL(), user="network_portal", password="monkey2us", dbname="network_portal_development", host="localhost", client.flag=CLIENT_MULTI_STATEMENTS)
    on.exit(dbDisconnect(con))
  }

  # create bicluster id lookup table
  sql <- sprintf("select k, id from biclusters where network_id=%d order by k;", network.id)
  temp <- dbGetQuery(con, sql)
  bicluster.ids <- temp$id
  rownames(bicluster.ids) <- temp$k

  # create gene id lookup table
  sql <- sprintf("select id, name from genes where species_id=%d;", species.id)
  temp <- dbGetQuery(con, sql)
  gene.ids <- temp$id
  rownames(gene.ids) <- temp$name

  for (bicluster.coeffs in e.coeffs) {
    for (predictor in names(bicluster$coeffs)) {
      if (predictor %in% names(gene.ids)) {
        gene.id <- gene.ids[predictor]
        sql <- sprintf("insert into influences (name, gene_id, type) values ('%s', %d, 'tf');", predictor, gene.id)
      }
      else if predictor
        sql <-  sprintf("insert into influences (name, type) values ('%s', '%s');", predictor, type)
      }
    }
  }

}

mark.tfs <- function(con=NULL, tfs, species.id) {
  # connect to db, if needed
  if (is.null(con)) {
    con <- dbConnect(MySQL(), user="network_portal", password="monkey2us", dbname="network_portal_development", host="localhost", client.flag=CLIENT_MULTI_STATEMENTS)
    on.exit(dbDisconnect(con))
  }
  
  sql <- sprintf("update genes set transcription_factor=true where species_id=%d and name in (%s);",
    species.id, paste("'", tfs, "'", sep="", collapse=","));
  cat(sql, "\n")
  dbGetQuery(con, sql)
  return(dbGetQuery(con, sprintf("select name from genes where transcription_factor=true and species_id=%d", species.id))$name)
}


# Example:
# =======
# to create and populate the database with dvu data, do the following steps,
# in the directory: /Users/cbare/Documents/work/projects/network_portal/network_portal

# == create database ==
# bash: mysql -p -u network_portal < db/create_tables.sql

# == import gene annotations ==
# bash: ruby script/genes_from_ncbi.rb
# bash: ruby script/dvu_discontinued_genes.rb

# == import biclusters ==
# extract.network(env, network.name="Desulfovibrio network", data.source="MO & cMonkey 4.8.2", description="testing...")

# == import expression data ==
# extract.ratios(e=env, network.id=1, species.id=1)
