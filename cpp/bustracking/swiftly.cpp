#include "stdafx.h"

#include "rapidjson/document.h"
#include "results.h"
#include "swiftly.h"

Swiftly::RestInterface::RestInterface(const char* _host, const char* _port, std::string _apikey, std::string _agencyid) :
	host(_host),
	port(_port),
	apikey(_apikey),
	agencyid(_agencyid)
{
	version = 11;
}

Swiftly::RestInterface::~RestInterface()
{

}

int Swiftly::RestInterface::test(http::response<http::dynamic_body>& res)
{
	return getrestcall(res, std::string("/test-key"));
}

int Swiftly::RestInterface::agency_info(http::response<http::dynamic_body>& res)
{
	std::string target = "/info/" + agencyid;

	if (EXIT_FAILURE == getrestcall(res, target)) {
		return EXIT_FAILURE;
	}
	
	rapidjson::Document document;
	document.Parse(boost::beast::buffers_to_string(res.body().data()).c_str());
	assert(document.HasMember("success"));

	SwiftlyResult<AgencyInfo> ai;
	ai.agencykey = document["data"]["name"].GetString();
	ai.success = document["success"].GetBool();
	ai.route = document["route"].GetString();
	ai.data.url = document["data"]["url"].GetString();
	ai.data.timezone = document["data"]["timezone"].GetString();
	ai.data.name = document["data"]["agencyKey"].GetString();
	ai.data.extent.maxLat = document["data"]["extent"]["maxLat"].GetFloat();
	ai.data.extent.maxLong = document["data"]["extent"]["maxLon"].GetFloat();
	ai.data.extent.minLat = document["data"]["extent"]["minLat"].GetFloat();
	ai.data.extent.minLong = document["data"]["extent"]["minLon"].GetFloat();

}

int Swiftly::RestInterface::agency_routes(http::response<http::dynamic_body>& res)
{
	std::string target = "/info/" + agencyid + "/routes";

	if (EXIT_FAILURE == getrestcall(res, target)) {
		return EXIT_FAILURE;
	}
	return 0;
}

int Swiftly::RestInterface::predictions(http::response<http::dynamic_body>& res)
{
	return 0;
}

int Swiftly::RestInterface::vehicles(http::response<http::dynamic_body>& res)
{
	return 0;
}

int Swiftly::RestInterface::predictions_near_location(http::response<http::dynamic_body>& res)
{
	return 0;
}

int Swiftly::RestInterface::gtfs_rt_trip_updates(http::response<http::dynamic_body>& res)
{
	return 0;
}

int Swiftly::RestInterface::gtfs_rt_vehicle_positions(http::response<http::dynamic_body>& res)
{
	return 0;
}

int Swiftly::RestInterface::getrestcall(http::response<http::dynamic_body>& res, std::string target)
{
	try
	{

		// The io_context is required for all I/O
		boost::asio::io_context ioc;

		// The SSL context is required, and holds certificates
		ssl::context ctx{ ssl::context::sslv23_client };


		// This holds the root certificate used for verification
		//load_root_certificates(ctx);

		// Verify the remote server's certificate
		ctx.set_verify_mode(boost::asio::ssl::verify_none);

		// These objects perform our I/O
		tcp::resolver resolver{ ioc };
		ssl::stream<tcp::socket> stream{ ioc, ctx };

		// Set SNI Hostname (many hosts need this to handshake successfully)
		if (!SSL_set_tlsext_host_name(stream.native_handle(), (void*)host))
		{
			boost::system::error_code ec{ static_cast<int>(::ERR_get_error()), boost::asio::error::get_ssl_category() };
			throw boost::system::system_error{ ec };
		}

		// Look up the domain name
		auto const results = resolver.resolve(host, port);

		// Make the connection on the IP address we get from a lookup
		boost::asio::connect(stream.next_layer(), results.begin(), results.end());

		// Perform the SSL handshake
		stream.handshake(ssl::stream_base::client);

		// Set up an HTTP GET request message
		http::request<http::dynamic_body> req{ http::verb::get, target, version };
		req.set(http::field::host, host);
		req.set(http::field::user_agent, BOOST_BEAST_VERSION_STRING);
		req.set(http::field::authorization, apikey);

		// Send the HTTP request to the remote host
		http::write(stream, req);

		// This buffer is used for reading and must be persisted
		boost::beast::flat_buffer buffer;

		// Receive the HTTP response
		http::read(stream, buffer, res);

		// Write the message to standard out
		std::cout << res << std::endl;

		// Gracefully close the stream
		boost::system::error_code ec;
		stream.shutdown(ec);
		if (ec == boost::asio::error::eof)
		{
			// Rationale:
			// http://stackoverflow.com/questions/25587403/boost-asio-ssl-async-shutdown-always-finishes-with-an-error
			ec.assign(0, ec.category());
		}
		if (ec)
			throw boost::system::system_error{ ec };

		// If we get here then the connection is closed gracefully
	}
	catch (std::exception const& e)
	{
		std::cerr << "Error: " << e.what() << std::endl;
		return EXIT_FAILURE;
	}
	return EXIT_SUCCESS;
}
