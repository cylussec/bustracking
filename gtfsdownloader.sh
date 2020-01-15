rm -f /opt/bitnami/logstash/mta-transit-data/google_transit.zip
rm -rf /opt/bitnami/logstash/mta-transit-data/google_transit/
rm -f /tmp/google_transit.zip
wget -O /tmp/google_transit.zip https://s3.amazonaws.com/mdotmta-gtfs/google_transit.zip
unzip -o /tmp/google_transit.zip -d /opt/bitnami/logstash/mta-transit-data/
rm -f /tmp/*_data
sudo perl -i.bak -pe 's/[^[:ascii:]]//g' /opt/bitnami/logstash/mta-transit-data/google_transit/stop_times.txt

sqlite3 /opt/bitnami/logstash/mta-transit-data.db <<END_SQL
.timeout 2000
.mode csv
.import /opt/bitnami/logstash/mta-transit-data/google_transit/stop_times.txt stop_times
.import /opt/bitnami/logstash/mta-transit-data/google_transit/routes.txt routes
.import /opt/bitnami/logstash/mta-transit-data/google_transit/stops.txt stops
.import /opt/bitnami/logstash/mta-transit-data/google_transit/trips.txt trips
.quit
END_SQL