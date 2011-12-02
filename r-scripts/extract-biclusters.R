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
## * A postgreSQL database w/ appropriate schema
##
## * Initial data in the species and chromosomes table for the species of interest
##
## * gene annotations for your species
##   see: insert_genes.py
##
##
## Example:
## =======
## to create and populate the database with dvu data, do the following steps,
## in the directory: /Users/cbare/Documents/work/projects/network_portal/
##
## == create and initialize database ==
## see db/README
##
## == load data ==
## in R: load('data/dvu/cm_session.RData')
## load('data/dvu/zzz_dvu_nwInf_coeffs.RData')
##
## == source this script ==
## source('network_portal/r-scripts/extract-biclusters.R')
##
## == check that genes exist ==
## check.genes(con=NULL, e, species.id=3)
## if this reports missing genes, try adding them:
## chromosome.id.map <- c(6)
## names(chromosome.id.map) <- c('NC_005791.1')
## extract.genes(e, species.id=3, chromosome.id.map)
## 
## == import biclusters ==
## extract.network(env, network.name="Desulfovibrio network", data.source="MO & cMonkey 4.8.2", description="testing...")
##
## == import expression data ==
## >>>>>already done in extract.network<<<<< extract.ratios(con=NULL, e=env, network.id=1, species.id=1)
##
## == import inferelator output ==
## extract.influences(con=NULL, e.coeffs, network.id, species.id)
##
##
## Christopher Bare

library(RPostgreSQL)

config <- environment()
config$db.user = "dj_ango"
config$db.password = "django"
config$db.name = "network_portal"
config$db.host = "localhost"



# import a network from cMonkey output
# e            - the environment produced by cMonkey
# network.name - name of new network, set to species if omitted
# data.source  - automatically populated w/ cmonkey if omitted
# description  - textual description of the network
extract.network <- function(e, network.name=NULL, data.source=NULL, description=NULL) {

  # connect ot database and disconnect on exit
  postgreSQL.driver <- dbDriver("PostgreSQL")
  con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)
  on.exit(function() {
    dbDisconnect(con)
    dbUnloadDriver(postgreSQL.driver)
  })

  species.id <- get.species.id(con, env=e)

  #insert a row in the nework tab, returning network id
  network.id <- insert.network(con, species.id, network.name, data.source, description)

  # insert conditions
  extract.conditions(con, e, network.id)

  # extract each bicluster and put it in the db
  for (k in 1:e$k.clust) {
    extract.bicluster(con, e, k, network.id, species.id)
  }

  # extract gene expression data from ratios matrix
  extract.ratios(con, e, network.id, species.id)
}


# insert an entry into the network table
insert.network <- function(con, species.id, network.name=NULL, data.source=NULL, description=NULL) {
  # insert row in network table
  sql <- sprintf("insert into networks_network (species_id, name, data_source, description, created_at) values (%d, '%s', '%s', '%s', NOW());",
                 species.id, network.name, data.source, description)
  cat(sql, "\n")
  db.result <- dbSendQuery(con, sql)
  dbClearResult(db.result)

  # get the ID of the newly inserted row
  network.id <- dbGetQuery(con, "select lastval();")[1,1]

  cat('inserted network ID: ', network.id, "\n")
  
  return(network.id)
}


# populate conditions table
extract.conditions <- function(con, e, network.id) {
  conditions <- rownames(e$col.membership)
  for (condition in conditions) {
    dbSendQuery(con, sprintf("insert into networks_condition (name, network_id) values ('%s', %d);", condition, network.id))
  }
  cat('inserted', length(conditions), 'conditions', "\n")
}


