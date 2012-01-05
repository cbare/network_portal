## Compute functional enrichment for biclusters
## 
## Copyright (C) 2011 Institute for Systems Biology, Seattle, Washington, USA.
## Christopher Bare

library(RPostgreSQL)

# database connect info
config <- environment()
config$db.user = "dj_ango"
config$db.password = "django"
config$db.name = "network_portal"
config$db.host = "localhost"


# for each bicluster count genes grouped by function
# return a data.frame w/ columns bicluster_id, function_id, count
get.bicluster.function.counts <- function(con, network.id, type, ancestor.map=NULL) {

  # don't limit this to a specific namespace, 'cause functions are annotated at
  # the most specific level possible. We map them up to higher levels through
  # the ancestor.map

  #count number of genes for each function in each bicluster for a species
  sql <- sprintf(paste(
    "select b.id as bicluster_id, f.id as function_id, count(bg.gene_id) as count",
    "from networks_bicluster b",
    "join networks_bicluster_genes bg on b.id=bg.bicluster_id",
    "join networks_gene_function gf on gf.gene_id=bg.gene_id",
    "join networks_function f on gf.function_id=f.id",
    "where b.network_id = %d",
    "and f.type='%s'",
    "group by b.id, f.id",
    "order by b.id, f.id;"),
    network.id, type)
  df <- dbGetQuery(con, sql)
  
  # map lower level functions to their ancestors
  if (is.null(ancestor.map))
    ancestor.map <- get.ancestor.map(con, df$function_id)
  merged.df <- merge(df, ancestor.map, by='function_id')
  mm <- data.frame(`bicluster_id`=merged.df$`bicluster_id`, `function_id`=merged.df$`ancestor_id`, `count`=merged.df$`count`)
  mm2 <- ddply(mm, .(bicluster_id, function_id), function(r) count=sum(r$count))
  colnames(mm2)[3] <- 'count'
  return(mm2)
}

# for each function, count all genes in genome with that function
# return a data.frame w/ columns function_id, count
get.function.gene.counts <- function(con, gene.ids, type=NULL, ancestor.map=NULL) {
  
  # don't limit this to a specific namespace, 'cause functions are annotated at
  # the most specific level possible. We map them up to higher levels through
  # the ancestor.map

  # count total number of genes in the genome for each function
  # (independent of a particular network, except that the set of
  #  genes considered here should be the same as those considered
  #  in the biclustering and network inference.)
  sql <- sprintf(paste(
    "select gf.function_id, count(gf.gene_id)",
    "from networks_gene_function gf",
    "join networks_gene g on g.id = gf.gene_id",
    "join networks_function f on gf.function_id=f.id",
    "where g.id in (%s)",
    if (is.null(type)) { "" } else { sprintf("and f.type='%s'", type) },
    "group by gf.function_id",
    "order by gf.function_id;"),
    paste(gene.ids,collapse=","), type)
  df <- dbGetQuery(con, sql)
  
  if (is.null(ancestor.map))
    ancestor.map <- get.ancestor.map(con, df$function_id)
  merged.df <- merge(df, ancestor.map, by='function_id')
  mm <- data.frame(`function_id`=merged.df$`ancestor_id`, `count`=merged.df$`count`)
  mm2 <- ddply(mm, .(function_id), function(r) count=sum(r$count))
  colnames(mm2)[2] <- 'count'
  return(mm2)
}


