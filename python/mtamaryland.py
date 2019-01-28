#!/usr/bin/python3

import json
import time
from pprint import pprint

from db import Database
from swiftly import Swiftly

class MTAMaryland(Swiftly):
    def __init__(self):
        super(MTAMaryland, self).__init__(api_key='b20d9bc117b565f7aafdf4819668996c', agency_key='mta-maryland')
        #self.db = Database()
        #self.db.create_table

    def get_trip_status(self):
        trip_updates = mtam.gtfs_rt_trip_updates()

        for entity in trip_updates.entity:
            print(entity)
            trip = entity.trip_update.trip
            self.db.insert_routestatus(entity.trip_update.timestamp, entity.trip_update.trip.trip_id, entity.trip_update.trip.schedule_relationship)
            if trip.schedule_relationship not in [trip.CANCELED, trip.SCHEDULED]:
                print("Trip type {}".format(trip.schedule_relationship))

if __name__ == '__main__':
    mtam = MTAMaryland()
    pprint(mtam.test())
    #mtam.get_trip_status()
    #pprint(mtam.predictions(2053))
    ##pprint(mtam.agency_routes(10989, verbose='true'))
    #pprint(mtam.vehicles(10989, verbose='true'))
    #pprint(mtam.predictions(2053))
    #pprint(mtam.predictions_near_location(39.287703, -76.593698))

    #pprint(mtam.gtfs_rt_vehicle_positions(format='human'))