# extract bicluster number k from environment e
# creating an entry in the biclusters table along with associations
# in biclusters_genes, biclusters_conditions
extract.bicluster <- function(con, e, k, network.id, species.id) {
  
  cat("~~~~~~~~~~~~~~~~  extracting cluster ", k, "\n")
  
  b <- e$get.clust(k)

  # insert row into biclusters table
  sql <- sprintf("insert into networks_bicluster (network_id, k, residual) values (%d, %d, %f);", network.id, k, b$resid)
  cat(sql, "\n")
  db.result <- dbSendQuery(con, sql)
  dbClearResult(db.result)

  # get the ID of the newly inserted bicluster
  bicluster.id <- dbGetQuery(con, "select lastval();")[1,1]
  gene.ids <- get.gene.ids(con, species.id)
  condition.ids <- get.condition.ids(con, network.id)

  # add genes to bicluster
  genes <- b$rows
  for (gene in genes) {
    gene.id <- gene.ids[gene]
    if (is.na(gene.id)) {
      stop(sprintf("Unknown gene \"%s\".", gene))
    }
    sql <- sprintf("insert into networks_bicluster_genes (bicluster_id, gene_id) values (%d, %d);", bicluster.id, gene.id)
    dbSendQuery(con, sql)
  }
  cat(length(genes), "genes\n")
  
  # add conditions to bicluster
  conditions <- b$cols
  for (condition in conditions) {
    condition.id <- condition.ids[condition]
    if (is.na(condition.id) || (is.null(condition.id))) {
      stop(sprintf("Unknown condition \"%s\".", condition))
    }
    sql <- sprintf("insert into networks_bicluster_conditions (bicluster_id, condition_id) values(%d, %d);", bicluster.id, condition.id)
    dbSendQuery(con, sql)
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
      sql <- sprintf("insert into networks_motif (bicluster_id, position, sites, e_value) values (%d, %d, %d, %f);",
                     bicluster.id, m, meme.out$sites, meme.out$e.value)
      db.result <- dbSendQuery(con, sql)
      dbClearResult(db.result)

      # get the ID of the newly inserted motif
      motif.id <- dbGetQuery(con, "select lastval();")[1,1]

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

# import the ratios matrix into the expression table
# this takes a couple hours to finish adding 2.5 million rows
extract.ratios <- function(con=NULL, e, network.id, species.id) {

  # connect to db, if needed
  if (is.null(con)) {
    postgreSQL.driver <- dbDriver("PostgreSQL")
    con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)
    on.exit(function() {
      dbDisconnect(con)
      dbUnloadDriver(postgreSQL.driver)
    })
  }

  ratios <- e$ratios[[1]]
  gene.ids <- get.gene.ids(con, species.id)
  condition.ids <- get.condition.ids(con, network.id)

  cat("Begin import of", nrow(ratios), "by", ncol(ratios), "matrix.\n")
  cat(format(Sys.time(), "%a %b %d %X %Y"), "\n")

  # drop indexes
  cat("droping indices\n")
  dbSendQuery(con, "DROP INDEX IF EXISTS expression_gene_id_idx;")
  dbSendQuery(con, "DROP INDEX IF EXISTS expression_condition_id_idx;")
  cat("indices dropped\n")

  # do inserts in sorted gene order
  order.by.rowname <- order( rownames(ratios) )
  
  # Note: I had hoped that using a clustered index on gene id and adding inserting
  # the data in gene order would speed up the insertion process... no such luck.
  # Prepared statements, which should help, seem not to be implemented in RPostgreSQL.
  
  # Removing indexes and re-creating them might help, too.
  
  # Likely, reformatting the matrix, writing to a text file and using the "copy"
  # bulk loading command would be quicker?

  tryCatch(
    {

      for (r in order.by.rowname) {
        gene.id <- gene.ids[rownames(ratios)[r]]
        cat(rownames(ratios)[r], "\n")
        dbBeginTransaction(con)
        for (c in 1:ncol(ratios)) {
          if (!is.na(ratios[r,c])) {
            cond.id <- condition.ids[colnames(ratios)[c]]
            sql <- sprintf("insert into expression (gene_id, condition_id, value) values (%d, %d, %f);", gene.id, cond.id, ratios[r,c])
            dbGetQuery(con, sql)
          }
        }
        dbCommit(con)
      }
      cat("inserted expression values for:", nrow(ratios), "genes under", ncol(ratios),"conditions\n")

      cat("rebuilding indices\n")
      dbGetQuery(con, "CREATE INDEX expression_gene_id_idx ON expression (gene_id);")
      dbGetQuery(con, "CREATE INDEX expression_condition_id_idx ON expression (condition_id);")
      cat("finished rebuilding indices\n")
    },
    warning = function(e) {
      cat("warning: ", conditionMessage(e), "\n")
      dbRollback(con)
    },
    error = function(e) {
      cat("error: ", conditionMessage(e), "\n")
      dbRollback(con)
    }
  )
  
  cat(format(Sys.time(), "%a %b %d %X %Y"), "\n")
}

# Don't use: very very slow
# export.ratios.to.file <- function(e) {
#   
#   library(reshape)
#   
#   ratios <- env$ratios[[1]]
# 
#   # connect to db, if needed
#   if (is.null(con)) {
#     postgreSQL.driver <- dbDriver("PostgreSQL")
#     con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)
#     on.exit(function() {
#       dbDisconnect(con)
#       dbUnloadDriver(postgreSQL.driver)
#     })
#   }
# 
#   gene.ids <- get.gene.ids(con, species.id)
#   condition.ids <- get.condition.ids(con, network.id)
#   
#   m.ratios <- melt(ratios)
#   # these are way too slow!
#   gene.ids <- sapply( m.ratios[,1], function(g) { gene.ids[g] } )
#   cond.ids <- sapply( m.ratios[,2], function(g) { condition.ids[g] } )
#   
#   db.ratios <- na.omit(data.frame(`gene_id`=gene.ids, `condition_id`=condition.ids, value=m.ratios[,3]))
#   
#   filename = tempfile(pattern = "network.portal.ratios", fileext = "tsv")
#   write.table(db.ratios, file=filename, sep="\t", quote=FALSE)
#   
#   return(filename)
# }

# create a helper function that finds an influence id if it exists or if not, adds it
# and returns the new id. Creating a closure to encapsulate the connection and gene.ids
# and allow the function to recursively call itself in the case of combiners.
# con = database connection
# gene.ids is a vector of integers named by the gene name
create.find.or.add.influence <- function(con, gene.ids) {
  
  # take the name of a predictor, add it if necessary and return it's id
  find.or.add.influence <- function(predictor) {
    # add influence, if not already present
    # influences can be one of 3 types:
    #  1) combiner, a logical combination of other influences (ef or tf)
    #     for example: "DVU3334~~DVU0230~~min"
    #  2) gene aka tf for transcription factor
    #  3) ef for environmental factor
    sql <- sprintf("select id from networks_influence where name = '%s';", predictor)
    result <- dbGetQuery(con, sql)
    if (nrow(result)>0) {
      influence.id <- result[1,1]
    }
    else {
      if (grepl("~~", predictor)) {
        # grab the operator
        op <- strsplit(predictor, "~~")[3]
        sql <- sprintf("insert into networks_influence (name, operation, type) values ('%s', '%s', 'combiner');", predictor, op)
        dbGetQuery(con, sql)
        influence.id <- dbGetQuery(con, "select lastval();")[1,1]
        # the first 2 of these should be genes or environmental factors
        operands <- strsplit(predictor, "~~")[[1]][1:2]
        for (operand in operands) {
          # recursively call this function to add parts of a combiner
          operand.id <- find.or.add.influence(operand)
          # link combiner to part
          sql <- sprintf("insert into networks_influence_parts (from_influence_id, to_influence_id) values ('%d', '%d')", influence.id, operand.id)
          dbGetQuery(con, sql)
        }
      }
      else if (predictor %in% names(gene.ids)) {
        gene.id <- gene.ids[predictor]
        sql <- sprintf("insert into networks_influence (name, gene_id, type) values ('%s', %d, 'tf');", predictor, gene.id)
        dbGetQuery(con, sql)
        influence.id <- dbGetQuery(con, "select lastval();")[1,1]
      }
      else {
        sql <- sprintf("insert into networks_influence (name, type) values ('%s', 'ef');", predictor)
        dbGetQuery(con, sql)
        influence.id <- dbGetQuery(con, "select lastval();")[1,1]
      }
    }
    return(influence.id)
  }
  return(find.or.add.influence)
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
    postgreSQL.driver <- dbDriver("PostgreSQL")
    con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)
    on.exit(function() {
      dbDisconnect(con)
      dbUnloadDriver(postgreSQL.driver)
    })
  }

  cat("Marking transcription factors...\n")
  tfs <- mark.tfs(con, tfs=predictor.mats$genetic.names, species.id=species.id)
  cat(sprintf("Marked %d transcription factors.\n", length(tfs)))
  
  # collect a uniq-ified list of predictors in the network
  # all.influences <- unique(c(sapply(e.coeffs, function(bicluster.coeffs) { names(bicluster.coeffs$coeffs) }), recursive=T))

  bicluster.ids <- get.bicluster.ids(con, network.id)
  gene.ids <- get.gene.ids(con, species.id)
  
  find.or.add.influence <- create.find.or.add.influence(con, gene.ids)
  
  tryCatch(
    {
      dbBeginTransaction(con)

      for (bicluster.coeffs in e.coeffs) {

        bicluster.id = bicluster.ids[ bicluster.ids$k == bicluster.coeffs$k, 'id' ]
        cat("extracting influences for bicluster", bicluster.id, "\n")

        for (predictor in names(bicluster.coeffs$coeffs)) {
          
          # create influence (and child influences in the case of combiners)
          influence.id <- find.or.add.influence(predictor)
          
          # associate bicluster with predictor
          sql <- sprintf("insert into networks_bicluster_influences (bicluster_id, influence_id) values (%d, %d);",
                          bicluster.id, influence.id)
          dbGetQuery(con, sql)
        }
      }

      dbCommit(con)
    },
    warning = function(e) {
      cat("warning: ", conditionMessage(e), "\n")
      dbRollback(con)
    },
    error = function(e) {
      cat("error: ", conditionMessage(e), "\n")
      dbRollback(con)
    })
}

