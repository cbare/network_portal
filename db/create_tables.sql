--
-- SQL script to create the db for the Network Portal web app.


-- modified for postgresql


-- create database network_portal;
-- \c network_portal



-- PSSMs
create table pssms (
  motif_id int NOT NULL,
  position int,
  a real not null,
  c real not null,
  g real not null,
  t real not null
);
CREATE INDEX pssms_motif_id_idx ON pssms (motif_id);


-- ratios - gene expression measurements
-- expression of a gene measured under a given condition
create table expression (
  gene_id int not null,
  condition_id int not null,
  value real
);
CREATE INDEX expression_gene_id_idx ON expression (gene_id);
CREATE INDEX expression_condition_id_idx ON expression (condition_id);


-- tf_groups and tf_groups_genes?

-- 

-- gene_functions

-- functions

-- bicluster_predictors
-- a predictor could be a gene or an evironmental factor


