-- get gene ids for a bicluster
select gene_id
from biclusters b join biclusters_genes bg on b.id=bg.bicluster_id
where network_id=1 and bicluster_id=2;

-- get genes for bicluster
select g.name, g.common_name
from biclusters b
join biclusters_genes bg on b.id=bg.bicluster_id
join genes g on bg.gene_id=g.id
where network_id=1 and bicluster_id=2;

-- for each pair of genes, count number of biclusters in which they co-occur
select bg1.gene_id, bg2.gene_id, count(*) as cooccurrence
from biclusters_genes bg1
join biclusters_genes bg2 on bg1.bicluster_id = bg2.bicluster_id
where bg1.gene_id < bg2.gene_id
group by bg1.gene_id, bg2.gene_id
order by cooccurrence desc
limit 20;


select f1.name as function, f2.name as subcategory
from networks_function f1 join networks_function_relationships r on f1.id=r.function_id
join networks_function f2 on r.target_id=f2.id where r.type='parent';


select * from networks_function
where id in (
  select function_id from networks_function_relationships
  where type='parent' and target_id=(
    select id from networks_function
    where name='Nucleotide and nucleoside interconversions'
    and type='tigr' and namespace='tigr role'));

delete from networks_function_relationships
  where function_id in (select id from networks_function where type='tigr');

delete from networks_gene_function
  where function_id in (select id from networks_function where type='tigr');
  
delete from networks_function where type='tigr';

delete from networks_function_relationships
  where function_id in (select id from networks_function where native_id='Accession')
  or target_id in (select id from networks_function where native_id='Accession');




# link influences with genes
insert into networks_influence_genes (influence_id, gene_id)
select ni.id, ng.id from networks_influence ni join networks_gene ng on ni.name=ng.name
where ni.type='tf';

insert into networks_influence_genes (influence_id, gene_id)
select ni.id, ng.id from networks_influence ni join networks_gene ng on ng.name = split_part(ni.name, '~~', 1)
where ni.type='combiner';

insert into networks_influence_genes (influence_id, gene_id)
select ni.id, ng.id from networks_influence ni join networks_gene ng on ng.name = split_part(ni.name, '~~', 2)
where ni.type='combiner';


# check for pairs of influence names like A~~B~~OP <-> B~~A~~OP 
select * from networks_influence ni1 join networks_influence ni2 on ni1.name = split_part(ni2.name, '~~', 2) || '~~' || split_part(ni2.name, '~~', 1) || '~~' || split_part(ni2.name, '~~', 3);


# get genes directly regulated by tf DVU3142
select ni.name, bi.bicluster_id
from networks_bicluster_influences bi join networks_influence ni on bi.influence_id=ni.id
where ni.name='DVU3142' and ni.type='tf';

# get genes indirectly regulated by tf DVU3142
select ni.name, bi.bicluster_id
from networks_bicluster_influences bi join networks_influence ni on bi.influence_id=ni.id
where ni.type='combiner' and ni.id in (
  select from_influence_id
  from networks_influence_parts nip join networks_influence ni on nip.to_influence_id=ni.id
  where ni.name='DVU3142');

# get all biclusters (of any network) that are regulated by a given gene
select bi.bicluster_id
from networks_bicluster_influences bi join networks_influence ni on bi.influence_id=ni.id
where (ni.type='tf' and ni.name='DVU3142')
or (ni.type='combiner' and ni.id in (
  select from_influence_id
  from networks_influence_parts nip join networks_influence ni on nip.to_influence_id=ni.id
  where ni.name='DVU3142'));

# get all biclusters of a specific network that are regulated by a given gene
select nb.*
from networks_bicluster nb
     join networks_bicluster_influences bi on nb.id=bi.bicluster_id
     join networks_influence ni on bi.influence_id=ni.id
where nb.network_id=1
and ((ni.type='tf' and ni.gene_id=3127)
  or (ni.type='combiner' and ni.id in (
    select from_influence_id
    from networks_influence_parts nip join networks_influence ni on nip.to_influence_id=ni.id
    where ni.gene_id=3127)));


# find GO terms and their parents
select f.native_id, f.name, f.namespace, f.type, r.id
from networks_function f left join networks_function_relationships r on f.id=r.function_id
where f.type='go' and r.type='parent'
limit 10;

# find top-level GO terms
select f.native_id, f.name, f.namespace, f.type
from networks_function f
where f.type='go' and f.obsolete=false
and f.id not in (select function_id from networks_function_relationships where type='is_a');

# find child terms of a GO term
select f.*
from networks_function f
where f.type='go'
and f.id in (select function_id from networks_function_relationships where type='is_a' and target_id=?)
order by native_id;


select split_part(name, '~~', 1) as regulator_1,
       split_part(name, '~~', 2) as regulator_2,
       split_part(name, '~~', 3) as op
from networks_influence
where position('~~' in name) > 0;


select distinct(u.regulator) from (
  select split_part(name, '~~', 1) as regulator
  from networks_influence
  where type='combiner'

  union

  select split_part(name, '~~', 2) as regulator
  from networks_influence
  where type='combiner'
) as u;



