# Takes in the raw Swiftly data and generates logstash events

require 'csv'
require 'date'


SCHEDULED = 0
CANCELED = 3

# the value of `params` is the value of the hash passed to `script_params`
# in the logstash configuration
def register(params)
    print 'Entering register (chop)'
    route_file = '/tmp/routes_data'
    trips_file = '/tmp/trips_data'
    stops_file = '/tmp/stops_data'
    stop_times_file = '/tmp/stop_times_data'

    if File.file?(route_file)
        @routes = Marshal.load(File.binread(route_file))
    else
        @routes = CSV.read("/opt/bitnami/logstash/mta-transit-data/routes.txt", headers:true)
        File.open(route_file, 'wb') {|f| f.write(Marshal.dump(@routes))}
    end

    if File.file?(trips_file)
        @trips = Marshal.load(File.binread(trips_file))
    else
        @trips = CSV.read("/opt/bitnami/logstash/mta-transit-data/trips.txt", headers:true)
        File.open(trips_file, 'wb') {|f| f.write(Marshal.dump(@trips))}
    end

    if File.file?(stops_file)
        @stops = Marshal.load(File.binread(stops_file))
    else
        @stops = CSV.read("/opt/bitnami/logstash/mta-transit-data/stops.txt", headers:true)
        File.open(stops_file, 'wb') {|f| f.write(Marshal.dump(@stops))}
    end

    if File.file?(stop_times_file)
        @stop_times = Marshal.load(File.binread(stop_times_file))
    else
        @stop_times = Hash.new
        CSV.foreach("/opt/bitnami/logstash/mta-transit-data/stop_times.txt", headers:true) do |row|
            id = row['trip_id'].to_s + '-' + row['stop_sequence'].to_s
            @stop_times[id] = row
        end
        File.open(stop_times_file, 'wb') {|f| f.write(Marshal.dump(@stop_times))}
    end
end

# Takes a time in the format hh:mm:ss as well as the date (at the beginning of the route) and converts it to epoc time. 
# It also accepts times like 25:45:38, indicating the route operated past midnight, and corrects the date.
#
# Returns an integer of the epoc time
def normalize_date(input_time, start_date)
    begin
        timesplit = input_time.split(':')
    rescue NoMethodError
        puts "ERROR: NoMethodError - stop_time"
    end

    hour = timesplit[0].to_i
    minute = timesplit[1].to_i
    second = timesplit[2].to_i

    realdate = start_date.to_i
    if hour > 23
      realdate += 1
      hour -= 24
    end
    datestr = realdate.to_s + ' ' + hour.to_s + ':' + minute.to_s + ':' + second.to_s + '  -0400'
    return DateTime.strptime(datestr, '%Y%m%d %k:%M:%S %z').to_time.to_i   
end

