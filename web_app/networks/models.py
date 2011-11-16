

from django.db import models


class Species(models.Model):
    name = models.CharField(max_length=255)
    short_name = models.CharField(max_length=64)
    ncbi_taxonomy_id = models.IntegerField(blank=True, null=True)
    ucsc_id = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField()
    
    def transcription_factors(self):
        return self.gene_set.filter(transcription_factor=True)
    
    def __unicode__(self):
        return self.name
    
    class Meta:
        ordering = ['name']

class Chromosome(models.Model):
    species = models.ForeignKey(Species)
    name = models.CharField(max_length=255)
    length = models.IntegerField()
    topology = models.CharField(max_length=64)
    refseq = models.CharField(max_length=64, blank=True, null=True)
    
    def __unicode__(self):
        return self.name

class Network(models.Model):
    species = models.ForeignKey(Species)
    name = models.CharField(max_length=255)
    data_source = models.TextField(blank=True, null=True)
    description = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField()
    
    def get_biclusters_regulated_by(regulator):
        biclusters = Bicluster.objects.filter(influences__name__contains=regulator)
    
    def __unicode__(self):
        return self.name
    

class Condition(models.Model):
    network = models.ForeignKey(Network)
    name = models.CharField(max_length=255)
    
    def __unicode__(self):
        return self.name

class Gene(models.Model):
    species = models.ForeignKey(Species)
    chromosome = models.ForeignKey(Chromosome, blank=True, null=True)
    name = models.CharField(max_length=64)
    common_name = models.CharField(max_length=100, blank=True, null=True)
    geneid = models.IntegerField(blank=True, null=True)
    type = models.CharField(max_length=64, blank=True, null=True)
    start = models.IntegerField(blank=True, null=True)
    end = models.IntegerField(blank=True, null=True)
    strand = models.CharField(max_length=1, blank=True, null=True)
    description = models.CharField(max_length=255, blank=True, null=True)
    transcription_factor = models.BooleanField(default=False)
    functions = models.ManyToManyField('Function', through='Gene_Function')
    
    def regulated_biclusters(self, network):
        """
        Return biclusters regulated by this gene.
        """
        if not self.transcription_factor:
            return []
        else:
            return Bicluster.objects.raw("""
            select nb.*
            from networks_bicluster nb
                 join networks_bicluster_influences bi on nb.id=bi.bicluster_id
                 join networks_influence ni on bi.influence_id=ni.id
            where nb.network_id=%s
            and ((ni.type='tf' and ni.gene_id=%s)
            or (ni.type='combiner' and ni.id in (
              select from_influence_id
              from networks_influence_parts nip join networks_influence ni on nip.to_influence_id=ni.id
              where ni.gene_id=%s)));
            """, (network.id, self.id, self.id,))
    
    def __unicode__(self):
        return self.name

    class Meta:
        ordering = ['name']

class Influence(models.Model):
    """
    Influences can be transcription factors, environmental factors or
    combinations of other influences. If the influence is a
    transcription factor, the gene field links to the entry in the gene table. If
    the influence is a combination of TFs, the individual TFs will be linked
    through the Influence_Combinations table.
    """
    name = models.CharField(max_length=255)
    gene = models.ForeignKey(Gene, blank=True, null=True)
    operation = models.CharField(max_length=32, blank=True, null=True)
    type = models.CharField(max_length=32, blank=True, null=True)
    parts = models.ManyToManyField('self')
    
    def __unicode__(self):
        return self.name

class Bicluster(models.Model):
    network = models.ForeignKey(Network)
    k = models.IntegerField()
    residual = models.FloatField(blank=True, null=True)
    conditions = models.ManyToManyField(Condition)
    genes = models.ManyToManyField(Gene)
    influences = models.ManyToManyField(Influence, symmetrical=False)
    
    def __unicode__(self):
        return "Bicluster " + str(self.k)

class PSSM():
    """
    Position specific scoring matrix. Not a Django model 'cause one PSSM is
    not a single in the DB but several (one row persition).
    """
    def __init__(self):
        self.positions=[]

    def add_position(self, dict):
        self.positions.append(dict)

    def get_position(self, p):
        return self.positions[p]
    
    def to_one_letter_string(self):
        letters = []
        for p in self.positions:
            max_letter = 'a'
            for letter in p.keys():
                if p[letter] > p[max_letter]:
                    max_letter = letter
            if p[max_letter] > 0.8:
                letters.append(max_letter.upper())
            elif p[max_letter] > 0.5:
                letters.append(max_letter)
            else:
                letters.append('.')
        return "".join(letters)

    def __len__(self):
        return len(self.positions)

class Motif(models.Model):
    bicluster = models.ForeignKey(Bicluster)
    position = models.IntegerField(blank=True, null=True)
    sites = models.IntegerField(blank=True, null=True)
    e_value = models.FloatField(blank=True, null=True)
    
    def pssm(self):
        from django.db import connection, transaction
        cursor = connection.cursor()

        # Data retrieval operation - no commit required
        cursor.execute("select position, a, c, g, t from pssms where motif_id=%s order by position;", [self.id])
        rows = cursor.fetchall()
        
        pssm = PSSM()
        for row in rows:
            pssm.add_position({'a':row[1], 'c':row[2], 'g':row[3], 't':row[4]})

        return pssm
        

# A generalized annotation field. Put annotation on any type of object.
class Annotation(models.Model):
    target_id = models.IntegerField()
    target_type = models.CharField(max_length=255)
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    source = models.CharField(max_length=255, blank=True, null=True)

# alternate names for genes, species, maybe influences or functions
class Synonym(models.Model):
    target_id = models.IntegerField()
    target_type = models.CharField(max_length=255)
    name = models.CharField(max_length=255)
    type = models.CharField(max_length=64, blank=True, null=True)

# functions as defined by some system
# type specifies the naming system {GO, COG, KEGG, etc.}
# native_id is the id within the naming system, GO_ID, Kegg pathway ID, etc.
# genes can have functions, biclusters can be enriched for functions
class Function(models.Model):
    native_id = models.CharField(max_length=64, blank=True, null=True)
    name = models.CharField(max_length=255)
    namespace = models.CharField(max_length=255, blank=True, null=True)
    type = models.CharField(max_length=64, blank=True, null=True)
    obsolete = models.BooleanField(default=False)
    description = models.TextField(blank=True, null=True)

class Function_Relationships(models.Model):
    """
    Define relationships among functions, such as the GO hierarchy or the categories/subcategories of KEGG.
    """
    function = models.ForeignKey(Function, related_name='relationships')
    target = models.ForeignKey(Function, related_name='+')
    type = models.CharField(max_length=255, blank=True, null=True)

class Gene_Function(models.Model):
    function = models.ForeignKey(Function)
    gene = models.ForeignKey(Gene)
    source = models.CharField(max_length=255, blank=True, null=True)