# count biclusters regulated by a transcription factor
select count(distinct(nb.id))
from networks_bicluster nb
     join networks_bicluster_influences bi on nb.id=bi.bicluster_id
     join networks_influence ni on bi.influence_id=ni.id
where nb.network_id=1
and ((ni.type='tf' and ni.gene_id=2074)
or (ni.type='combiner' and ni.id in (
  select from_influence_id
  from networks_influence_parts nip join networks_influence ni on nip.to_influence_id=ni.id
  where ni.gene_id=2074)));

# count genes regulated by a transcription factor
select count(distinct(g.id))
from networks_gene g
join networks_bicluster_genes bg on g.id = bg.gene_id
join networks_bicluster b on b.id = bg.bicluster_id
join networks_bicluster_influences bi on b.id=bi.bicluster_id
join networks_influence i on bi.influence_id=i.id
where b.network_id=1
and ((i.type='tf' and i.gene_id=2074)
or (i.type='combiner' and i.id in (
  select from_influence_id
  from networks_influence_parts ip join networks_influence i on ip.to_influence_id=i.id
  where i.gene_id=2074)));

# add synonyms for halo genes
insert into networks_synonym (target_id, target_type, name, type)
  select id as target_id, 
          'gene' as target_type,
          trim(trailing 'm' from name) as name,
          'vng:m' as type
    from networks_gene
    where species_id=2
    and name like '%m';

insert into networks_synonym (target_id, target_type, name, type) select id as target_id, 'gene' as target_type, 'xxxx' as name, 'vng:7/5' as type from networks_gene where species_id=2 and name = 'yyyy';

# get synonyms for genes in a species
select s.* from networks_synonym s 
join networks_gene g on g.id=s.target_id
where s.target_type='gene'
and g.species_id=2;


# for each bicluster, list genes and their functions
select b.id as bicluster_id, bg.gene_id as gene_id, f.id as function_id
from networks_bicluster b
join networks_bicluster_genes bg on b.id=bg.bicluster_id
join networks_gene_function gf on gf.gene_id=bg.gene_id
join networks_function f on gf.function_id=f.id
where f.type='kegg'
order by bicluster_id, gene_id, function_id
limit 50;

# count genes in each bicluster
select b.id as bicluster_id, count(bg.gene_id) as gene_count
from networks_bicluster b
join networks_bicluster_genes bg on b.id=bg.bicluster_id
group by b.id
order by b.id;

select b.id as bicluster_id, f.id as function_id, count(bg.gene_id) as count
from networks_bicluster b
join networks_bicluster_genes bg on b.id=bg.bicluster_id
join networks_gene_function gf on gf.gene_id=bg.gene_id
join networks_function f on gf.function_id=f.id
where f.type='kegg'
group by b.id, f.id
order by bicluster_id, function_id
limit 50;

# get a count of genes with each functional annotation in the organism
select gf.function_id, count(gf.gene_id)
from networks_gene_function gf
join networks_gene g on g.id = gf.gene_id
where g.species_id = 1 
group by gf.function_id
order by gf.function_id;

select count(distinct(e.gene_id))
from expression e
join networks_bicluster_conditions bc on e.condition_id = bc.condition_id
join networks_bicluster b on b.id = bc.bicluster_id
where b.network_id = 1

# get GO mappings for all genes in an organism
select gf.gene_id, f.native_id
from networks_function f
join networks_gene_function gf on gf.function_id=f.id
join networks_gene g on gf.gene_id=g.id
where g.species_id=1
and f.type='go'
and f.namespace='biological_process';


# get a translation table between kegg pathways and kegg subcategories
select f1.name, f1.type, f1.namespace, fr.type, f2.name, f2.namespace
from networks_function f1
join networks_function_relationships fr on f1.id = fr.target_id
join networks_function f2 on f2.id = fr.function_id
where fr.type='parent'
and f1.type='kegg'
and f1.namespace='kegg subcategory'

select f1.name, f1.type, f1.namespace, fr.type, f2.name, f2.namespace
from networks_function f1
join networks_function_relationships fr on f1.id = fr.target_id
join networks_function f2 on f2.id = fr.function_id
where fr.type='parent'
and f1.type='cog'
and f1.namespace='cog subcategory'
and f1.name != 'General function prediction only'
and f1.name != 'Function unknown'

select f1.id, f1.name
from networks_function f1
join networks_function_relationships fr on f1.id = fr.target_id
join networks_function f2 on f2.id = fr.function_id
where fr.type='parent'
and f2.id = 

select * from networks_function where id in (40535,40616,40751,40753,40775,40797,40892,40905,41177,41240,41287,41288,41296,41412,41838,41895,42021,42073,42093,42124,42206,42207,42210,42323,42891,42953,43063);


# get biclusters with significant enrichment for the kegg subcategory 'cellular motility'
select b.id as bicluster_id, b.k as bicluster_k, f.type, f.namespace, f.native_id, f.name, bf.gene_count, bf.k, bf.p_bh
from networks_bicluster_function bf
join networks_function f on bf.function_id=f.id
join networks_bicluster b on b.id=bf.bicluster_id
where f.name ilike '%motil%'
and f.namespace='kegg subcategory'
and bf.p_b < 0.05
and b.network_id=1;
