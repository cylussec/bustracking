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
			Swiftly::RestInterface swiftly("api.goswift.ly", "443", apikey);
			http::response<http::dynamic_body> res;
			swiftly.agency_info(res);
			std::string compvalue("testvalue");
			Assert::AreEqual(res.body()., compvalue);
		}


		TEST_METHOD(SwiftlyAgencyRoutes)
		{
			std::string apikey("b20d9bc117b565f7aafdf4819668996c");
			Swiftly::RestInterface swiftly("api.goswift.ly", "443", apikey);
			std::map<std::string, std::string> results;
			swiftly.agency_routes(results);
			std::string compvalue("testvalue");
			Assert::AreEqual(results[0], compvalue);
		}

		TEST_METHOD(SwiftlyPredictions)
		{
			std::string apikey("b20d9bc117b565f7aafdf4819668996c");
			Swiftly::RestInterface swiftly("api.goswift.ly", "443", apikey);
			std::map<std::string, std::string> results;
			swiftly.predictions(results);
			std::string compvalue("testvalue");
			Assert::AreEqual(results[0], compvalue);
		}

		TEST_METHOD(SwiftlyVehicles)
		{
			std::string apikey("b20d9bc117b565f7aafdf4819668996c");
			Swiftly::RestInterface swiftly("api.goswift.ly", "443", apikey);
			std::map<std::string, std::string> results;
			swiftly.vehicles(results);
			std::string compvalue("testvalue");
			Assert::AreEqual(results[0], compvalue);
		}

		TEST_METHOD(SwiftlyLocationPredictions)
		{
			std::string apikey("b20d9bc117b565f7aafdf4819668996c");
			Swiftly::RestInterface swiftly("api.goswift.ly", "443", apikey);
			std::map<std::string, std::string> results;
			swiftly.predictions_near_location(results);
			std::string compvalue("testvalue");
			Assert::AreEqual(results[0], compvalue);
		}

		TEST_METHOD(SwiftlyTripUpdates)
		{
			std::string apikey("b20d9bc117b565f7aafdf4819668996c");
			Swiftly::RestInterface swiftly("api.goswift.ly", "443", apikey);
			std::map<std::string, std::string> results;
			swiftly.gtfs_rt_trip_updates(results);
			std::string compvalue("testvalue");
			Assert::AreEqual(results[0], compvalue);
		}

		TEST_METHOD(SwiftlyVehiclePositions)
		{
			std::string apikey("b20d9bc117b565f7aafdf4819668996c");
			Swiftly::RestInterface swiftly("api.goswift.ly", "443", apikey);
			std::map<std::string, std::string> results;
			swiftly.gtfs_rt_vehicle_positions(results);
			std::string compvalue("testvalue");
			Assert::AreEqual(results[0], compvalue);
		}

	};
}