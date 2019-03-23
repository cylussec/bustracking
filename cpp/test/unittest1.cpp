#include "stdafx.h"
#include "CppUnitTest.h"
#include "..\bustracking\swiftly.h"

using namespace Microsoft::VisualStudio::CppUnitTestFramework;

namespace test
{		
	TEST_CLASS(UnitTest1)
	{
	public:
		TEST_METHOD(SwiftlyAgencyInfo)
		{
			std::string apikey("b20d9bc117b565f7aafdf4819668996c");
			std::string agencykey("mta-maryland");
			Swiftly::RestInterface swiftly("api.goswift.ly", "443", apikey, agencykey);
			http::response<http::dynamic_body> res;
			swiftly.agency_info(res);
			std::string compvalue("testvalue");
			//Assert::AreEqual(res.body(), compvalue);
		}


		TEST_METHOD(SwiftlyAgencyRoutes)
		{
			std::string apikey("b20d9bc117b565f7aafdf4819668996c");
			std::string agencykey("mta-maryland");
			Swiftly::RestInterface swiftly("api.goswift.ly", "443", apikey, agencykey);
			http::response<http::dynamic_body> res;
			swiftly.agency_routes(res);
			std::string compvalue("testvalue");
			//Assert::AreEqual(res[0], compvalue);
		}

		TEST_METHOD(SwiftlyPredictions)
		{
			std::string apikey("b20d9bc117b565f7aafdf4819668996c");
			std::string agencykey("mta-maryland");
			Swiftly::RestInterface swiftly("api.goswift.ly", "443", apikey, agencykey);
			http::response<http::dynamic_body> res;
			swiftly.predictions(res);
			std::string compvalue("testvalue");
			//Assert::AreEqual(res[0], compvalue);
		}

		TEST_METHOD(SwiftlyVehicles)
		{
			std::string apikey("b20d9bc117b565f7aafdf4819668996c");
			std::string agencykey("mta-maryland");
			Swiftly::RestInterface swiftly("api.goswift.ly", "443", apikey, agencykey);
			http::response<http::dynamic_body> res;
			swiftly.vehicles(res);
			std::string compvalue("testvalue");
			//Assert::AreEqual(res[0], compvalue);
		}

		TEST_METHOD(SwiftlyLocationPredictions)
		{
			std::string apikey("b20d9bc117b565f7aafdf4819668996c");
			std::string agencykey("mta-maryland");
			Swiftly::RestInterface swiftly("api.goswift.ly", "443", apikey, agencykey);
			http::response<http::dynamic_body> res;
			swiftly.predictions_near_location(res);
			std::string compvalue("testvalue");
			//Assert::AreEqual(res[0], compvalue);
		}

		TEST_METHOD(SwiftlyTripUpdates)
		{
			std::string apikey("b20d9bc117b565f7aafdf4819668996c");
			std::string agencykey("mta-maryland");
			Swiftly::RestInterface swiftly("api.goswift.ly", "443", apikey, agencykey);
			http::response<http::dynamic_body> res;
			swiftly.gtfs_rt_trip_updates(res);
			std::string compvalue("testvalue");
			//Assert::AreEqual(res[0], compvalue);
		}

		TEST_METHOD(SwiftlyVehiclePositions)
		{
			std::string apikey("b20d9bc117b565f7aafdf4819668996c");
			std::string agencykey("mta-maryland");
			Swiftly::RestInterface swiftly("api.goswift.ly", "443", apikey, agencykey);
			http::response<http::dynamic_body> res;
			swiftly.gtfs_rt_vehicle_positions(res);
			std::string compvalue("testvalue");
			//Assert::AreEqual(res[0], compvalue);
		}

	};
}