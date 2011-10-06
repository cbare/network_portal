-- create table for expression data

create table expression (
  gene_id int not null,
  condition_id int not null,
  value real
);
CREATE INDEX expression_gene_id_idx ON expression (gene_id);
CREATE INDEX expression_condition_id_idx ON expression (condition_id);

-- I had hoped clustering the table by the gene index would help
-- speed up data loading, but it didn't help as far as i could tell
-- CLUSTER expression_gene_id_idx ON expression;
