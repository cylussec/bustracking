# Takes in the raw Swiftly data and generates logstash events

require 'csv'
require 'time'
require 'logger'
require 'tzinfo'
require 'sequel'

require_relative 'constants'

LOG = Logger.new(STDOUT)
LOG.level = Logger::WARN

def import_cdsfsv(tablename, csvfile, primary_key=:id)
  LOG.debug("Entering import_csv")
  $db = Sequel.connect('jdbc:sqlite::memory:') if $db.nil?
  csv = CSV.open(csvfile, :headers=> true, :header_converters => :symbol ).read
  $db.create_table(tablename){
    #primary_key primary_key
    csv.headers.each{|col|
      String col
    }
  }
  puts csv.headers
  $db[tablename].multi_insert(CSV.open(csvfile, :headers=> true) {|row| row.to_h})
end

# Imports a csv file into an in memory sql database
#
# tablename - table to create in the in-memory database
# csvfile - full path to the file to read in
# fields - list of fields (as symbols) to import from the csvfile; defaults to all
def import_csv(tablename, csvfile, fields=nil)
  data = File.open(csvfile)
  $db = Sequel.connect('jdbc:sqlite::memory:') if $db.nil?
  csv = CSV.parse(data, :headers=> true, :header_converters => :symbol )
  fields = fields.nil? ? csv.headers : fields

  $db.create_table(tablename){
    fields.each{|col|
      String col.to_s
    }
  }

  $db[tablename].multi_insert(csv.map {|row| row.to_h.slice(*fields)})
end

# the value of `params` is the value of the hash passed to `script_params`
# in the logstash configuration
def register(_params)
  LOG.debug('Entering register')

  import_csv(:trips, '/opt/bitnami/logstash/mta-transit-data/google_transit/trips.txt')
  import_csv(:routes, '/opt/bitnami/logstash/mta-transit-data/google_transit/routes.txt')
  import_csv(:stops, '/opt/bitnami/logstash/mta-transit-data/google_transit/stops.txt')
  import_csv(:stop_times,
             '/opt/bitnami/logstash/mta-transit-data/google_transit/stop_times.txt',
             [:trip_id, :arrival_time, :stop_id, :stop_sequence, :shape_dist_traveled])
end

# Takes a time in the format hh:mm:ss as well as the date (at the beginning of the route) and converts it to epoc time.
# It also accepts times like 25:45:38, indicating the route operated past midnight, and corrects the date.
#
# input_time should be string of hh:mm:ss from local time which should be converted
# start_date should be string of YYYMMDD
#
# Returns an integer of the epoc time in UTC time
def normalize_local_date(input_time, start_date)
  LOG.debug("Entering normalize_local_date #{input_time}, #{start_date}")

  hour, minute, second = input_time.split(':').map(&:to_i)
  realdate = Time.parse(start_date)

  if hour > 23
    realdate += 86_400 # add a day to the datetime object
    hour -= 24
  end

  tz = TZInfo::Timezone.get('America/New_York')
  offset = tz.period_for_local(realdate).dst? ? -14_400 : -18_000 # -4:00 offset in DST, else -5:00

  Time.new(realdate.year,
           realdate.month,
           realdate.day,
           hour,
           minute,
           second,
           offset).to_time.to_i
end

# Get the trip data from the GTFS file
def get_gtfs_trip(trip_id)
  records = $db[:trips].where(Sequel.lit('trip_id = ?', trip_id)) # "SELECT * FROM trips WHERE trip_id=?"
  records.all
end

# Get the route data from the GTFS file
def get_gtfs_route(route_id)
  records = $db[:routes].where(Sequel.lit('route_id = ?', route_id)) # "SELECT * FROM routes WHERE route_id=?"
  records.all
end

# Get the stop data from the GTFS file
def get_gtfs_stop(stop_id)
  records = $db[:stops].where(Sequel.lit('stop_id = ?', stop_id)) # "SELECT * FROM trips WHERE trip_id=?"
  records.all
end

# Get the stop time data from the GTFS file
def get_gtfs_stop_time(trip_id, stop_sequence)
  records = $db[:stop_times].where(Sequel.lit('trip_id = ? and stop_sequence = ?', trip_id, stop_sequence)) # "SELECT * FROM stop_times WHERE trip_id=? AND stop_sequence=?"
  records.all
