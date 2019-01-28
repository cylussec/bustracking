import http.client

conn = http.client.HTTPSConnection("api.goswift.ly")

#b20d9bc117b565f7aafdf4819668996c

class Swiftly:
    def __init__(self, api_key, agency_key):
        self.headers = { 'authorization': api_key }
        self.agency_key = agency_key

    def test(self):
        return self._get_response("/test-key")

    def agency_info(self):
        return self._get_response("/info/{}".format(self.agency_key))

    def agency_routes(self, route=None, verbose=None):
        args = {}
        if route:
            args['route'] = route
        if verbose is not None:
            args['verbose'] = 'true' if verbose else 'false'

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

    def vehicles(self, route=None, unassigned=None, verbose=None):
        args = {}
        if route:
            args['route'] = route
        if unassigned:
            args['unassigned'] = unassigned
        if verbose is not None:
            args['verbose'] = 'true' if verbose else 'false'

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

    def gtfs_rt_trip_updates(self, format):
        args = {'format':format}
        url = self._build_query_string("/real-time/{}/gtfs-rt-trip-updates".format(self.agency_key), args)

        return self._get_response(url)

    def gtfs_rt_vehicle_positions(self, format):
        args = {'format':format}
        url = self._build_query_string("/real-time/{}/gtfs-rt-vehicle-positions".format(self.agency_key), args)

        return self._get_response(url)

    def _build_query_string(self, url, parameters):
        first = True
        for key, value in parameters.items():
            url += "?" if first else "&"
            url += "{}={}".format(key, value)
            first = False

        print(url)

        return url

    def _get_response(self, url):
        conn.request("GET", url, headers=self.headers)

        res = conn.getresponse()
        data = res.read()

        return data.decode("utf-8")