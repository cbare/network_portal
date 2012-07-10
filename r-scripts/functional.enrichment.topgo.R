## Compute GO enrichment for biclusters with TopGo
## (http://www.bioconductor.org/packages/2.9/bioc/html/topGO.html)
## based on Chris Plaisier's script: https://gist.github.com/2998046
##
## Copyright (C) 2012 Institute for Systems Biology, Seattle, Washington, USA.
## Christopher Bare

## Given an organism with populated tables for genes and GO functions,
## compute functional enrichment using TopGO, which accounts for the
## topology of the GO graph.

library(RPostgreSQL)
library(plyr)
library(topGO)


# database connect info
config <- environment()
config$db.user = "dj_ango"
config$db.password = "django"
config$db.name = "network_portal"
config$db.host = "localhost"

# set species here!
config$species = 'hal';

# set this in case of multiple networks for one species
config$network.id = NULL;

topgo.ontology = c('BP', 'CC', 'MF')
names(topgo.ontology) <- c('biological_process', 'cellular_component', 'molecular_function')


# get a table of gene ids, names and GO identifiers
tryCatch(
expr={
  postgreSQL.driver <- dbDriver("PostgreSQL")
  con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)

  for (namespace in names(topgo.ontology)) {
    
    # get species id
    sql <- sprintf(paste(
      "select * ",
      "from networks_species ",
      "where short_name='%s';"), config$species)
    result <- dbGetQuery(con, sql)
    species.id = result$id
    
    # get network id
    sql <- sprintf(paste(
      "select * ",
      "from networks_network ",
      "where species_id=%d;"), species.id)
    result <- dbGetQuery(con, sql)
    network.id = result$id
    
    # test if network id is configured properly
    if (length(network.id) != 1) {
      if (is.null(config$network.id) || length(network.id)==0) {
        msg <- sprintf('Found %d networks for species: %s', length(network.id), config$species)
        stop(msg)
      }
    }
    else if (!is.null(config$network.id)) {
      if (config$network.id %in% network.id) {
        network.id = config$network.id
      }
      else {
        msg <- sprintf('Configured network ID %d doesn\'t match available networks for species: %s', config$network.id, config$species)
        stop(msg)
      }
    }
    else {
      msg <- sprintf('Need to configure network id for species: %s {%s}', config$species, paste(network.id, collapse=', '))
      stop(msg)
    }
    
    # select g.id, g.name, f.native_id
    # from networks_gene g
    #   join networks_gene_function gf on g.id=gf.gene_id
    #   join networks_function f on gf.function_id=f.id
    # where 
    #   f.type='go' and f.namespace='biological_process'
    #   and g.species_id=1;
    
    # get mapping of gene to GO function for all genes in that species that have GO annotations
    sql <- sprintf(paste(
      "select g.id, g.name, f.native_id ",
      "from networks_gene g ",
      "  join networks_gene_function gf on g.id=gf.gene_id ",
      "  join networks_function f on gf.function_id=f.id ",
      "where  ",
      "f.type='go' and f.namespace='%s' ",
      "and g.species_id=%d;"), namespace, species.id)
    go.annotations <- dbGetQuery(con, sql)

    # Check for unique gene names and complain if we find duplicates.
    # The condition we're testing here is that there aren't two unique gene
    # ids with the same name.
    dups <- sapply(unique(go.annotations$name), function(name) length(unique(go.annotations[go.annotations$name==name, 'id'])) > 1)
    if (any(dups)) {
      msg <- sprintf('duplicate gene names found: %s', paste(names(dups)[dups], collapse=', '))
      stop(msg)
    }

    # build a list named by gene name where each entry is a character
    # vector of GO identifiers
    gene2GO <- dlply(go.annotations, .(name), function(g) {
      g$native_id
    })

    # The way topGO uses the parameter allGenes is a bit strange.
    # It requires either a numeric vector or a vector of 2-valued factors. Either way,
    # the names of the vector are the list of all genes. 
    # Question: Should we use all genes or all genes with GO annotations? This script uses
    # just the genes with GO annotations, due to the join in the SQL query.
    allGenes <- integer(length(gene2GO))
    # We have a vector of all zeros. Set the first item to 1, just so we'll have 2 values.
    allGenes[1] <- 1
    # Convert to factor
    allGenes <- factor(allGenes)
    names(allGenes) <- names(gene2GO)

    # Build GO DAG topology and annotate genes
    GOdata <- new("topGOdata", ontology=topgo.ontology[namespace], allGenes = allGenes, annot = annFUN.gene2GO, gene2GO = gene2GO)


    # get a table of biclusters and their member genes from the database
    sql <- sprintf(paste(
      "select b.id as bicluster_id, g.id as gene_id, g.name as gene_name ",
      "from networks_bicluster b ",
      "  join networks_bicluster_genes bg on b.id=bg.bicluster_id ",
      "  join networks_gene g on bg.gene_id=g.id ",
      "where b.network_id=%d;"
      ), network.id)
    biclusters <- dbGetQuery(con, sql)


    # build a list of biclusters where each entry is a list of genes in that bicluster
    # and the names are the bicluster IDs
    bicluster.genes <- dlply(biclusters, .(bicluster_id), function(b) {
      b$gene_name
    })

    # get translation from GO ID to IDs in the table networks_function
    sql <- sprintf(paste(
      "select id, native_id",
      "from networks_function",
      "where type='go' and namespace='%s';"),
      namespace)
    function.ids.tmp <- dbGetQuery(con, sql)

    # set up to translate GO IDs to database IDs in the table networks_function
    function.ids <- as.integer(function.ids.tmp$id)
    names(function.ids) <- function.ids.tmp$native_id

    # for each bicluster, compute TOPGO enrichment
    for (i in seq(along=bicluster.genes)) {
      cat('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

      # convert bicluster ID to integer
      bicluster.id = as.integer(names(bicluster.genes)[i])

      print(sprintf("bicluster %d (%d genes)", bicluster.id, length(bicluster.genes[[i]])))
      
      go.annotations <- do.call(c, lapply(bicluster.genes[[i]], function(g) { gene2GO[[g]] }))
      print(sprintf("bicluster %d has %d GO annotations.", bicluster.id, length(go.annotations)))
      
      if (length(go.annotations)>0) {

        # set the genes in the bicluster in TOPGO's funny factor format
        GOdata@allScores <- factor(as.integer(names(allGenes) %in% bicluster.genes[[i]]))

        # run the enrichment test
        result = runTest(GOdata, algorithm = 'classic', statistic = 'fisher')
        p.bh <- p.adjust(result@score, method='BH')
        p.b  <- p.adjust(result@score, method='bonferroni')

        # thresholding is important because every bicluster will have annotations at the
        # higher levels of the GO hierarchy, but they will not be very significant.
        threshold = which(p.bh <= 0.05)

        table.topgo <- GenTable(GOdata, result)
        print(table.topgo)

        if (length(threshold) > 0) {
          df <- data.frame(bicluster.id=bicluster.id, function.id=function.ids[names(result@score)[threshold]], function.native.id=names(result@score)[threshold], p=result@score[threshold], p.bh=p.bh[threshold], p.b=p.b[threshold])
          print(df)

          sql <- sprintf(paste(
            "insert into networks_bicluster_function",
            "(bicluster_id, function_id, k, p, p_bh, p_b, method)",
            "values (%d, %d, %d, %f, %f, %f, 'topgo');"),
            bicluster.id, df$function.id, length(bicluster.genes[[i]]), df$p, df$p.bh, df$p.b)
          for (sql1 in sql) {
            dbGetQuery(con, sql1)
          }
        }
        else {
          print(sprintf("bicluster %d has no enriched functions.", bicluster.id))
        }
        
      }
    }

  }

},
finally={
  dbDisconnect(con)
})
