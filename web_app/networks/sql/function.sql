-- make the default value false. Lamely, Django doesn't do this.
alter table networks_function alter column obsolete set default false;
