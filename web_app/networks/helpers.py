from django.db import connection

def synonym(obj=None, synonym_type=None):
    print '+' * 100
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
    