# compute functional enrichment for all biclusters in the given network
# with the given system and namespace. If gene.ids are not given, use the
# set of genes that appear in at least one bicluster. This will likely not
# include all genes in the organism. If genes were considered, but not
# included in any bicluster, we should include those in the background.
#
# examples:
# enrichment(network.id=1, type='kegg', namespace='kegg pathway')
# enrichment(network.id=1, type='tigr', namespace='tigrfam')
enrichment <- function(network.id, type=NULL, namespace=NULL, gene.ids=NULL) {
  tryCatch(
  expr={
    postgreSQL.driver <- dbDriver("PostgreSQL")
    con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)
    
    # get species id
    sql <- sprintf("select species_id from networks_network where id=%d;", network.id)
    species.id = dbGetQuery(con, sql)[1,1]
    
    if (is.null(gene.ids)) {
      # count genes in this organism
      # Here, we count the genes that are in some bicluster.
      # From the cMonkey side, the number we want might be this
      # nrow(env$ratios[[1]]). although Dave says these are filtered to
      # remove genes that don't change much. Might we want to include those
      # genes in our background as well?
      # If it's true that each gene will be in at least one
      # bicluster, the count below will work. Otherwise, we should
      # probably store the set of genes considered in the clustering so we
      # can properly construct our background.
      sql <- sprintf(paste(
        "select distinct(bg.gene_id)",
        "from networks_bicluster_genes bg",
        "join networks_bicluster b on b.id = bg.bicluster_id",
        "where b.network_id=%d",
        "order by bg.gene_id;"),
        network.id)
      gene.ids <- dbGetQuery(con, sql)[[1]]
    }
    total.genes <- length(gene.ids)
    
    #count number of genes in each bicluster in the network
    sql <- sprintf(paste(
      "select b.id as bicluster_id, count(bg.gene_id) as gene_count",
      "from networks_bicluster b ",
      "join networks_bicluster_genes bg on b.id=bg.bicluster_id",
      "where b.network_id = %d",
      "group by b.id",
      "order by b.id;"),
      network.id)
    bicluster.gene.counts <- dbGetQuery(con, sql)
    
    ancestor.map <- get.ancestor.map(con,type=type, namespace=namespace)
    
    # for each bicluster count genes grouped by function
    # return a data.frame w/ columns bicluster_id, function_id, count
    bicluster.function.counts <- get.bicluster.function.counts(con, network.id, type, ancestor.map)
    
    # for each function, count all genes in genome with that function
    # return a data.frame w/ columns function_id, count
    function.gene.counts <- get.function.gene.counts(con, gene.ids, type, ancestor.map)
    
    # phyper(q, m, n, k)
    # q = number of white balls drawn without replacement from an urn
    # m = the number of white balls in the urn
    # n = the number of black balls in the urn
    # k = the number of balls drawn from the urn
    
    # ...in terms of this problem...
    # we want one row per bicluster_id / function_id combination
    # q = number of genes with function f in bicluster b
    # m = total number of genes with function f
    # n = total number of genes without function f
    # k = number of genes in the bicluster b
    q <- bicluster.function.counts$count
    m <- function.gene.counts$count[ match(bicluster.function.counts$function_id, function.gene.counts$function_id) ]
    n <- total.genes - m
    k <- bicluster.gene.counts$gene_count[ match(bicluster.function.counts$bicluster_id, bicluster.gene.counts$bicluster_id) ]
    p <- phyper( q, m, n, k, lower.tail=F )
    
    # do benjamini-hochberg and bonferroni multiple testing correction
    p.bh <- p.adjust(p, method='BH')
    p.b  <- p.adjust(p, method='bonferroni')
    
    sql <- sprintf(paste(
      "select id, native_id, name, namespace ",
      "from networks_function",
      "where type='%s';"),
      type)
    functions <- dbGetQuery(con, sql)
    functions <- functions[ match(bicluster.function.counts$function_id, functions$id), ]
    
    # add columns to data frame
    return(data.frame(bicluster.id=bicluster.function.counts$bicluster_id,
                      function.id=bicluster.function.counts$function_id,
                      native_id=functions$native_id,
                      name=functions$name,
                      namespace=functions$namespace,
                      gene.count=q,
                      m,n,k,p,p.bh, p.b))
  },
  finally={
    dbDisconnect(con)
    postgreSQL.driver <- dbDriver("PostgreSQL")
  })
}

# put an enrichment data.frame into the DB
insert.enrichment <- function(en) {
  tryCatch(
  expr={
    postgreSQL.driver <- dbDriver("PostgreSQL")
    con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)

    for (i in 1:nrow(en)) {
      row <- en[i,]
      sql <- sprintf(paste(
        "insert into networks_bicluster_function",
        "(bicluster_id, function_id, gene_count, m, n, k, p, p_bh, p_b)",
        "values (%d, %d, %d, %d, %d, %d, %f, %f, %f);"),
            row$bicluster.id, row$function.id, row$gene.count,
            row$m, row$n, row$k,
            row$p, row$p.bh, row$p.b)
      dbGetQuery(con, sql)
    }
  },
  finally={
    dbDisconnect(con)
    postgreSQL.driver <- dbDriver("PostgreSQL")
  })
}

