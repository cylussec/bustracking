require 'csv'

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

# the filter method receives an event and must return a list of events.
# Dropping an event means not including it in the return array,
# while creating new ones only requires you to add a new instance of
# LogStash::Event to the returned array
def filter(event)
    if event.get('entity').nil?
        print "#{Time.now} Nil event"
        print event
        return []
    end
    puts "#{Time.now} Chop"
    new_array = Array.new
    event.get('entity').each do |trip_update|
        trip_data = trip_update['trip_update']['trip']
        trip = @trips.detect{ |trip| trip['trip_id'] == trip_data['trip_id'] }
        route = @routes.detect{ |route| route['route_id'] == trip_data['route_id'] }
        start_date = trip_data['start_date']
        if start_date.nil?
            next
        end
        pre_aggregate_id = trip_data['trip_id'].to_s + '-'  + start_date
        trip_update['trip_update']['stop_time_update'].each do |stop_time_update|
                        aggregate_id = pre_aggregate_id + '-' + stop_time_update['stop_id'].to_s
                        stop_id = stop_time_update['stop_id'].to_s
            stop_sequence = stop_time_update['stop_sequence'].to_s
            route_id = route['route_id'].to_s
            route_short_name = route['route_short_name'].to_s
            route_long_name = route['route_long_name'].to_s
            route_color = route['route_color'].to_s
            route_text_color = route['route_text_color'].to_s
            shape_id = trip['shape_id'].to_s
            trip_id = trip['trip_id'].to_s

            stop_time_id = trip['trip_id'].to_s + '-' + stop_time_update['stop_sequence'].to_s
            stop = @stops.detect{ |stop| stop['stop_id'] == stop_id }
            stop_time = @stop_times[stop_time_id]
            
            if !stop_time_update['arrival'].nil? 
                actual_arrival_time = stop_time_update['arrival']['time'].to_i
                scheduled_arrival_time = stop_time['arrival_time']
                timesplit = scheduled_arrival_time.split(':')
                hour = timesplit[0].to_i
                minute = timesplit[1].to_i
                second = timesplit[2].to_i
                realdate = start_date.to_i
                if hour > 23
                  realdate += 1
                  hour -= 24
                end
                realtime = hour.to_s + ':' + minute.to_s + ':' + second.to_s
                mystr = realdate.to_s + ' ' + realtime + '  -0400'
                mydate = DateTime.strptime(mystr, '%Y%m%d %k:%M:%S %z')
                scheduled_arrival_time = mydate.to_time.to_i            
                arrival_time_diff = actual_arrival_time - scheduled_arrival_time
                new_array.push LogStash::Event.new({
                    :aggregate_id => aggregate_id,
                    :route_id => route_id.to_i,
                    :trip_id => trip_id.to_i,
                    :stop_id => stop_id.to_i,
                    :stop_sequence => stop_sequence.to_i,
                    :route_short_name => route_short_name,
                    :route_long_name => route_long_name,
                    :route_color => route_color,
                    :route_text_color => route_text_color,
                    :shape_id => shape_id,
                    :trip_headsign => trip['trip_headsign'],
                    :trip_short_name => trip['trip_short_name'],
                    :direction_id => trip['direction_id'],
                    :route_desc => route['route_desc'],
                    :route_type => route['route_type'],
                    :stop_desc => stop['stop_desc'],
                    :stop_name => stop['stop_name'],
                    :stop_lat => stop['stop_lat'].to_f,
                    :stop_lon => stop['stop_lon'].to_f,
                    :scheduled_arrival_time => scheduled_arrival_time,
                    :actual_arrival_time => actual_arrival_time,
                    :arrival_time_diff => arrival_time_diff,
                    :shape_dist_traveled => stop_time['shape_dist_traveled']    
                })
            end
        end
    end
    return new_array
end
