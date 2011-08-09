#
# SQL script to create the db for the Network Portal web app.
#

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
  residual real
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
  PRIMARY KEY (`id`)
);

insert into species (name, short_name, ncbi_taxonomy_id, ucsc_id) values ('Desulfovibrio vulgaris Hildenborough', 'dvu', 882, 'desuVulg_HILDENBOROUG');
insert into species (name, short_name, ncbi_taxonomy_id, ucsc_id) values ('Halobacterium salinarum NRC-1', 'hal', 64091, 'haloHalo1');
insert into species (name, short_name, ncbi_taxonomy_id, ucsc_id) values ('Methanococcus maripaludis S2', 'mmp', 267377, 'metMar1');


# genes (loci on the genome)
drop table if exists genes;
create table genes (
  id int(11) primary key NOT NULL,
  species_id int(11),
  name varchar(40),
  common_name varchar(100),
  accession varchar(20),
  gi int(10) unsigned,
  scaffoldId int(11),
  start int(10) unsigned,
  stop int(10) unsigned,
  strand char(1),
  description varchar(255),
  COG varchar(12),
  COGFun varchar(12),
  COGDesc varchar(255),
  TIGRFam varchar(255),
  TIGRRoles varchar(255),
  GO varchar(255),
  EC varchar(40),
  ECDesc varchar(255)
);

# link biclusters to member genes
drop table if exists bicluster_genes;
create table bicluster_genes (
  bicluster_id int(11) not null,
  gene_id int(11) not null
);

# gene_functions

# functions

# bicluster_predictors
# a predictor could be a gene or an evironmental factor


