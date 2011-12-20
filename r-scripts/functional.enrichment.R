library(RPostgreSQL)

# database connect info
config <- environment()
config$db.user = "dj_ango"
config$db.password = "django"
config$db.name = "network_portal"
config$db.host = "localhost"



# for each bicluster, need its member genes and their functional annotations
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
      # remove genes that don't change much. Might we want to include thos
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
    
    #count number of genes in each bicluster for the species
    sql <- sprintf(paste(
      "select b.id as bicluster_id, count(bg.gene_id) as gene_count",
      "from networks_bicluster b ",
      "join networks_bicluster_genes bg on b.id=bg.bicluster_id",
      "where b.network_id = %d",
      "group by b.id",
      "order by b.id;"),
      network.id)
    bicluster.gene.counts <- dbGetQuery(con, sql)

    # restrict functions to a particular type and namespace
    # namespace has meaning in GO where it comes from the set
    # {molecular_function, cellular_component, biological_process}
    # in other systems it marks category/subcategory levels of the hierarchy
    if (is.null(type)) {
      where.type = ""
    }
    else {
      where.type = sprintf("and f.type='%s'", type)
    }
    if (is.null(namespace)) {
      where.namespace = ""
    }
    else {
      where.namespace = sprintf("and f.namespace='%s'", namespace)
    }
    
    #count number of genes for each function in each bicluster for a species
    sql <- sprintf(paste(
      "select b.id as bicluster_id, f.id as function_id, count(bg.gene_id) as count",
      "from networks_bicluster b",
      "join networks_bicluster_genes bg on b.id=bg.bicluster_id",
      "join networks_gene_function gf on gf.gene_id=bg.gene_id",
      "join networks_function f on gf.function_id=f.id",
      "where b.network_id = %d",
      where.type,
      where.namespace,
      "group by b.id, f.id",
      "order by b.id, f.id;"),
      network.id)
    bicluster.function.counts <- dbGetQuery(con, sql)
    
    # count total number of genes for each function
    sql <- sprintf(paste(
      "select gf.function_id, count(gf.gene_id)",
      "from networks_gene_function gf",
      "join networks_gene g on g.id = gf.gene_id",
      "join networks_function f on gf.function_id=f.id",
      "where g.id in (%s)",
      where.type,
      where.namespace,
      "group by gf.function_id",
      "order by gf.function_id;"),
      paste(gene.ids,collapse=","))
    function.gene.counts <- dbGetQuery(con, sql)
    
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
    
    # add columns to data frame
    return(data.frame(bicluster.id=bicluster.function.counts$bicluster_id,
                      function.id=bicluster.function.counts$function_id,
                      count=q,
                      m,n,k,p,p.bh, p.b))
  },
  finally={
    dbDisconnect(con)
    postgreSQL.driver <- dbDriver("PostgreSQL")
  })
}

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

let.it.rip <- function() {
  systems = list( c(type='kegg', namespace='kegg pathway'),
                  c(type='tigr', namespace='tigrfam'),
                  c(type='go',   namespace='biological_process'),
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
    }
  }
}
