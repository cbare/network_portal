## Some duplicate GO functions got into the database. This is
## the script I wrote to delete them. - Chris 2012-7

import psycopg2


con = psycopg2.connect("dbname=network_portal user=dj_ango password=django")
cur = con.cursor()

cur.execute("""
    select *
    from
      (select gene_id, function_id, count(id) as c from networks_gene_function group by gene_id,function_id) as foo
    where foo.c > 1 order by foo.function_id;
    """)

dups = []
for row in cur:
    dups.append( row[0:3] )

print dups

for row in dups:
    cur.execute("""
        select id from networks_gene_function where gene_id=%d and function_id=%d;
    """ % row[0:2])
    
    a = cur.fetchall()
    # flatten
    b = [item for sublist in a for item in sublist]
    print b
    
    # remove the duplicate with the smallest ID - we'll keep that one.
    m = min(b)
    to_delete = set(b).difference(set((m,)))
    print to_delete
    
    # delete the rest
    cur.execute("""
    delete from networks_gene_function where id in (%s);
    """ % ",".join([ str(id) for id in to_delete ]) )
    con.commit()

cur.close()
con.close()
