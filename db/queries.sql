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