# known transcription factors are in predictor.mats#genetic.names
# tfs <- mark.tfs(con, tfs=predictor.mats$genetic.names, species.id=1)
mark.tfs <- function(con=NULL, tfs, species.id) {
  # connect to db, if needed
  if (is.null(con)) {
    postgreSQL.driver <- dbDriver("PostgreSQL")
    con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)
    on.exit(function() {
      dbDisconnect(con)
      dbUnloadDriver(postgreSQL.driver)
    })
  }
  
  sql <- sprintf("update networks_gene set transcription_factor=true where species_id=%d and name in (%s);",
    species.id, paste("'", tfs, "'", sep="", collapse=","));
  cat(sql, "\n")
  dbGetQuery(con, sql)
  return(dbGetQuery(con, sprintf("select name from networks_gene where transcription_factor=true and species_id=%d", species.id))$name)
}




# is the given gene identifier in the feature table?
is.feature.id <- function(gene) {
  gene %in% e$genome.info$feature.tab$id
}

# map the given gene name to it's identifier in the feature table
# or to "???" if no such identifier can be found in the synonyms list.
# example: feature.ids <- sapply( rownames(e$row.membership), get.feature.id )
get.feature.id <- function(gene) {
    if (is.feature.id(gene)) {
       return(gene)
    }
    else {
        result <- Filter( is.feature.id, e$genome.info$synonyms[[gene]] )
        if (length(result)==0) { return(gene) }
        return(result)
    }
}

