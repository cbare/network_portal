Network Portal Solr test
=============================


Running Solr for development
----------------------------

Download the Solr distribution and put it somewhere convenient. Solr
comes with an "example" configuration that uses the Jetty server. We
can run that, with our own Solr config directory, with the start.jar
provided in the Solr example directory.

There are 3 important directories that have to be set: jetty.home,
solr.solr.home, and finally the Solr installation. The last of these
is used in the solrconfig.xml to load optional components. Look for
${solr.install.dir}.

Navigate to the example directory under the Solr installation. It will
look something like, where "my_projects" stands for some directory of
your choosing.

.../my_projects/apache-solr-3.4.0/example/

This implicitly takes care of setting jetty.home 'cause start.jar looks
in the current working directory for a jetty install. We'll pass the
other two as JVM system properties on the command line.

> cd my_projects/apache-solr-3.4.0/example/
> export network_portal_home=[path to project]
> java -Dsolr.solr.home="${network_portal_home}/network_portal/solr" -Dsolr.install.dir="${network_portal_home}/apache-solr-3.4.0/" -jar start.jar

...and when Solr is started connect to 

http://localhost:8983/solr/

To reindex do:
http://localhost:8983/solr/dataimport?command=full-import


Basic Directory Structure
-------------------------

The Solr Home directory typically contains the following subdirectories...

   conf/
        This directory is mandatory and must contain your solrconfig.xml
        and schema.xml.  Any other optional configuration files would also 
        be kept here.

   data/
        This directory is the default location where Solr will keep your
        index, and is used by the replication scripts for dealing with
        snapshots.  You can override this location in the solrconfig.xml
        and scripts.conf files. Solr will create this directory if it
        does not already exist.

   lib/
        This directory is optional.  If it exists, Solr will load any Jars
        found in this directory and use them to resolve any "plugins"
        specified in your solrconfig.xml or schema.xml (ie: Analyzers,
        Request Handlers, etc...).  Alternatively you can use the <lib>
        syntax in solrconfig.xml to direct Solr to your plugins.  See the
        example solrconfig.xml file for details.

   bin/
        This directory is optional.  It is the default location used for
        keeping the replication scripts.
