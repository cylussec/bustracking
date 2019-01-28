#include "stdafx.h"

#include "swiftly.h"




Swiftly::RestInterface::RestInterface(const char* xhost, const char* xport, std::string xapikey)
{
	//http::server instance;
	host = xhost;
	port = xport;
	apikey = xapikey;
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
	///info/{}
	std::string target("/info/");
	target.append(apikey);
	return getrestcall(res, target);
}

int Swiftly::RestInterface::agency_routes(http::response<http::dynamic_body>& res)
{
	///info/{}/routes
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
		http::request<http::string_body> req{ http::verb::get, target, version };
		req.set(http::field::host, host);
		req.set(http::field::user_agent, BOOST_BEAST_VERSION_STRING);
		req.set(http::field::authorization, apikey);

		// Send the HTTP request to the remote host
		http::write(stream, req);

		// This buffer is used for reading and must be persisted
		boost::beast::flat_buffer buffer;

		// Declare a container to hold the response
		http::response<http::dynamic_body> res;

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
