# Tests for the chop.rb and stitch.rb methods

require 'json'
require 'test/unit'
require 'tmpdir'

require_relative 'chop'
require_relative 'stitch'
require_relative 'constants'

# Mirrors the functionality of the builtin LogStash::Event class
module LogStash
  class Event
    def initialize(**args)
      @hash = args
    end

    def get(key)
      @hash[key]
    end

    def set(key, value)
      @hash[key] = value
    end
  end
end

# This is test data for the trip, route, and stop data. Its an arbitrary data element from each
# Its used in the load data tests.
VALIDATION_DATA = {
  'trips' =>
  [
    'trip_data',                          # data file name
    2_412_396,                            # valid trip id (same as validation data)
    2_513_148,                            # invaid trip id
    {
      'route_id' => 11_745,               # validation data
      'service_id' => 3,
      'trip_id' => 2_412_396,
      'trip_headsign' => 'YW PATAPSCO LR',
      'trip_short_name' => nil,
      'direction_id' => 0,
      'block_id' => 380_031,
      'shape_id' => 113_483,
      'wheelchair_accessible' => 1,
      'bikes_allowed' => 1
    }
  ],
  'routes' =>
  [
    'route_data',
    11_739,
    11_637,
    {
      'route_id' => 11_739,
      'agency_id' => 1,
      'route_short_name' => 'CityLink NAVY',
      'route_long_name' => 'MONDAWMIN - DUNDALK',
      'route_desc' => nil,
      'route_type' => 3,
      'route_url' => nil,
      'route_color' => '0000FF',
      'route_text_color' => 'D2D9D3'
    }
  ],
  'stops' =>
  [
    'stop_data',
    13_704,
    9375,
    {
      'stop_id' => 13_704,
      'stop_code' => 13_704,
      'stop_name' => 'EDENVALE RD & FARRINGDON RD nb',
      'stop_desc' => nil,
      'stop_lat' => 39.372859,
      'stop_lon' => -76.671617,
      'zone_id' => nil,
      'stop_url' => nil,
      'location_type' => nil,
      'parent_station' => nil,
      'stop_timezone' => nil,
      'wheelchair_boarding' => 0
    }
  ],
  'bus_trip_data' => {
    2_395_665 => {
      39 => {
        'distance' => 14.8274,
        'actual_arrival_time' => 1_573_414_737
      },
      40 => {
        'distance' => 16.6596,
        'actual_arrival_time' => 1_573_414_879
      },
      41 => {
        'distance' => 17.0002,
        'actual_arrival_time' => 1_573_414_905
      },
      42 => {
        'distance' => 19.6611,
        'actual_arrival_time' => 1_573_415_137
      }
    }
  }
}.freeze

def pull_gtfs_data
  system('./gtfsdownloader.sh')
end

