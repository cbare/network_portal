-- sequences for dvu
insert into networks_chromosome (name, species_id, length, topology, refseq) values ('chromosome', 1, 3570858, 'circular', 'NC_002937');
insert into networks_chromosome (name, species_id, length, topology, refseq) values ('pDV', 1,  202301, 'circular', 'NC_005863');
insert into networks_synonym (target_id, target_type, name, type) values (1, 'chromosome', 'chr', 'ucsc');
insert into networks_synonym (target_id, target_type, name, type) values (2, 'chromosome', 'megaplasmid', 'ucsc');

-- sequences for hal
insert into networks_chromosome (name, species_id, length, topology, refseq) values ('chromosome', 2, 2014239, 'circular', 'NC_002607');
insert into networks_chromosome (name, species_id, length, topology, refseq) values ('pNRC200', 2, 365425, 'circular', 'NC_002608');
insert into networks_chromosome (name, species_id, length, topology, refseq) values ('pNRC100', 2,  191346, 'circular', 'NC_001869');
insert into networks_synonym (target_id, target_type, name, type) values (3, 'chromosome', 'chr', 'ucsc');
insert into networks_synonym (target_id, target_type, name, type) values (4, 'chromosome', 'plasmid_pNRC200', 'ucsc');
insert into networks_synonym (target_id, target_type, name, type) values (5, 'chromosome', 'plasmid_pNRC100', 'ucsc');

-- sequence for mmp
insert into networks_chromosome (name, species_id, length, topology, refseq) values ('chromosome', 3, 1661137, 'circular', 'NC_005791');
insert into networks_synonym (target_id, target_type, name, type) values (6, 'chromosome', 'chr', 'ucsc');

