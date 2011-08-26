#
# SQL script to create the db for the Network Portal web app.
#

# example usage: mysql -p -u network_portal < network_portal/db/create_tables.sql
# to populate w/ dvu gene annotations:
# ruby network_portal/script/genes_from_ncbi.rb
# ruby network_portal/script/dvu_discontinued_genes.rb

create database if not exists network_portal_development;
use network_portal_development;


drop table if exists networks;
create table networks (
  id int(11) primary key NOT NULL AUTO_INCREMENT,
  species_id int(11),
  name varchar(255),
  data_source varchar(255),
  description text,
  created_at datetime
);

drop table if exists biclusters;
create table biclusters (
  id int(11) primary key NOT NULL AUTO_INCREMENT,
  network_id int(11) not null,
  k int not null,
  residual real,
  INDEX (network_id)
);


# species
drop table if exists species;
CREATE TABLE `species` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `short_name` varchar(255) DEFAULT NULL,
  `ncbi_taxonomy_id` int(11) DEFAULT NULL,
  `ucsc_id` varchar(255) DEFAULT NULL,
  created_at datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX (name)
);

# sequences (scaffold, chromosome, plasmid, etc)
# topology = linear or circular
drop table if exists sequences;
create table sequences (
  id int(11) primary key NOT NULL AUTO_INCREMENT,
  species_id int(11),
  name varchar(255),
  length int(11),
  topology varchar(24),
  refseq varchar(24)
);

# genes (loci on the genome)
drop table if exists genes;
create table genes (
  id int(11) primary key NOT NULL AUTO_INCREMENT,
  species_id int(11),
  sequence_id int(11),
  name varchar(40),
  common_name varchar(100),
  geneid int(10) unsigned,
  type varchar(48),
  start int(10) unsigned,
  end int(10) unsigned,
  strand char(1),
  description varchar(255),
  transcription_factor boolean,
  INDEX(name),
  INDEX(species_id)
);

# link biclusters to member genes
drop table if exists biclusters_genes;
create table biclusters_genes (
  bicluster_id int(11) not null,
  gene_id int(11) not null,
  INDEX (bicluster_id),
  INDEX (gene_id)
);

# conditions
drop table if exists conditions;
create table conditions (
  id int(11) primary key NOT NULL AUTO_INCREMENT,
  network_id int(11),
  name varchar(255)
);

# biclusters_conditions
drop table if exists biclusters_conditions;
create table biclusters_conditions (
  bicluster_id int(11) not null,
  condition_id int(11) not null,
  INDEX (bicluster_id),
  INDEX (condition_id)
);

# motifs
# a motif will belong to only 1 bicluster
drop table if exists motifs;
create table motifs (
  id int(11) primary key NOT NULL AUTO_INCREMENT,
  bicluster_id int(11),
  position int(11),
  sites int(11),
  e_value real,
  INDEX (bicluster_id)
);


# PSSMs
drop table if exists pssms;
create table pssms (
  motif_id int(11) NOT NULL,
  position int,
  a real not null,
  c real not null,
  g real not null,
  t real not null,
  INDEX (motif_id)
);


# ratios - gene expression measurements
# expression of a gene measured under a given condition
drop table if exists expression;
create table expression (
  gene_id int(11) not null,
  condition_id int(11) not null,
  value real,
  INDEX (gene_id),
  INDEX (condition_id)
);


# influences are things that influence/predict the expression
# of a bicluster. They might be TFs, TF-groups, logical functions
# (AND, OR), or environmental factors.
drop table if exists influences;
create table influences (
  id int(11) primary key NOT NULL AUTO_INCREMENT,
  name varchar(255),
  gene_id int(11),
  type varchar(255)
  index(gene_id)
);

drop table if exists biclusters_influences;
create table biclusters_influences (
  influence_id int(11),
  bicluster_id int(11),
  coefficient real,
  INDEX (bicluster_id)
);

# tf_groups and tf_groups_genes?

# 

# gene_functions

# functions

# bicluster_predictors
# a predictor could be a gene or an evironmental factor


# insert some data to start with
insert into species (name, short_name, ncbi_taxonomy_id, ucsc_id, created_at) values ('Desulfovibrio vulgaris Hildenborough', 'dvu', 882, 'desuVulg_HILDENBOROUG', NOW());
insert into species (name, short_name, ncbi_taxonomy_id, ucsc_id, created_at) values ('Halobacterium salinarum NRC-1', 'hal', 64091, 'haloHalo1', NOW());
insert into species (name, short_name, ncbi_taxonomy_id, ucsc_id, created_at) values ('Methanococcus maripaludis S2', 'mmp', 267377, 'metMar1', NOW());

# sequences for dvu
insert into sequences (name, species_id, length, topology, refseq) values ('chromosome', 1, 3570858, 'circular', 'NC_002937');
insert into sequences (name, species_id, length, topology, refseq) values ('pDV',        1,  202301, 'circular', 'NC_005863');

# sequences for hal
insert into sequences (name, species_id, length, topology, refseq) values ('chromosome', 2, 2014239, 'circular', 'NC_002607');
insert into sequences (name, species_id, length, topology, refseq) values ('pNRC200',    2,  365425, 'circular', 'NC_002608');
insert into sequences (name, species_id, length, topology, refseq) values ('pNRC100',    2,  191346, 'circular', 'NC_001869');

# sequence for mmp
insert into sequences (name, species_id, length, topology, refseq) values ('chromosome', 3, 1661137, 'circular', 'NC_005791');
