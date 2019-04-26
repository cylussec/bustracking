This starts with the AWS Bitnami ELK stack 6.7. 

Put the gtfs-realtime.pb.rb, chop.rb and stitch.rb into /opt/bitnami/logstash
Put the logstash.conf and logstash-postprocess.conf into /opt/bitnami/logstash/conf

Add the following to the /opt/bitnami/logstash/config/pipeline.yml
 - pipeline.id: parser
   path.config: "/opt/bitnami/logstash/config/logstash.yml"
 - pipeline.id: postprocessor
   path.config: "/opt/bitnami/logstash/config/logstash-postprocess.yml"

sudo logstash-plugin install logstash-codec-protobuf

Put the mta-transit-data into /opt/bitnami/logstash (This needs to be updated whenever the gtfs data updates)

Change this: /opt/bitnami/logstash/config/jvm.options
# Xms represents the initial size of total heap space
# Xmx represents the maximum size of total heap space
-Xms1g
-Xmx8g


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