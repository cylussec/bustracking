This starts with the AWS Bitnami ELK stack 7.3. 

Run the following 

PUT gtfs-data
{
  "mappings": {
    "properties": {
      "location": {
        "type": "geo_point"
      }
    }
  }
}

======

Put the gtfsdownloader.sh, gtfs-realtime.pb.rb, chop.rb and stitch.rb into /opt/bitnami/logstash
Put the logstash.conf and logstash-postprocess.conf into /opt/bitnami/logstash/conf

Add the following to the /opt/bitnami/logstash/config/pipeline.yml
- pipeline.id: parser
  path.config: "/opt/bitnami/logstash/conf/logstash.conf"
- pipeline.id: postprocessor
  path.config: "/opt/bitnami/logstash/conf/logstash-postprocess.conf"
  pipeline.workers: 1

====

Make logstash use the above yml file by changing /opt/bitnami/logstash/scripts/ctl.sh line 7 from

LOGSTASH="$INSTALL_PATH/bin/logstash -f $INSTALL_PATH/conf"

to

LOGSTASH="$INSTALL_PATH/bin/logstash"

And on the line 79 with

       ps ax | grep logstash | grep "$JAVA_HOME" | grep " \-f $INSTALL_PATH/conf" | grep -v grep | awk '{print $1}' > $LOGSTASH_PIDFILE

change it to

       ps ax | grep logstash | grep "$JAVA_HOME" | grep -v grep | awk '{print $1}' > $LOGSTASH_PIDFILE

======

sudo logstash-plugin install logstash-codec-protobuf

run gtfsdownloader.sh and add it as a cron job to run nightly at 2am (0 2 * * * /opt/bitnami/logstash/gtfsdownloader.sh)

Change this: /opt/bitnami/logstash/config/jvm.options
# Xms represents the initial size of total heap space
# Xmx represents the maximum size of total heap space
-Xms1g
-Xmx8g

========

Then start the postprocessor pulling in the old data and restart everything
Then switch the host, schedule and src index back
Then import all of the saved objects from the export.json file

=======================

AWS Network security:

HTTP
TCP
80
0.0.0.0/0
SSH
TCP
22
0.0.0.0/0
HTTPS
TCP
443
0.0.0.0/0
Custom TCP Rule
TCP
9200
0.0.0.0/0

=====

security

https://github.com/opendistro-for-elasticsearch/security



=======

When we get forbidden errors, this is the fix
  PUT _settings
    {
    "index": {
    "blocks": {
    "read_only_allow_delete": "false"
    }
    }
    }