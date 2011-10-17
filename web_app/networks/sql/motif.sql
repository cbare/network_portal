-- create table for PSSMs
-- Not a model class, but accessible through Motif objects
create table pssms (
  motif_id int NOT NULL,
  position int,
  a real not null,
  c real not null,
  g real not null,
  t real not null
);
CREATE INDEX pssms_motif_id_idx ON pssms (motif_id);
