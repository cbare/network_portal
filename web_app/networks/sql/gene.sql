# make the default value for transcription factor false. Lamely,
# Django doesn't do this.
alter table networks_gene alter column transcription_factor set default false;

