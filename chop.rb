# Takes in the raw Swiftly data and generates logstash events

require 'csv'
require 'time'
require 'logger'

require_relative 'constants'

LOG = Logger.new(STDOUT)
LOG.level = Logger::WARN

# Loads the gtfs from disk, if its already been loaded and pickled, or it creates the structure and saves it
#
# data_path - path where the pickled data stucture should be saved; can be a temp path
# gtfs_file_path - path to the ascii version of the gtfs file to be loaded and returned
#
# return: the data from gtfs_file_path returned as a hash
def load_data(data_path, gtfs_file_path = nil)
  if File.file?(data_path)
    output = Marshal.load(File.binread(data_path))
  else
    content = File.read(gtfs_file_path, encoding: 'bom|utf-8')
    output = CSV.parse(content, headers: true, converters: :all)
    File.open(data_path, 'wb') { |f| f.write(Marshal.dump(output)) }
  end
  output
end

def load_stop_times(data_path, gtfs_file_path)
  if File.file?(data_path)
    output = load_data(data_path, gtfs_file_path)
  else
    output = {}
    load_data(data_path, gtfs_file_path).each do |row|
      id = row['trip_id'].to_s + '-' + row['stop_sequence'].to_s
      output[id] = row
    end
    File.open(data_path, 'wb') { |f| f.write(Marshal.dump(output)) }
  end
  output
end

# the value of `params` is the value of the hash passed to `script_params`
# in the logstash configuration
def register(_params)
  LOG.debug('Entering register')
  route_file = '/tmp/routes_data'
  trips_file = '/tmp/trips_data'
  stops_file = '/tmp/stops_data'
  stop_times_file = '/tmp/stop_times_data'

  @routes = load_data(route_file, ROUTES_FILE)
  @trips = load_data(trips_file, TRIPS_FILE)
  @stops = load_data(stops_file, STOPS_FILE)
  @stop_times = load_stop_times(stop_times_file, STOP_TIMES_FILE)
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

  Time.new(realdate.year,
           realdate.month,
           realdate.day,
           hour,
           minute,
           second,
           Time.now.utc_offset).to_time.to_i
end

def get_gtfs_generic(id, data, element)
  output = data.detect { |x| x[element] == id.to_i }
  LOG.error("#{element} #{id} not found") if output.nil?
  output
end

# Get the trip data from the GTFS file
def get_gtfs_trip(trip_id, data = @trips)
  get_gtfs_generic(trip_id, data, 'trip_id')
end

# Get the route data from the GTFS file
def get_gtfs_route(route_id, data = @routes)
  get_gtfs_generic(route_id, data, 'route_id')
end

# Get the stop data from the GTFS file
def get_gtfs_stop(stop_id, data = @stops)
  get_gtfs_generic(stop_id, data, 'stop_id')
end

