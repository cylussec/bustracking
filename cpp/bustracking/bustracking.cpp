/*#include <boost/beast/core.hpp>
#include <boost/beast/http.hpp>
#include <boost/beast/version.hpp>
#include <boost/asio/connect.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <cstdlib>
#include <iostream>
#include <string>
#include "swiftly.h"
#include <map>

using tcp = boost::asio::ip::tcp;       // from <boost/asio/ip/tcp.hpp>
namespace http = boost::beast::http;    // from <boost/beast/http.hpp>

										// Performs an HTTP GET and prints the response
int main(int argc, char** argv)
{
	std::map<std::string, std::string> dict;
	std::string host("api.goswift.ly");
	std::string apikey("b20d9bc117b565f7aafdf4819668996c");
	Swiftly::RestInterface swiftly(host, "443", apikey);
	swiftly.test(dict);

}*/

//
// Copyright (c) 2016-2017 Vinnie Falco (vinnie dot falco at gmail dot com)
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
// Official repository: https://github.com/boostorg/beast
//

//------------------------------------------------------------------------------
//
// Example: HTTP SSL client, synchronous
//
//------------------------------------------------------------------------------

#include "rootcertificate.h"
//
// Copyright (c) 2016-2017 Vinnie Falco (vinnie dot falco at gmail dot com)
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
// Official repository: https://github.com/boostorg/beast
//

//------------------------------------------------------------------------------
//
// Example: HTTP SSL client, synchronous
//
//------------------------------------------------------------------------------

#include <boost/beast/core.hpp>
#include <boost/beast/http.hpp>
#include <boost/beast/version.hpp>
#include <boost/asio/connect.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/ssl/error.hpp>
#include <boost/asio/ssl/stream.hpp>
#include <boost/asio/buffers_iterator.hpp>
#include <boost/asio/buffers_iterator.hpp>
#include <cstdlib>
#include <iostream>
#include <string>
#include <iomanip>
#include "swiftly.h"

using tcp = boost::asio::ip::tcp;       // from <boost/asio/ip/tcp.hpp>
namespace ssl = boost::asio::ssl;       // from <boost/asio/ssl.hpp>
namespace http = boost::beast::http;    // from <boost/beast/http.hpp>

// Performs an HTTP GET and prints the response
int main(int argc, char** argv)
{
	http::response<http::dynamic_body> res;
	Swiftly::RestInterface ri("api.goswift.ly", "443", std::string("b20d9bc117b565f7aafdf4819668996c"));
	ri.test(res);
	std::string body{ boost::asio::buffers_begin(res.body().data()),
				   boost::asio::buffers_end(res.body().data()) };

	std::cout << "Body: " << std::quoted(body) << "\n";
}