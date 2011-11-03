class Species:
    def __init__(self, name, chromosome_map):
        self.name = name
        self.chromosome_map = chromosome_map


# define names and chromosome names for known species. Add new species here as needed.
species_dict = {}
species_dict['hal'] = Species("Halobacterium salinarum NRC-1",
                              {'chromosome':'chromosome', 'pNRC100':'pNRC100', 'pNRC200':'pNRC200'})
species_dict['halo'] = species_dict['hal']
species_dict['dvu'] = Species("Desulfovibrio vulgaris Hildenborough",
                              {'chromosome':'chromosome', 'pDV':'pDV'})
species_dict['dvh'] = species_dict['dvu']
species_dict['mmp'] = Species("Methanococcus maripaludis S2",
                              {'chromosome':'chromosome'})
