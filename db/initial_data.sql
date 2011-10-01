-- insert some data to start with

-- insert species, dvu, hal, mmp
insert into networks_species (name, short_name, ncbi_taxonomy_id, ucsc_id, created_at) values ('Desulfovibrio vulgaris Hildenborough', 'dvu', 882, 'desuVulg_HILDENBOROUG', NOW());
insert into networks_species (name, short_name, ncbi_taxonomy_id, ucsc_id, created_at) values ('Halobacterium salinarum NRC-1', 'hal', 64091, 'haloHalo1', NOW());
insert into networks_species (name, short_name, ncbi_taxonomy_id, ucsc_id, created_at) values ('Methanococcus maripaludis S2', 'mmp', 267377, 'metMar1', NOW());

-- sequences for dvu
insert into networks_chromosome (name, species_id, length, topology, refseq) values ('chromosome', 1, 3570858, 'circular', 'NC_002937');
insert into networks_chromosome (name, species_id, length, topology, refseq) values ('pDV',        1,  202301, 'circular', 'NC_005863');

-- sequences for hal
insert into networks_chromosome (name, species_id, length, topology, refseq) values ('chromosome', 2, 2014239, 'circular', 'NC_002607');
insert into networks_chromosome (name, species_id, length, topology, refseq) values ('pNRC200',    2,  365425, 'circular', 'NC_002608');
insert into networks_chromosome (name, species_id, length, topology, refseq) values ('pNRC100',    2,  191346, 'circular', 'NC_001869');

-- sequence for mmp
insert into networks_chromosome (name, species_id, length, topology, refseq) values ('chromosome', 3, 1661137, 'circular', 'NC_005791');
