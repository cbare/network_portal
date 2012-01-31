from django.db import connection

# maybe this should be a static method of synomym?

def synonym(obj=None, synonym_type=None):
    """
    Return a single synonym for an object of the specified type. The object may be any
    other entity, for example gene, species or chromosome.
    Returns a string or None if no such synonym exists.
    """
    if object:
        target_id = obj.id
        target_type = type(obj).__name__.lower()
    cursor = None
    try:
        cursor = connection.cursor()
        cursor.execute("select name from networks_synonym where target_type=%s and target_id=%s and type=%s", (target_type,target_id,synonym_type,))
        row = cursor.fetchone()
        return row[0] if row else None
    finally:
        if cursor: cursor.close()

def nice_string(obj):
    if obj is None:
        return ""
    return str(obj)

def get_influence_biclusters(gene):
    # get all biclusters that the gene is a member of
    member_biclusters = gene.bicluster_set.all()
    
    # list of IDs for biclusters that this gene belongs to
    bicluster_ids = [b.id for b in member_biclusters]

    # get regulatory influences for this gene
    influence_biclusters = []
    for bicluster in member_biclusters:
        for influence in bicluster.influences.all():
            influence_biclusters.append((bicluster.id, influence))
    return member_biclusters, sorted(influence_biclusters, key=lambda bi: (bi[0], bi[1].name))