end

# process scheduled trips from logstash
#
# trip_update - trip_update from swiftly, by way of logstash
# results_array - array to be populated with each processed trip, passed by reference
def process_canceled_trip(trip_update, results_array)
  # Get trip and route data from GTFS sources
  gtfs_tripdata = get_gtfs_trip(trip_update['trip_update']['trip']['trip_id'])[0]
  gtfs_routedata = get_gtfs_route(gtfs_tripdata[:route_id])[0]
  return if gtfs_tripdata.nil? || gtfs_routedata.nil?

  trip_id = gtfs_tripdata[:trip_id].to_s
  LOG.debug("Processing canceled trip #{trip_id}")

  # Lets fill in all of the stops in case the trip is uncanceled, and to have complete data
  start_date = Time.at(trip_update['trip_update']['timestamp']).to_datetime.strftime('%Y%m%d')

  stop_seq_id = 1
  loop do
    LOG.debug("Processing #{trip_id} - #{stop_seq_id.to_s}")

    # Loop until we find the first non existant stop
    gtfs_stoptimedata = get_gtfs_stop_time(trip_id, stop_seq_id)[0]
    break if gtfs_stoptimedata.nil?

    # Get stop data from GTFS sources
    gtfs_stopdata = get_gtfs_stop(gtfs_stoptimedata[:stop_id])[0]
    break if gtfs_stopdata.nil?

    results_array << LogStash::Event.new(
      'aggregate_id': trip_id + '-' + start_date + '-' + gtfs_stoptimedata[:stop_id].to_s,
      'route_id': gtfs_routedata[:route_id].to_i,
      'trip_id': trip_id.to_i,
      'stop_id': gtfs_stoptimedata[:stop_id].to_i,
      'stop_sequence': stop_seq_id.to_i,
      'route_short_name': gtfs_routedata[:route_short_name].to_s,
      'route_long_name': gtfs_routedata[:route_long_name].to_s,
      'route_color': gtfs_routedata[:route_color].to_s,
      'route_text_color': gtfs_routedata[:route_text_color].to_s,
      'shape_id': gtfs_tripdata[:shape_id].to_s,
      'trip_headsign': gtfs_tripdata[:trip_headsign].to_s,
      'trip_short_name': gtfs_tripdata[:trip_short_name].to_s,
      'direction_id': gtfs_tripdata[:direction_id].to_i,
      'route_desc': gtfs_routedata[:route_desc].to_s,
      'route_type': gtfs_routedata[:route_type].to_i,
      'stop_desc': gtfs_stopdata[:stop_desc].to_s,
      'stop_name': gtfs_stopdata[:stop_name].to_s,
      'stop_lat': gtfs_stopdata[:stop_lat].to_f,
      'stop_lon': gtfs_stopdata[:stop_lon].to_f,
      'scheduled_arrival_time': normalize_local_date(gtfs_stoptimedata[:arrival_time], start_date),
      'actual_arrival_time': 0,
      'actual_arrival_time_dow': 0,
      'actual_arrival_time_hour': 0,
      'arrival_time_diff': 0,
      'shape_dist_traveled': gtfs_stoptimedata[:shape_dist_traveled].to_f,
      'schedule_relationship': trip_update['trip_update']['trip']['schedule_relationship'].to_i
    )
    stop_seq_id += 1
  end
end

