#pragma once

#include <string>
#include <vector>

template <class T>
class SwiftlyResult
{
	/*
	:param agencykey (std::string) The agency key used in the Swiftly dashboard. This is the parameter that follows “dashboard.goswift.ly/” in the Swiftly dashboard url.
	:param route (std::string) The api-route or URL pattern that the user entered.
	:param success (bool) true if the API call was successful.
	:param data (T) type specific to the API call
	*/
public:
	std::string agencykey;
	std::string route;
	bool success;
	T data;
};

struct LocationBox
{
	/*
	The minimum and maximum latitude and longitude coordinates of a bounding box that contains the route.

	:param maxLat (float) Maximum latitude of the bounding box that encompasses the route shape.
	:param maxLong (float) Maximum longitude of the bounding box that encompasses the route shape.
	:param minLat (float) Maximum latitude of the bounding box that encompasses the route shape.
	:param minLong (float) Minimum longitude of the bounding box that encompasses the route shape.
	*/

	float maxLat;
	float maxLong;
	float minLat;
	float minLong;
};

struct LocationPoint
{
	/*
	The latitude and longitude coordinates for a location

	:param lat (float) Latitude coordinate for a location
	:param lon (float) Longitude coordinate for a location
	*/
	float lat;
	float lon;
};

struct AgencyInfo
{
	/*
	Information pulled in an Agency Info query

	:param extent (LocationBox) The minimum and maximum latitude and longitude coordinates of a bounding box that contains the route.
	:param name (std::string) The agency name. This matches the `agency_name` field in the agency.txt GTFS file
	:param timezone (std::string) The agency timezone. This matches the `agency_timezone` field in the agency.txt GTFS file.
	:param url (std::string) The agency URL. this matches the `agency_url` field in the agency.txt GTFS file.
	*/
	LocationBox extent;
	std::string name;
	std::string timezone;
	std::string url;
};

enum RouteType { lightrail, subway, heavyrail };

struct RouteShape
{
	std::string tripPatternId;
	std::string shapeId;
	std::string directionId;
	std::string headsign;
	LocationPoint loc;
};

struct TransitStop
{
	std::string id;
	float lat;
	float lon;
	std::string name;
	int code;
};

struct RouteDirections
{
	std::string id;
	std::string title;
	std::vector<TransitStop> stops;
	std::vector<std::string> headsigns;
};

struct AgencyRoutes
{
	/*
	:param id (str) Matches the `route_id` from GTFS. This is an ID that uniquely identifies the route.
	*/
	std::string id;
	std::string name;
	std::string shortName;
	std::string longName;
	RouteType type;
	std::vector <RouteDirections> directions;
	std::vector<RouteShape> shapes;
	LocationBox extent;
};