get.gene2go <- function(species.id, namespace='biological_process') {
  tryCatch(
  expr={
    postgreSQL.driver <- dbDriver("PostgreSQL")
    con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)

    sql <- sprintf(paste(
      "select g.id, g.name, f.native_id",
      "from networks_function f",
      "join networks_gene_function gf on gf.function_id=f.id",
      "join networks_gene g on gf.gene_id=g.id",
      "where g.species_id=%d",
      "and f.type='go'",
      "and f.namespace='%s'",
      "order by gf.gene_id;"),
      species.id, namespace)
    go.annos <- dbGetQuery(con, sql)
    genes <- unique(go.annos$name)
    gene2go <- lapply(genes, function(g) { go.annos$native_id[ go.annos$name==g ] })
    names(gene2go) <- genes
    return(gene2go)
  },
  finally={
    dbDisconnect(con)
    postgreSQL.driver <- dbDriver("PostgreSQL")
  })
}

# pull the networks table into a data frame
get.networks <- function() {
  tryCatch(
  expr={
    postgreSQL.driver <- dbDriver("PostgreSQL")
    con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)
    
    sql <- "select * from networks_network;"
    return(dbGetQuery(con, sql))
  },
  finally={
    dbDisconnect(con)
    postgreSQL.driver <- dbDriver("PostgreSQL")
  })
}

let.it.rip <- function(insert=F) {
  systems = list( c(type='kegg', namespace='kegg pathway'),
                  c(type='tigr', namespace='tigrfam'),
                  c(type='go',   namespace='biological_process'),
                  c(type='go',   namespace='molecular_function'),
                  c(type='cog',  namespace='cog') )
  
  networks <- get.networks()
  for (id in networks$id) {
    for (system in systems) {
      en <- enrichment(id, system['type'], system['namespace'])
      cat("enrichment network", id, "type=", system['type'], "namespace=", system['namespace'], "\n")
      cat("dim(en) =", dim(en), "\n")
      cat("sum(en$p.bh < 0.05) =", sum(en$p.bh < 0.05), "\n")
      cat("sum(en$p.b < 0.05) =", sum(en$p.b < 0.05), "\n")
      print(head(en))
      if (insert) {
        insert.enrichment(en)
      }
    }
  }
}

# read a mapping from a COG function to its parent category, which can be used to
# compute enrichment at the higher level.
get.hierarchy.map <- function() {
  tryCatch(
  expr={
    postgreSQL.driver <- dbDriver("PostgreSQL")
    con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)
    
    # retreive a set of mappings from cog subcategory to COG, excluding two generic categories
    sql <- paste(
      "select f1.id, f1.name, f2.id, f2.name",
      "from networks_function f1",
      "join networks_function_relationships fr on f1.id = fr.function_id",
      "join networks_function f2 on f2.id = fr.target_id",
      "where fr.type='parent'",
      "and f1.type='cog'",
      "and f1.namespace='cog'",
      "and f2.type='cog'",
      "and f2.namespace='cog subcategory'")
    return(dbGetQuery(con, sql))
  },
  finally={
    dbDisconnect(con)
    postgreSQL.driver <- dbDriver("PostgreSQL")
  })
}

# read a mapping from a COG function to its parent category, which can be used to
# compute enrichment at the higher level.
get.tigr.hierarchy.map <- function() {
  tryCatch(
  expr={
    postgreSQL.driver <- dbDriver("PostgreSQL")
    con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)
    
    # retreive a set of mappings from cog subcategory to COG, excluding two generic categories
    sql <- paste(
      "select f1.id, f1.name, f2.id, f2.name",
      "from networks_function f1",
      "join networks_function_relationships fr on f1.id = fr.function_id",
      "join networks_function f2 on f2.id = fr.target_id",
      "where fr.type='parent'",
      "and f1.type='tigr'",
      "and f1.namespace='tigrfam'",
      "and f2.type='tigr'",
      "and f2.namespace='tigr sub1role'")
    return(dbGetQuery(con, sql))
  },
  finally={
    dbDisconnect(con)
    postgreSQL.driver <- dbDriver("PostgreSQL")
  })
}

# count child functions of the function with the given id
count.children <- function(con, id) {
  sql <- sprintf(paste(
    "select count(fr.function_id)",
    "from networks_function_relationships fr",
    "where fr.type='parent'",
    "and fr.target_id = %d"),
    id)
  return( dbGetQuery(con, sql)[1,1] )
}

# return a data.frame with function ids, names for children of the given function id
get.children <- function(con, id) {
  sql <- sprintf(paste(
    "select f1.id, f1.name",
    "from networks_function f1",
    "join networks_function_relationships fr on f1.id = fr.function_id",
    "join networks_function f2 on f2.id = fr.target_id",
    "where fr.type='parent'",
    "and f2.id = %d"),
    id)
  children <- dbGetQuery(con, sql)
}

