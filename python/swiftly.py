import ast
import http.client
import json

from google.transit import gtfs_realtime_pb2

class Swiftly:
    def __init__(self, api_key, agency_key):
        self.conn = http.client.HTTPSConnection("api.goswift.ly")
        self.headers = { 'authorization': api_key }
        self.agency_key = agency_key

    def test(self):
        return self._get_response("/test-key")

    def agency_info(self):
        return self._get_response("/info/{}".format(self.agency_key))

    def agency_routes(self, route=None, verbose='false'):
        args = {}
        if route:
            args['route'] = route
        if verbose not in ['true', 'false']:
            raise ValueError 
        url = self._build_query_string("/info/{}/routes".format(self.agency_key), args)

        return self._get_response(url)

    def predictions(self, stop, route=None, number=None):
        args = {}
        args['stop'] = stop
        if route:
            args['route'] = route
        if number:
            args['number'] = number

        url = self._build_query_string("/real-time/{}/predictions".format(self.agency_key), args)

        return self._get_response(url)

    def vehicles(self, route=None, unassigned='false', verbose='false'):
        args = {}
        if route:
            args['route'] = route
        if unassigned not in ['true', 'false']:
            raise ValueError 
        if verbose not in ['true', 'false']:
            raise ValueError 

        url = self._build_query_string("/real-time/{}/vehicles".format(self.agency_key), args)

        return self._get_response(url)

    def predictions_near_location(self, lat, long, number=None, meters=None):
        args = {}
        args['lat'] = lat
        args['long'] = long
        if number:
            args['number'] = number
        if meters:
            args['meters'] = meters

        url = self._build_query_string("/real-time/{}/predictions-near-location".format(self.agency_key), args)

        return self._get_response(url)

    def gtfs_rt_trip_updates(self, format='None'):
        args = {'format':format} if format else {}
        url = self._build_query_string("/real-time/{}/gtfs-rt-trip-updates".format(self.agency_key), args)

        return self._get_gtfs_response(url)

    def gtfs_rt_vehicle_positions(self, format='None'):
        args = {'format':format} if format else {}
        url = self._build_query_string("/real-time/{}/gtfs-rt-vehicle-positions".format(self.agency_key), args)

        return self._get_gtfs_response(url)

    def _build_query_string(self, url, parameters):
        first = True
        for key, value in parameters.items():
            url += "?" if first else "&"
            url += "{}={}".format(key, value)
            first = False

        print(url)

        return url

    def _get_response(self, url, response_type='string'):
        import pdb;pdb.set_trace()
        self.conn.request("GET", url, headers=self.headers)

        res = self.conn.getresponse()
        data = res.read()
        return self._string_to_dict(data.decode("utf-8"))

    def _get_gtfs_response(self, url):
        self.conn.request("GET", url, headers=self.headers)

        res = self.conn.getresponse()
        feed = gtfs_realtime_pb2.FeedMessage()
        feed.ParseFromString(res.read())
        return feed

    @staticmethod
    def _string_to_dict(strdict):
        json_acceptable_string = strdict.replace("'", "\"")
        return json.loads(json_acceptable_string)