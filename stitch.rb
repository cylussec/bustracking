# Script that postprocesses data. This should be run every few hours, and only on trips that are complete (so only run
# it on data that is a few hours old to allow the trip to end)

require 'csv'

SCHEDULED = 0
CANCELED = 3

# stop_arrivals
#     [route_id]
#         [stop_id] = last actual_arrival_time

# bus_trip_data
#     [trip_id] = hash
#         [stop_sequence] = hash
#             [distance] = last shape_dist_traveled
#             [actual_arrival_time] = last actual_arrival_time
#
# sets
#    headway
#    shape_dist_traveled_since_prev
#    time_since_last_stop
#    segment_speed

def register(_params)
  print 'Entering register (stitch)'

  @bus_trip_data = Hash.new(Hash.new({}))
  @stop_arrivals = Hash.new({})
end

def filter(event)
  # Does not require postprocessing
  return [event] if event.get(:schedule_relationship) == CANCELED

  trip_id = event.get(:trip_id).to_s
  stop_sequence = event.get(:stop_sequence).to_s
  route_id = event.get(:route_id).to_s
  stop_id = event.get(:stop_id).to_s

  # This relies on us only running this script on previous stop data. The scheduled stops are included
  # in the emited events, so if this is run on data, it will provide bad bus stop data, and will use future data.
  unless @stop_arrivals[route_id][stop_id].nil?
    event.set('headway', event.get('actual_arrival_time') - @stop_arrivals[route_id][stop_id])
  end

  # Populate stop_arrivals
  if event.get('actual_arrival_time') > @stop_arrivals[route_id][stop_id]
    @stop_arrivals[route_id][stop_id] = event.get('actual_arrival_time')
  end

  # Populate bus_trip_data
  @bus_trip_data[trip_id][stop_sequence] = { 'distance' => event.get(:shape_dist_traveled),
                                             'actual_arrival_time' => event.get(:actual_arrival_time) }

  # A shortcut for reprocessing data. If we already have these calculated, then skip this.
  postprocess = [event.get(:shape_dist_traveled_since_prev),
                 event.get(:time_since_last_stop),
                 event.get(:segment_speed)].include?(nil)

  postprocess(event, trip_id, stop_sequence) if postprocess

  [event]
end

def postprocess_data(event, trip_id, stop_sequence)
  last_stop_distance, last_stop_time = find_last_stop(@bus_trip_data[trip_id], stop_sequence)

  unless last_stop_distance.nil?
    event.set(:shape_dist_traveled_since_prev, (event.get(:shape_dist_traveled).to_f - last_stop_distance))
  end

  unless last_stop_time.nil?
    event.set(:time_since_last_stop, (event.get(:actual_arrival_time).to_i - last_stop_time))
  end

  unless (last_stop_distance.nil? || last_stop_time.nil?) && event.get(:time_since_last_stop) != 0
    event.set(:segment_speed,
              (event.get(:shape_dist_traveled_since_prev) * 3600 / event.get(:time_since_last_stop)))
  end
end

def find_last_stop(bus_run_data, stop_sequence)
  # Finds the last valid stop data backwards from the specified stop. This glosses over missing data
  #
  # @param bus_run_data Hash of stops => actual stop time
  # @param stop_sequence The stop sequence number we use as our reference
  stop_sequence = stop_sequence.to_i - 1
  distance = nil
  actual_arrival_time = nil
  (1..stop_sequence).reverse_each do |i|
    next if bus_run_data[i].nil?
    next if bus_run_data[i]['distance'].nil?
    next if bus_run_data[i]['actual_arrival_time'].nil?

    distance = bus_run_data[i]['distance'].to_f
    actual_arrival_time = bus_run_data[i]['actual_arrival_time'].to_i
    break
  end

  [distance, actual_arrival_time]
end