# process scheduled trips from logstash
#
# trip_update - trip_update from swiftly, by way of logstash
# results_array - array to be populated with each processed trip, passed by reference
def process_canceled_trip(trip_update, results_array)
  # Get trip and route data from GTFS sources
  gtfs_tripdata = get_gtfs_trip(trip_update['trip_update']['trip']['trip_id'])
  gtfs_routedata = get_gtfs_route(gtfs_tripdata['route_id'])
  return if gtfs_tripdata.nil? || gtfs_routedata.nil?

  trip_id = gtfs_tripdata['trip_id'].to_s
  LOG.debug("Processing canceled trip #{trip_id}")

  # Lets fill in all of the stops in case the trip is uncanceled, and to have complete data
  start_date = Time.at(trip_update['trip_update']['timestamp']).to_datetime.strftime('%Y%m%d')

  stop_seq_id = 1
  loop do
    stop_time_id = trip_id + '-' + stop_seq_id.to_s
    LOG.debug("Processing #{stop_time_id}")

    # Loop until we find the first non existant stop
    gtfs_stoptimedata = @stop_times[stop_time_id]
    break if gtfs_stoptimedata.nil?

    # Get stop data from GTFS sources
    gtfs_stopdata = get_gtfs_stop(gtfs_stoptimedata['stop_id'])
    break if gtfs_stopdata.nil?

    results_array << LogStash::Event.new(
      aggregate_id: trip_id + '-' + start_date + '-' + gtfs_stoptimedata['stop_id'].to_s,
      route_id: gtfs_routedata['route_id'].to_i,
      trip_id: trip_id.to_i,
      stop_id: gtfs_stoptimedata['stop_id'].to_i,
      stop_sequence: stop_seq_id.to_i,
      route_short_name: gtfs_routedata['route_short_name'].to_s,
      route_long_name: gtfs_routedata['route_long_name'].to_s,
      route_color: gtfs_routedata['route_color'].to_s,
      route_text_color: gtfs_routedata['route_text_color'].to_s,
      shape_id: gtfs_tripdata['shape_id'].to_s,
      trip_headsign: gtfs_tripdata['trip_headsign'],
      trip_short_name: gtfs_tripdata['trip_short_name'],
      direction_id: gtfs_tripdata['direction_id'],
      route_desc: gtfs_routedata['route_desc'],
      route_type: gtfs_routedata['route_type'],
      stop_desc: gtfs_stopdata['stop_desc'],
      stop_name: gtfs_stopdata['stop_name'],
      stop_lat: gtfs_stopdata['stop_lat'].to_f,
      stop_lon: gtfs_stopdata['stop_lon'].to_f,
      scheduled_arrival_time: normalize_local_date(gtfs_stoptimedata['arrival_time'], start_date),
      actual_arrival_time: 0,
      actual_arrival_time_dow: 0,
      actual_arrival_time_hour: 0,
      arrival_time_diff: 0,
      shape_dist_traveled: gtfs_stoptimedata['shape_dist_traveled'],
      schedule_relationship: trip_update['trip_update']['trip']['schedule_relationship']
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
  gtfs_tripdata = get_gtfs_trip(trip_update['trip_update']['trip']['trip_id'])
  gtfs_routedata = get_gtfs_route(gtfs_tripdata['route_id'])
  return if gtfs_tripdata.nil? || gtfs_routedata.nil?

  trip_id = gtfs_tripdata['trip_id'].to_s
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
    gtfs_stopdata = get_gtfs_stop(stop_id)
    break if gtfs_stopdata.nil?

    stop_time_id = trip_id + '-' + stop_time_update['stop_sequence'].to_s
    LOG.debug("Processing #{stop_time_id}")

    # Loop until we find the first non existant stop
    gtfs_stoptimedata = @stop_times[stop_time_id]

    if gtfs_stoptimedata.nil?
      LOG.error("stop_time_id #{stop_time_id} not found")
      next
    end

    scheduled_arrival_time = normalize_local_date(gtfs_stoptimedata['arrival_time'], start_date)

    arrival = (stop_time_update['arrival'] || stop_time_update['departure'])
    if !arrival.nil?
      actual_arrival_time = arrival['time'].to_i
      arrival_time_diff = actual_arrival_time - scheduled_arrival_time
      actual_arrival_hour = Time.at(actual_arrival_time).hour
      actual_arrival_wday = Time.at(actual_arrival_time).wday
    else
      LOG.error("Unable to get arrival time for trip_id: #{trip_id}, route_id #{gtfs_routedata['route_id'].to_i}")
      actual_arrival_time = 0
      arrival_time_diff = 0
      actual_arrival_hour = 0
      actual_arrival_wday = 0
    end

    results_array << LogStash::Event.new(
      aggregate_id: trip_id + '-' + start_date + '-' + stop_time_update['stop_id'].to_s,
      route_id: gtfs_routedata['route_id'].to_i,
      trip_id: trip_id.to_i,
      stop_id: stop_id.to_i,
      stop_sequence: stop_time_update['stop_sequence'].to_i,
      route_short_name: gtfs_routedata['route_short_name'].to_s,
      route_long_name: gtfs_routedata['route_long_name'].to_s,
      route_color: gtfs_routedata['route_color'].to_s,
      route_text_color: gtfs_routedata['route_text_color'].to_s,
      shape_id: gtfs_tripdata['shape_id'].to_s,
      trip_headsign: gtfs_tripdata['trip_headsign'],
      trip_short_name: gtfs_tripdata['trip_short_name'],
      direction_id: gtfs_tripdata['direction_id'],
      route_desc: gtfs_routedata['route_desc'],
      route_type: gtfs_routedata['route_type'],
      stop_desc: gtfs_stopdata['stop_desc'],
      stop_name: gtfs_stopdata['stop_name'],
      stop_lat: gtfs_stopdata['stop_lat'].to_f,
      stop_lon: gtfs_stopdata['stop_lon'].to_f,
      scheduled_arrival_time: scheduled_arrival_time,
      actual_arrival_time: actual_arrival_time,
      actual_arrival_time_dow: actual_arrival_wday,
      actual_arrival_time_hour: actual_arrival_hour,
      arrival_time_diff: arrival_time_diff,
      shape_dist_traveled: gtfs_stoptimedata['shape_dist_traveled'],
      schedule_relationship: swiftly_tripdata['schedule_relationship']
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