# the filter method receives an event and must return a list of events.
# Dropping an event means not including it in the return array,
# while creating new ones only requires you to add a new instance of
# LogStash::Event to the returned array
def filter(event)
    new_array = Array.new

    if event.get('entity').nil?
        print "#{Time.now} ERROR Nil event"
        return new_array
    end
    
    event.get('entity').each do |trip_update|
        swiftly_tripdata = trip_update['trip_update']['trip']

        # Get trip data from GTFS sources
        gtfs_tripdata = @trips.detect{ |trip| trip['trip_id'] == swiftly_tripdata['trip_id'] }
        if gtfs_tripdata.nil?
            puts "#{Time.now} ERROR: trip_id #{swiftly_tripdata['trip_id']} not found"
            next
        end

        # Get route data from GTFS sources
        gtfs_routedata = @routes.detect{ |route| route['route_id'] == gtfs_tripdata['route_id'] }
        if gtfs_routedata.nil?
            puts "#{Time.now} ERROR: route_id #{swiftly_tripdata['route_id']} not found"
            next
        end

        trip_id = gtfs_tripdata['trip_id'].to_s

        if swiftly_tripdata['schedule_relationship'] == CANCELED
            # Lets fill in all of the stops in case the trip is uncancelled, and to have complete data
            start_date = Time.at(trip_update['trip_update']['timestamp']).to_datetime.strftime("%Y%m%d")
            stop_time_updates = @stop_times.select{ |st| st['trip_id'] == trip_id }

            stop_seq_id = 1
            while true
                stop_time_id = trip_id + '-' + stop_seq_id.to_s
                gtfs_stoptimedata = @stop_times[stop_time_id]
                if gtfs_stoptimedata.nil?
                    # We found the non existant stop 
                    puts "#{Time.now} ERROR: stop_time_id #{stop_time_id} not found"
                    break
                end

                # Get stop data from GTFS sources
                gtfs_stopdata = @stops.detect{ |stop| stop['stop_id'] == gtfs_stoptimedata['stop_id'] }
                if gtfs_stopdata.nil?
                    puts "#{Time.now} ERROR: stop_id #{stop_id} not found"
                    next
                end

                new_array.push LogStash::Event.new({
                    :aggregate_id => trip_id + '-'  + start_date + '-' + gtfs_stoptimedata['stop_id'].to_s,
                    :route_id => gtfs_routedata['route_id'].to_i,
                    :trip_id => trip_id.to_i,
                    :stop_id => gtfs_stoptimedata['stop_id'].to_i,
                    :stop_sequence => stop_seq_id.to_i,
                    :route_short_name => gtfs_routedata['route_short_name'].to_s,
                    :route_long_name => gtfs_routedata['route_long_name'].to_s,
                    :route_color => gtfs_routedata['route_color'].to_s,
                    :route_text_color => gtfs_routedata['route_text_color'].to_s,
                    :shape_id => gtfs_tripdata['shape_id'].to_s,
                    :trip_headsign => gtfs_tripdata['trip_headsign'],
                    :trip_short_name => gtfs_tripdata['trip_short_name'],
                    :direction_id => gtfs_tripdata['direction_id'],
                    :route_desc => gtfs_routedata['route_desc'],
                    :route_type => gtfs_routedata['route_type'],
                    :stop_desc => gtfs_stopdata['stop_desc'],
                    :stop_name => gtfs_stopdata['stop_name'],
                    :stop_lat => gtfs_stopdata['stop_lat'].to_f,
                    :stop_lon => gtfs_stopdata['stop_lon'].to_f,
                    :scheduled_arrival_time => normalize_date(gtfs_stoptimedata['arrival_time'], start_date),
                    :actual_arrival_time => 0,
                    :actual_arrival_time_dow => 0,
                    :actual_arrival_time_hour => 0,
                    :arrival_time_diff => 0,
                    :shape_dist_traveled => gtfs_stoptimedata['shape_dist_traveled'],
                    :schedule_relationship => swiftly_tripdata['schedule_relationship']
                })
                stop_seq_id += 1
            end
            next
        end

        start_date = swiftly_tripdata['start_date']
        if start_date.nil?
            puts "#{Time.now} WARNING: Start date not found"
            next
        end
        stop_time_updates = trip_update['trip_update']['stop_time_update']
  
        stop_time_updates.each do |stop_time_update|
            stop_id = stop_time_update['stop_id'].to_s

            # Get stop data from GTFS sources
            gtfs_stopdata = @stops.detect{ |stop| stop['stop_id'] == stop_id }
            if gtfs_stopdata.nil?
                puts "#{Time.now} ERROR: stop_id #{stop_id} not found"
                next
            end

            stop_time_id = trip_id + '-' + stop_time_update['stop_sequence'].to_s
            gtfs_stoptimedata = @stop_times[stop_time_id]
            if gtfs_stoptimedata.nil?
                puts "#{Time.now} ERROR: stop_time_id #{stop_time_id} not found"
                next
            end

            scheduled_arrival_time  = normalize_date(gtfs_stoptimedata['arrival_time'], start_date)
            
            arrival = (stop_time_update['arrival'] or stop_time_update['departure']) 
            if !arrival.nil? 
                actual_arrival_time = arrival['time'].to_i    
                arrival_time_diff = actual_arrival_time - scheduled_arrival_time
                actual_arrival_hour = Time.at(actual_arrival_time).hour
                actual_arrival_wday = Time.at(actual_arrival_time).wday
            else
                puts "Unable to get arrival time for trip_id: #{trip_id}, route_id #{gtfs_routedata['route_id'].to_i}"
                actual_arrival_time = 0
                arrival_time_diff = 0
                actual_arrival_hour = 0
                actual_arrival_wday = 0
            end

            new_array.push LogStash::Event.new({
                :aggregate_id => trip_id + '-'  + start_date + '-' + stop_time_update['stop_id'].to_s,
                :route_id => gtfs_routedata['route_id'].to_i,
                :trip_id => trip_id.to_i,
                :stop_id => stop_id.to_i,
                :stop_sequence => stop_time_update['stop_sequence'].to_i,
                :route_short_name => gtfs_routedata['route_short_name'].to_s,
                :route_long_name => gtfs_routedata['route_long_name'].to_s,
                :route_color => gtfs_routedata['route_color'].to_s,
                :route_text_color => gtfs_routedata['route_text_color'].to_s,
                :shape_id => gtfs_tripdata['shape_id'].to_s,
                :trip_headsign => gtfs_tripdata['trip_headsign'],
                :trip_short_name => gtfs_tripdata['trip_short_name'],
                :direction_id => gtfs_tripdata['direction_id'],
                :route_desc => gtfs_routedata['route_desc'],
                :route_type => gtfs_routedata['route_type'],
                :stop_desc => gtfs_stopdata['stop_desc'],
                :stop_name => gtfs_stopdata['stop_name'],
                :stop_lat => gtfs_stopdata['stop_lat'].to_f,
                :stop_lon => gtfs_stopdata['stop_lon'].to_f,
                :scheduled_arrival_time => scheduled_arrival_time,
                :actual_arrival_time => actual_arrival_time,
                :actual_arrival_time_dow => actual_arrival_wday,
                :actual_arrival_time_hour => actual_arrival_hour,
                :arrival_time_diff => arrival_time_diff,
                :shape_dist_traveled => gtfs_stoptimedata['shape_dist_traveled'],
                :schedule_relationship => swiftly_tripdata['schedule_relationship']
            })
        end
    end
    return new_array
end