to.strand <- function(string) {
  string <- tolower(string)
  if (string %in% c('+', 'd', 'forward', 'plus', 'for', 'f')) {
    return('+')
  }
  else if (string %in% c('-', 'r', 'reverse', 'minus', 'rev')) {
    return('-')
  }
  else {
    return('.')
  }
}

to.db <- function(a) {
  if (is.null(a) || is.na(a)) {
    return('null')
  }
  if (typeof(a)=='character') {
    return(paste("'", a, "'", sep=""))
  }
  return(a)
}

check.genes <- function(con=NULL, e, species.id) {
  if (is.null(con)) {
    postgreSQL.driver <- dbDriver("PostgreSQL")
    con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)
    on.exit(function() {
      dbDisconnect(con)
      dbUnloadDriver(postgreSQL.driver)
    })
  }
  
  # might this ever be necessary??
  # genes <- union(rownames(e$row.membership), rownames(e$ratios[[1]]))
  genes <- rownames(e$row.membership)
  
  cat("checking whether genes in network are in the DB...\n")
  gene.ids <- get.gene.ids(con, species.id)
  genes.not.found <- Filter( function(g) {!(g %in% names(gene.ids))}, genes )
  if (length(genes.not.found) == 0) {
    cat("all genes are in the DB!\n")
  }
  else {
    cat(sprintf("%d genes are missing from the DB!!\n", length(genes.not.found)))
    print(genes.not.found)
  }
  return(genes.not.found)
}

