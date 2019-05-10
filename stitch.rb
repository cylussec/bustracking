require 'csv'

$bus_trip_data = Hash.new
$bus_stop_data = Hash.new

def register(params)
    puts 'Entering register (stitch)'
end

def filter(event)

    if not (event.get('average_speed').nil? or event.get('time_between_stops').nil?)
        #puts "skipping #{event.get('trip_id')} :: #{event.get('stop_sequence')}"
        return []
    end

    trip_id = event.get('trip_id')
    stop_sequence = event.get('stop_sequence')
    # puts "Processing trip #{trip_id} and stop #{stop_sequence}"
    # This relies on us only running this script on previous stop data. The scheduled stops are included
    # in the emmited events, so if this is run on data, it will provide bad bus stop data, and will use future data. 
    if $bus_stop_data[event.get('stop_id')]
        event.set('headway', event.get('actual_arrival_time') - $bus_stop_data[event.get('stop_id')])
    end
    $bus_stop_data[event.get('stop_id')] = event.get('actual_arrival_time')

    if $bus_trip_data[trip_id].nil?
        $bus_trip_data[trip_id] = Hash.new
    end

    if $bus_trip_data[trip_id][stop_sequence].nil?
        $bus_trip_data[trip_id][stop_sequence] = Hash.new
    end

    $bus_trip_data[trip_id][stop_sequence]['distance'] = event.get('shape_dist_traveled')
    $bus_trip_data[trip_id][stop_sequence]['stop_time'] = event.get('actual_arrival_time')

    #puts "Got distance #{event.get('shape_dist_traveled')} and time #{event.get('actual_arrival_time')}"

    if not (event.get('shape_dist_traveled_since_prev').nil? or event.get('time_since_last_stop').nil? or event.get('segment_speed').nil?)
        return []
    end

    last_stop_distance, last_stop_time = find_last_stop($bus_trip_data[trip_id], stop_sequence)
    if not last_stop_distance.nil? 
        event.set('shape_dist_traveled_since_prev', (event.get('shape_dist_traveled').to_f - last_stop_distance))
    end

    if not last_stop_time.nil?
        event.set('time_since_last_stop', (event.get('actual_arrival_time').to_i - last_stop_time))
    end

    if not (last_stop_distance.nil? or last_stop_time.nil?) and event.get('time_since_last_stop') != 0
        event.set('segment_speed', (event.get('shape_dist_traveled_since_prev')*3600/event.get('time_since_last_stop')))
    end

    return [event]
end

def find_last_stop(bus_run_data, stop_sequence)
    stop_sequence = stop_sequence.to_i - 1
    (1..stop_sequence).reverse_each do |i|
        if bus_run_data[i].nil?
            next
        end
        if not bus_run_data[i]['distance'].nil? and not bus_run_data[i]['stop_time'].nil?
            #puts "find_last_stop returning #{bus_run_data[i]['distance']}, #{bus_run_data[i]['stop_time']}"
            return bus_run_data[i]['distance'].to_f, bus_run_data[i]['stop_time'].to_i
        end
    end

    return nil, nil
end
