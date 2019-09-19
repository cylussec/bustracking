# Script that postprocesses data. This should be run every few hours, and only on trips that are complete (so only run
# it on data that is a few hours old to allow the trip to end)

require 'csv'

SCHEDULED = 0
CANCELED = 3

# bus_stop_data
#     [route_id]
#         [stop_id] = last actual_arrival_time

# bus_trip_data
#     [trip_id] = hash
#         [stop_sequence] = hash
#             [distance] = last shape_dist_traveled
#             [stop_time] = last actual_arrival_time
#
# sets
#    headway
#    shape_dist_traveled_since_prev
#    time_since_last_stop
#    segment_speed

$bus_trip_data = Hash.new
$bus_stop_data = Hash.new

def register(params)
    print 'Entering register (stitch)'
end

def filter(event)
    if event.get('schedule_relationship') == CANCELED
        # Does not require postprocessing
        return [event]
    end

    trip_id = event.get('trip_id').to_s
    stop_sequence = event.get('stop_sequence').to_s
    route_id = event.get('route_id').to_s
    stop_id = event.get('stop_id').to_s

    if $bus_stop_data[route_id].nil?
        $bus_stop_data[route_id] = Hash.new
    end
    
    # This relies on us only running this script on previous stop data. The scheduled stops are included
    # in the emmited events, so if this is run on data, it will provide bad bus stop data, and will use future data. 
    if not $bus_stop_data[route_id][stop_id].nil?
        event.set('headway', event.get('actual_arrival_time') - $bus_stop_data[route_id][stop_id])
    end
    $bus_stop_data[route_id][stop_id] = event.get('actual_arrival_time')

    if $bus_trip_data[trip_id].nil?
        $bus_trip_data[trip_id] = Hash.new
    end

    if $bus_trip_data[trip_id][stop_sequence].nil?
        $bus_trip_data[trip_id][stop_sequence] = Hash.new
    end

    $bus_trip_data[trip_id][stop_sequence]['distance'] = event.get('shape_dist_traveled')
    $bus_trip_data[trip_id][stop_sequence]['stop_time'] = event.get('actual_arrival_time')

    # A shortcut for reprocessing data. If we already have these calculated, then skip this.
    if event.get('shape_dist_traveled_since_prev').nil? or event.get('time_since_last_stop').nil? or event.get('segment_speed').nil?
        last_stop_distance, last_stop_time = find_last_stop($bus_trip_data[trip_id], stop_sequence)
        if not last_stop_distance.nil? 
            event.set('shape_dist_traveled_since_prev', (event.get('shape_dist_traveled').to_f - last_stop_distance))
        end

        if not last_stop_time.nil?
            event.set('time_since_last_stop', (event.get('actual_arrival_time').to_i - last_stop_time))
        end

        if not (last_stop_distance.nil? or last_stop_time.nil?) and event.get('time_since_last_stop') != 0
            event.set('segment_speed', (event.get('shape_dist_traveled_since_prev') * 3600 / event.get('time_since_last_stop')))
        end
    end

    return [event]
end

def find_last_stop(bus_run_data, stop_sequence)
    # Finds the last valid stop data backwards from the specified stop. This glosses over missing data
    #
    # @param bus_run_data Hash of stops => actual stop time
    # @param stop_sequence The stop sequence number we use as our reference
    stop_sequence = stop_sequence.to_i - 1
    (1..stop_sequence).reverse_each do |i|
        if bus_run_data[i].nil?
            next
        end
        if not bus_run_data[i]['distance'].nil? and not bus_run_data[i]['stop_time'].nil?
            return bus_run_data[i]['distance'].to_f, bus_run_data[i]['stop_time'].to_i
        end
    end

    return nil, nil
end
