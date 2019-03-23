#pragma once
#include <map>
#include <string>
#include <boost/beast/core.hpp>
#include <boost/beast/http.hpp>
#include <boost/beast/version.hpp>
#include <boost/asio/connect.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/ssl/error.hpp>
#include <boost/asio/ssl/stream.hpp>
#include <cstdlib>
#include <iostream>
#include <string>
#include <map>

namespace beast = boost::beast; // from <boost/beast.hpp>
namespace http = beast::http;   // from <boost/beast/http.hpp>
namespace net = boost::asio;    // from <boost/asio.hpp>
namespace ssl = net::ssl;       // from <boost/asio/ssl.hpp>
using tcp = net::ip::tcp;       // from <boost/asio/ip/tcp.hpp>

namespace Swiftly
{
	class RestInterface
	{
	public:
		RestInterface(const char* _host, const char* _port, std::string _apikey, std::string _agencyid);
		~RestInterface();
		int test(http::response<http::dynamic_body>& res);
		int agency_info(http::response<http::dynamic_body>& res);
		int agency_routes(http::response<http::dynamic_body>& res);
		int predictions(http::response<http::dynamic_body>& res);
		int vehicles(http::response<http::dynamic_body>& res);
		int predictions_near_location(http::response<http::dynamic_body>& res);
		int gtfs_rt_trip_updates(http::response<http::dynamic_body>& res);
		int gtfs_rt_vehicle_positions(http::response<http::dynamic_body>& res);
	private:
		const char* host;
		std::string apikey;
		std::string agencyid;
		const char* port;
		int version; 
		int getrestcall(http::response<http::dynamic_body>& res, std::string target);
		//std::string buildquerystring(std::map< elements);

	};

};