# process scheduled trips from logstash
#
# trip_update - trip_update from swiftly, by way of logstash
# results_array - array to be populated with each processed trip, passed by reference
def process_scheduled_trips(trip_update, results_array)
  swiftly_tripdata = trip_update['trip_update']['trip']

  # Get trip and route data from GTFS sources
  gtfs_tripdata = get_gtfs_trip(trip_update['trip_update']['trip']['trip_id'])[0]
  gtfs_routedata = get_gtfs_route(gtfs_tripdata[:route_id])[0]
  return if gtfs_tripdata.nil? || gtfs_routedata.nil?

  trip_id = gtfs_tripdata[:trip_id].to_s
  LOG.debug("Processing scheduled trip #{trip_id}")

  start_date = swiftly_tripdata['start_date']
  if start_date.nil?
    LOG.warn('Start date not found')
    return
  end

  trip_update['trip_update']['stop_time_update'].each do |stop_time_update|
    stop_id = stop_time_update['stop_id'].to_s
    LOG.debug("Processing #{stop_id}")

    # Get stop data from GTFS sources
    gtfs_stopdata = get_gtfs_stop(stop_id)[0]
    break if gtfs_stopdata.nil?

    LOG.debug("Processing #{trip_id} - #{stop_time_update['stop_sequence'].to_s}")

    # Loop until we find the first non existant stop
    gtfs_stoptimedata = get_gtfs_stop_time(trip_id, stop_time_update['stop_sequence'])[0]

    if gtfs_stoptimedata.nil?
      LOG.error("stop_time_id #{trip_id} - #{stop_time_update['stop_sequence'].to_s} not found")
      next
    end

    scheduled_arrival_time = normalize_local_date(gtfs_stoptimedata[:arrival_time], start_date)

    arrival = (stop_time_update['arrival'] || stop_time_update['departure'])
    if !arrival.nil?
      actual_arrival_time = arrival['time'].to_i
      arrival_time_diff = actual_arrival_time - scheduled_arrival_time
      actual_arrival_hour = Time.at(actual_arrival_time).hour
      actual_arrival_wday = Time.at(actual_arrival_time).wday
    else
      LOG.error("Unable to get arrival time for trip_id: #{trip_id}, route_id #{gtfs_routedata[:route_id].to_i}")
      actual_arrival_time = 0
      arrival_time_diff = 0
      actual_arrival_hour = 0
      actual_arrival_wday = 0
    end

    results_array << LogStash::Event.new(
      'aggregate_id': trip_id + '-' + start_date + '-' + stop_time_update['stop_id'].to_s,
      'route_id': gtfs_routedata[:route_id].to_i,
      'trip_id': trip_id.to_i,
      'stop_id': stop_id.to_i,
      'stop_sequence': stop_time_update['stop_sequence'].to_i,
      'route_short_name': gtfs_routedata[:route_short_name].to_s,
      'route_long_name': gtfs_routedata[:route_long_name].to_s,
      'route_color': gtfs_routedata[:route_color].to_s,
      'route_text_color': gtfs_routedata[:route_text_color].to_s,
      'shape_id': gtfs_tripdata[:shape_id].to_s,
      'trip_headsign': gtfs_tripdata[:trip_headsign].to_s,
      'trip_short_name': gtfs_tripdata[:trip_short_name].to_s,
      'direction_id': gtfs_tripdata[:direction_id].to_i,
      'route_desc': gtfs_routedata[:route_desc].to_s,
      'route_type': gtfs_routedata[:route_type].to_i,
      'stop_desc': gtfs_stopdata[:stop_desc].to_s,
      'stop_name': gtfs_stopdata[:stop_name].to_s,
      'stop_lat': gtfs_stopdata[:stop_lat].to_f,
      'stop_lon': gtfs_stopdata[:stop_lon].to_f,
      'scheduled_arrival_time': scheduled_arrival_time.to_i,
      'actual_arrival_time': actual_arrival_time.to_i,
      'actual_arrival_time_dow': actual_arrival_wday.to_i,
      'actual_arrival_time_hour': actual_arrival_hour.to_i,
      'arrival_time_diff': arrival_time_diff.to_i,
      'shape_dist_traveled': gtfs_stoptimedata[:shape_dist_traveled].to_f,
      'schedule_relationship': swiftly_tripdata['schedule_relationship'].to_i
    )
  end
end

# the filter method receives an event and must return a list of events.
# Dropping an event means not including it in the return array,
# while creating new ones only requires you to add a new instance of
# LogStash::Event to the returned array
def filter(event)
  LOG.debug('Entering filter')
  results_array = []

  if event.get('entity').nil?
    LOG.error('Nil event')
    return results_array
  end

  event.get('entity').each do |trip_update|
    LOG.debug('Processing trip')

    if trip_update['trip_update']['trip']['schedule_relationship'] == CANCELED
      process_canceled_trip(trip_update, results_array)
    else
      process_scheduled_trips(trip_update, results_array)
    end
  end
  results_array
end