# return a vector containing ids of all descendent from the given function id
get.descendants <- function(con, id) {
  if (count.children(con, children[i,'id']) == 0) {
    return( vector() )
  }
  children <- get.children(con, id)
  descendant.ids <- children$id
  for (child_id in children$id) {
    descendant.ids <- append(descendant.ids, get.descendants(con, child_id))
  }
  return( descendant.ids )
}

get.hierarchy.map <- function(type, namespace) {
  tryCatch(
  expr={
    postgreSQL.driver <- dbDriver("PostgreSQL")
    con <- dbConnect(postgreSQL.driver, user=config$db.user, password=config$db.password, dbname=config$db.name, host=config$db.host)
    
    # retrieve a set of mappings from cog subcategory to COG, excluding two generic categories
    sql <- sprintf(paste(
      "select id, name",
      "from networks_function",
      "where type='%s'",
      "and namespace='%s'"),
      type, namespace)
    parents <- dbGetQuery(con, sql)

    hierarchy.map <- list()
    for (i in 1:nrow(parents)) {
      id <- parents[i,'id']
      hierarchy.map[[as.character(id)]] <- data.frame(parent.function.id=id, descendant.id=c(id, get.descendants(con, id)))
    }
    
    do.call(rbind, hierarchy.map)
  },
  finally={
    dbDisconnect(con)
    postgreSQL.driver <- dbDriver("PostgreSQL")
  })
}

# given a set of function ids, return their parent functions as a vector
get.parents <- function(con, function_ids) {
  sql <- sprintf(paste(
    "select target_id",
    "from networks_function_relationships",
    "where function_id in (%s)"),
    paste(function_ids,collapse=","))
  df <- dbGetQuery(con, sql)
  if (nrow(df)>0) return(df$target_id) else return(integer(0))
}

# given a set of function ids, return a vector of their ancestor's ids
get.ancestors <- function(con, function_ids) {
  ancestors <- get.parents(con, function_ids)
  if (length(ancestors) > 0) {
    ancestors <- c(ancestors, get.ancestors(con, ancestors))
  }
  return(ancestors)
}

# return a data.frame with two columns, function_id and ancestor_id mapping a function
# to it's ancestors, where a function is considered to be it's own ancestor.
get.ancestor.map <- function(con, function_ids=NULL, type=NULL, namespace=NULL) {
  if (is.null(function_ids)) {
    sql <- sprintf(paste("select id from networks_function where type='%s';"),type)
    function_ids <- dbGetQuery(con, sql)$id
  }
  results <- list()
  for (id in function_ids) {
    results[[as.character(id)]] <- data.frame(function_id=id, ancestor_id=c(id, get.ancestors(con, id)))
  }
  df <- do.call(rbind, results)
  
  if (!is.null(namespace)) {
    sql <- sprintf(paste(
      "select id",
      "from networks_function",
      "where type='%s'",
      "and namespace='%s';"),
      type,namespace)
    namespaces <- dbGetQuery(con, sql)
    # this is an inner join, so it includes only ancestors that are of the requested namespace
    merged <- merge(df, namespaces, by.x='ancestor_id', by.y='id')
    df <- data.frame(function_id=merged$function_id, ancestor_id=merged$ancestor_id)
  }
  
  return(df)
}

# ...for a different form of hierarchy.map which was a list of descendants for each parent
# find.ancestors <- function(descendants, id) {
#   as.integer(names(which(sapply(descendants, function(d) id %in% d))))
# }

# geneList <- factor(as.integer(names(gene2go) %in% sig.genes))
# names(geneList) <- names(gene2go)
# 
# GOdata <- new("topGOdata", ontology = "BP",
#               allGenes = geneList,
#               annot = annFUN.gene2GO,
#               gene2GO = gene2go)
# 
# resultFis <- getSigGroups(GOdata, test.stat)
# 
# GenTable(resultFis)
# # Error in function (classes, fdef, mtable)  : 
# #   unable to find an inherited method for function "GenTable", for signature "topGOresult"
# 
# my.group <- new("classicCount", testStatistic = GOFisherTest, name = "fisher", 
#                 allMembers = names(gene2go),
#                 groupMembers = gene2go,
#                 sigMembers = sig.genes)