extract.genes <- function(e, species.id, chromosome.id.map) {
  # For dvu, all the genes in the ratios matrix aren't represented in the feature
  # names table:

  # > setdiff(rownames(env$ratios[[1]]), as.character(env$genome.info$feature.names$name))
  #  [1] "DVU0699"      "DVU1831"      "DVU2001"      "DVU2049"      "DVU2950"     
  #  [6] "DVU3126"      "DVU3280"      "DVU3304"      "VIMSS_208926" "DVU0490"     
  # [11] "DVU0557"
  
  # For mmp, there is one gene missing from the features table: "Mma-sR04"

  # I eventually got dvu genes from
  # NCBI, including an extra step to get discontinued and pseudo genes. See:
  # script/genes_from_ncbi.rb
  # script/dvu_discontinued_genes.rb
  
  # note that genes table must contain an entry for each row in e$ratios

  postgreSQL.driver <- dbDriver("PostgreSQL")
  con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)
  on.exit(function() {
    dbDisconnect(con)
    dbUnloadDriver(postgreSQL.driver)
  })

  genes.not.found <- check.genes(con=NULL, e, species.id)
  if (length(genes.not.found) > 0) {
    for (gene in genes.not.found) {
      feature.id <- get.feature.id( gene )
      i = e$genome.info$feature.tab$id==feature.id
      if (any(i)) {
        if (sum(i) > 1) {
          warning(sprintf("ambiguous gene name \"%s\".", feature.id))
          i = which(i)[1]
        }
        chromosome.id <- chromosome.id.map[e$genome.info$feature.tab$contig[i]]
        common_name <- e$genome.info$feature.tab$name[i]
        if (common_name==gene) common_name<-NULL
        sql <- sprintf("insert into networks_gene 
                        (species_id, chromosome_id, name, common_name, geneid, type, start, \"end\", strand, description)
                        values (%d, %d, %s, %s, %s, %s, %d, %d, %s, %s);",
                        species.id, chromosome.id, to.db(gene), to.db(common_name),
                        to.db(e$genome.info$feature.tab$GeneID[i]),
                        to.db(tolower(e$genome.info$feature.tab$type[i])),
                        e$genome.info$feature.tab$start[i],
                        e$genome.info$feature.tab$end[i],
                        to.db(to.strand(e$genome.info$feature.tab$strand[i])),
                        to.db(e$genome.info$feature.tab$description[i]))
        cat(sql,"\n")
        dbGetQuery(con, sql)
      }
      else {
        warning(sprintf("unidentifiable gene name \"%s\".", gene))
        sql <- sprintf("insert into networks_gene 
                        (species_id, name, type)
                        values (%d, %s, %s);",species.id, to.db(gene), to.db('unknown'))
        cat(sql,"\n")
        dbGetQuery(con, sql)
      }
    }
  }
}


# reset a sequence to zero, not really usefull unless you're OCD about your ids
reset.sequence <- function(con=NULL, sequence) {
  # connect to db, if needed
  if (is.null(con)) {
    postgreSQL.driver <- dbDriver("PostgreSQL")
    con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)
    on.exit(function() {
      dbDisconnect(con)
      dbUnloadDriver(postgreSQL.driver)
    })
  }
  sql <- sprintf("SELECT setval('%s', 1);", sequence)
  dbGetQuery(con, sql)
}

# get species_id for e$organism
get.species.id <- function(con, species=NULL, env=NULL) {
  if (is.null(species) && !is.null(env)) {
    species <- env$organism
  }
  sql <- sprintf("select id from networks_species where name = '%s' or short_name = '%s';", species, species)
  # cat(sql, "\n")
  return( dbGetQuery(con, sql)[1,1] )
}

# create a translation table between gene name and id for the given species
get.gene.ids <- function(con, species.id) {
  sql <- sprintf("select id, name from networks_gene where species_id=%d order by name;", species.id)
  df <- dbGetQuery(con, sql)
  name.id.map <- df$id
  names(name.id.map) <- df$name
  return(name.id.map)
}

# create a translation table between condition name and id for the given network
get.condition.ids <- function(con, network.id) {
  sql <- sprintf("select id, name from networks_condition where network_id=%d order by name;", network.id)
  df <- dbGetQuery(con, sql)
  name.id.map <- df$id
  names(name.id.map) <- df$name
  return(name.id.map)
}

# create lookup table to find bicluster ids for a network by k
get.bicluster.ids <- function(con, network.id) {
  sql <- sprintf("select k, id from networks_bicluster where network_id=%d order by k;", network.id)
  bicluster.ids <- dbGetQuery(con, sql)
  return(bicluster.ids)
}

get.chromosome.ids <- function(con, species.id) {
  sql <- sprintf("select id, name, refseq from networks_chromosome where species_id=%d;", species.id)
  chromosome.ids <- dbGetQuery(con, sql)
  result <- rbind( chromosome.ids$id, chromosome.ids$id )
  names(result) <- rbind( chromosome.ids$name, chromosome.ids$refseq )
  return(result)
}

assert.equals <- function(func_name, value, expected) {
  if (value == expected) { cat(func_name, "ok\n") }
  else { cat(func_name, "failed. expected", expected, "but got", value, "\n") }
}


run.tests <- function(db.name="network_portal") {
  postgreSQL.driver <- dbDriver("PostgreSQL")
  con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)
  on.exit(function() {
    dbDisconnect(con)
    dbUnloadDriver(postgreSQL.driver)
  })
  
  species.id <- get.species.id(con, species="Halobacterium salinarum NRC-1")
  assert.equals("get.species.id", species.id, 2)
  
  species.id <- get.species.id(con, species="Desulfovibrio vulgaris Hildenborough")
  assert.equals("get.species.id", species.id, 1)
  
  gene.ids <- get.gene.ids(con, species.id)
  assert.equals("get.gene.ids", gene.ids["DVU0003"], 3)
}


