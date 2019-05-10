rm -f /opt/bitnami/logstash/mta-transit-data/google_transit.zip
wget -O /tmp/google_transit.zip https://s3.amazonaws.com/mdotmta-gtfs/google_transit.zip
unzip -o /tmp/google_transit.zip -d /opt/bitnami/logstash/mta-transit-data/
rm -f /tmp/*_data