# unit tests for bus tracking
class TestTransitTrak < Test::Unit::TestCase
  def _validate(valid_test_data, invalid_test_data, validation_data)
    assert_not_nil(valid_test_data)
    assert_nil(invalid_test_data)

    validation_data.each_key do |key|
      assert_equal(valid_test_data[key], validation_data[key])
    end
  end

  def test_load_data_trips
    pull_gtfs_data
    Dir.mktmpdir do |dir|
      tmp_data = "#{dir}/#{VALIDATION_DATA['trips'][0]}"
      data = load_data(tmp_data, TRIPS_FILE)

      _validate(get_gtfs_trip(VALIDATION_DATA['trips'][1], data),
                get_gtfs_trip(VALIDATION_DATA['trips'][2], data),
                VALIDATION_DATA['trips'][3])

      data = load_data(tmp_data, '')
      _validate(get_gtfs_trip(VALIDATION_DATA['trips'][1], data),
                get_gtfs_trip(VALIDATION_DATA['trips'][2], data),
                VALIDATION_DATA['trips'][3])
    end
  end

  def test_load_data_routes
    pull_gtfs_data
    Dir.mktmpdir do |dir|
      tmp_data = "#{dir}/#{VALIDATION_DATA['routes'][0]}"
      data = load_data(tmp_data, ROUTES_FILE)

      _validate(get_gtfs_route(VALIDATION_DATA['routes'][1], data),
                get_gtfs_route(VALIDATION_DATA['routes'][2], data),
                VALIDATION_DATA['routes'][3])

      data = load_data(tmp_data, '')
      _validate(get_gtfs_route(VALIDATION_DATA['routes'][1], data),
                get_gtfs_route(VALIDATION_DATA['routes'][2], data),
                VALIDATION_DATA['routes'][3])
    end
  end

  def test_load_data_stops
    pull_gtfs_data
    Dir.mktmpdir do |dir|
      tmp_data = "#{dir}/#{VALIDATION_DATA['stops'][0]}"
      data = load_data(tmp_data, STOPS_FILE)

      _validate(get_gtfs_stop(VALIDATION_DATA['stops'][1], data),
                get_gtfs_stop(VALIDATION_DATA['stops'][2], data),
                VALIDATION_DATA['stops'][3])

      data = load_data(tmp_data, '')
      _validate(get_gtfs_stop(VALIDATION_DATA['stops'][1], data),
                get_gtfs_stop(VALIDATION_DATA['stops'][2], data),
                VALIDATION_DATA['stops'][3])
    end
  end

  def test_load_stop_times
    pull_gtfs_data
    validate_st = lambda do |stop_times|
      assert_not_nil(stop_times['2398318-23'])
      assert_nil(stop_times['2398318-200'])
      assert_equal(stop_times['2398318-23']['arrival_time'], ' 7:43:00')
    end

    Dir.mktmpdir do |dir|
      tmp_data = "#{dir}/stop_time_data"
      validate_st.call(load_stop_times(tmp_data, STOP_TIMES_FILE))
      validate_st.call(load_stop_times(tmp_data, ''))
    end
  end

  def test_normalize_local_date
    assert_equal(1_577_733_900, normalize_local_date('14:25:00', '2019/12/30'))
    assert_equal(1_573_262_300, normalize_local_date('20:18:20', '2019/11/8'))
    assert_equal(1_573_286_016, normalize_local_date('2:53:36', '2019/11/9'))
    assert_equal(1_573_295_408, normalize_local_date('5:30:08', '2019/11/9'))
    assert_equal(1_573_309_500, normalize_local_date('9:25:00', '2019/11/9'))
    assert_equal(1_546_408_923, normalize_local_date(' 1:2:3', '19/1/2'))
    assert_equal(1_548_910_800, normalize_local_date(' 0:0:0', '2019/1/31'))
    assert_raise(ArgumentError) { normalize_local_date('00:00:00', '2019/01/32') }
  end

  def test_process_canceled_trips
    Dir.mktmpdir do |dir|
      @routes = load_data("#{dir}/routes_data", ROUTES_FILE)
      @trips = load_data("#{dir}/trips_data", TRIPS_FILE)
      @stops = load_data("#{dir}/stop_data", STOPS_FILE)
      @stop_times = load_stop_times("#{dir}/stoptimes_data", STOP_TIMES_FILE)

      content = File.read('test_data/canceled.json')
      trip_update = JSON.parse(content)
      results_array = []

      process_canceled_trip(trip_update['entity'], results_array)
      assert_equal(results_array.length, 61)

      # Arbitrary element to check
      assert_equal(results_array[41].get(:aggregate_id), '2408865-20191109-138')
      assert_equal(results_array[41].get(:route_id), 11_739)
      assert_equal(results_array[41].get(:trip_id), 2_408_865)
      assert_equal(results_array[41].get(:stop_id), 138)
      assert_equal(results_array[41].get(:stop_sequence), 42)
      assert_equal(results_array[41].get(:route_short_name), 'CityLink NAVY')
      assert_equal(results_array[41].get(:route_long_name), 'MONDAWMIN - DUNDALK')
      assert_equal(results_array[41].get(:route_color), '0000FF')
      assert_equal(results_array[41].get(:route_text_color), 'D2D9D3')
      assert_equal(results_array[41].get(:shape_id), '113433')
      assert_equal(results_array[41].get(:trip_headsign), 'NV MONDAWMIN METRO')
      assert_equal(results_array[41].get(:trip_short_name), nil)
      assert_equal(results_array[41].get(:direction_id), 0)
      assert_equal(results_array[41].get(:route_desc), nil)
      assert_equal(results_array[41].get(:route_type), 3)
      assert_equal(results_array[41].get(:stop_desc), nil)
      assert_equal(results_array[41].get(:stop_name), 'CAREY ST & EDMONDSON AVE nb')
      assert_equal(results_array[41].get(:stop_lat), 39.295252)
      assert_equal(results_array[41].get(:stop_lon), -76.638429)
      assert_equal(results_array[41].get(:scheduled_arrival_time), 1_573_319_342)
      assert_equal(results_array[41].get(:actual_arrival_time), 0)
      assert_equal(results_array[41].get(:actual_arrival_time_dow), 0)
      assert_equal(results_array[41].get(:actual_arrival_time_hour), 0)
      assert_equal(results_array[41].get(:arrival_time_diff), 0)
      assert_equal(results_array[41].get(:shape_dist_traveled), 13.5846)
      assert_equal(results_array[41].get(:schedule_relationship), CANCELED)
    end
  end

  def test_process_scheduled_trips
    Dir.mktmpdir do |dir|
      @routes = load_data("#{dir}/routes_data", ROUTES_FILE)
      @trips = load_data("#{dir}/trips_data", TRIPS_FILE)
      @stops = load_data("#{dir}/stop_data", STOPS_FILE)
      @stop_times = load_stop_times("#{dir}/stoptimes_data", STOP_TIMES_FILE)

      content = File.read('test_data/scheduled.json')
      entity = JSON.parse(content)
      results_array = []

      process_scheduled_trips(entity['entity'], results_array)
      assert_equal(results_array.length, 59)

      # Arbitrary element to check
      assert_equal(results_array[41].get(:aggregate_id), '2393125-20191109-5903')
      assert_equal(results_array[41].get(:route_id), 11_652)
      assert_equal(results_array[41].get(:trip_id), 2_393_125)
      assert_equal(results_array[41].get(:stop_id), 5903)
      assert_equal(results_array[41].get(:stop_sequence), 42)
      assert_equal(results_array[41].get(:route_short_name), '53')
      assert_equal(results_array[41].get(:route_long_name), 'STATE CENTER - TOWSON')
      assert_equal(results_array[41].get(:route_color), '879A8C')
      assert_equal(results_array[41].get(:route_text_color), 'FFFFFF')
      assert_equal(results_array[41].get(:shape_id), '112912')
      assert_equal(results_array[41].get(:trip_headsign), '53 SHEPPARD PRATT')
      assert_equal(results_array[41].get(:trip_short_name), nil)
      assert_equal(results_array[41].get(:direction_id), 1)
      assert_equal(results_array[41].get(:route_desc), nil)
      assert_equal(results_array[41].get(:route_type), 3)
      assert_equal(results_array[41].get(:stop_desc), nil)
      assert_equal(results_array[41].get(:stop_name), 'THE ALAMEDA & NORTHWOOD DR fs nb')
      assert_equal(results_array[41].get(:stop_lat), 39.356329)
      assert_equal(results_array[41].get(:stop_lon), -76.596025)
      assert_equal(results_array[41].get(:scheduled_arrival_time), 1_573_325_260)
      assert_equal(results_array[41].get(:actual_arrival_time), 1_573_325_292)
      assert_equal(results_array[41].get(:actual_arrival_time_dow), 6)
      assert_equal(results_array[41].get(:actual_arrival_time_hour), 13)
      assert_equal(results_array[41].get(:arrival_time_diff), 32)
      assert_equal(results_array[41].get(:shape_dist_traveled), 8.9965)
      assert_equal(results_array[41].get(:schedule_relationship), SCHEDULED)
    end
  end

  def test_find_last_stop
    btd = VALIDATION_DATA['bus_trip_data'][2_395_665]
    assert_equal([nil, nil], find_last_stop(btd, 0))
    assert_equal([nil, nil], find_last_stop(btd, 38))
    assert_equal([nil, nil], find_last_stop(btd, 39))
    assert_equal([14.8274, 1_573_414_737], find_last_stop(btd, 40))
    assert_equal([16.6596, 1_573_414_879], find_last_stop(btd, 41))
    assert_equal([17.0002, 1_573_414_905], find_last_stop(btd, 42))
    assert_equal([19.6611, 1_573_415_137], find_last_stop(btd, 43))
    assert_equal([19.6611, 1_573_415_137], find_last_stop(btd, 50))
    assert_equal([19.6611, 1_573_415_137], find_last_stop(btd, 100))
  end

  def test_postprocess_data
    # Create test data with the last few stops to use
    @bus_trip_data = VALIDATION_DATA['bus_trip_data']
    distance_delta = 0.1598
    time_delta = 100

    # Make up a 43rd stop
    event = LogStash::Event.new(
      shape_dist_traveled: VALIDATION_DATA['bus_trip_data'][2_395_665][42]['distance'] + distance_delta,
      actual_arrival_time: VALIDATION_DATA['bus_trip_data'][2_395_665][42]['actual_arrival_time'] + time_delta
    )

    postprocess_data(event, 2_395_665, 43)

    assert_equal(event.get(:shape_dist_traveled_since_prev).round(4), distance_delta)
    assert_equal(event.get(:time_since_last_stop), time_delta)
    assert_equal(event.get(:segment_speed).round(4), distance_delta * 3600 / time_delta)
  end
end
