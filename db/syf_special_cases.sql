-- insert a couple extra genes into syf that appear in the array data but not in the
-- gene list from NCBI. These are: Synpcc7942_2452_2 and Synpcc7942_2454_2, which might
-- be duplicate probes for Synpcc7942_2452 and Synpcc7942_2454 or might not.

-- Dunno what this means?
-- > cor(env$ratios[[1]]['Synpcc7942_2454',], env$ratios[[1]]['Synpcc7942_2454_2',])
-- [1] 0.6304663
-- > cor(env$ratios[[1]]['Synpcc7942_2452',], env$ratios[[1]]['Synpcc7942_2452_2',])
-- [1] 0.9649488

-- syf species id = 4


insert into networks_gene (species_id, chromosome_id, name, common_name, geneid, type, start, "end", strand, description, transcription_factor)
  values (4,7,'Synpcc7942_2452_2',NULL,3774471,'CDS',2530160,2530876,'-','Tfp pilus assembly protein PilN-like',false);

insert into networks_gene (species_id, chromosome_id, name, common_name, geneid, type, start, "end", strand, description, transcription_factor)
  values (4,7,'Synpcc7942_2454_2',NULL,3774473,'CDS',2532100,2533374,'-','adenine phosphoribosyltransferase (EC 2.4.2.7) (IMGterm)',false);

