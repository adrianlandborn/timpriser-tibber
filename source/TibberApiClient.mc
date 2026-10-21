import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

class TibberApiClient {
    private const TIBBER_API_URL = "https://api.tibber.com/v1-beta/gql";

    private var _responseCallback;
    private var _requestType; // "current" or "daily"

    function initialize() {
        _responseCallback = null;
        _requestType = null;
    }

    function getCurrentPrice(callback) {
        // For now, return mock data to test the widget functionality
        var mockData = {
            "current_price" => "125",
            "current_time" => "15:30",
            "level" => "NORMAL",
            "currency" => "SEK"
        };

        callback.invoke(mockData);
        return;

        // Original API call (commented out for testing)
        /*
        var query = {
            "query" => "{ viewer { homes { currentSubscription { priceInfo { current { total level currency } } } } } }"
        };

        _requestType = "current";
        makeRequest(query, callback);
        */
    }

    function getDailyPrices(callback) {
        // For now, return mock daily prices to test the widget functionality
        var mockDailyPrices = [
            {"hour" => "00:00", "price" => "89"},
            {"hour" => "01:00", "price" => "87"},
            {"hour" => "02:00", "price" => "85"},
            {"hour" => "03:00", "price" => "84"},
            {"hour" => "04:00", "price" => "86"},
            {"hour" => "05:00", "price" => "92"},
            {"hour" => "06:00", "price" => "105"},
            {"hour" => "07:00", "price" => "118"},
            {"hour" => "08:00", "price" => "125"},
            {"hour" => "09:00", "price" => "115"},
            {"hour" => "10:00", "price" => "108"},
            {"hour" => "11:00", "price" => "102"},
            {"hour" => "12:00", "price" => "98"},
            {"hour" => "13:00", "price" => "95"},
            {"hour" => "14:00", "price" => "97"},
            {"hour" => "15:00", "price" => "105"},
            {"hour" => "16:00", "price" => "125"},
            {"hour" => "17:00", "price" => "145"},
            {"hour" => "18:00", "price" => "165"},
            {"hour" => "19:00", "price" => "155"},
            {"hour" => "20:00", "price" => "145"},
            {"hour" => "21:00", "price" => "125"},
            {"hour" => "22:00", "price" => "115"},
            {"hour" => "23:00", "price" => "95"}
        ];

        callback.invoke(mockDailyPrices);
        return;

        // Original API call (commented out for testing)
        /*
        var query = {
            "query" => "{ viewer { homes { currentSubscription { priceInfo { today { total startsAt level } } } } } }"
        };

        _requestType = "daily";
        makeRequest(query, callback);
        */
    }

    private function makeRequest(query, callback) {
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Authorization" => "Bearer " + TibberSecrets.getApiToken(),
                "Content-Type" => "application/json"
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(
            TIBBER_API_URL,
            query,
            options,
            method(:onApiResponse)
        );

        _responseCallback = callback;
    }

    function onApiResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (_responseCallback == null) {
            return;
        }

        // Log response for debugging
        System.println("Response code: " + responseCode.toString());
        if (data instanceof Dictionary) {
            System.println("Received dictionary data");
        } else if (data instanceof String) {
            System.println("Received string data: " + (data as String));
        } else {
            System.println("Received null or unknown data type");
        }

        if (responseCode == 200) {
            if (data instanceof Dictionary) {
                var parsedData;
                if (_requestType.equals("current")) {
                    parsedData = parseCurrentPriceData(data);
                } else {
                    parsedData = parseDailyPricesData(data);
                }
                _responseCallback.invoke(parsedData);
            } else {
                // Response code 200 but not a dictionary - API might have returned an error
                var errorMessage = "API returned invalid data format";
                if (data instanceof String) {
                    errorMessage = "API error: " + (data as String);
                }
                _responseCallback.invoke(errorMessage);
            }
        } else {
            var errorMessage = "HTTP " + responseCode.toString();
            if (responseCode == 401) {
                errorMessage = "Invalid API token";
            } else if (responseCode == 403) {
                errorMessage = "Access denied";
            } else if (responseCode == 404) {
                errorMessage = "API not found";
            } else if (responseCode >= 500) {
                errorMessage = "Server error";
            }

            _responseCallback.invoke(errorMessage);
        }

        _responseCallback = null;
        _requestType = null;
    }

    private function parseCurrentPriceData(data) {
        try {
            System.println("Parsing current price data...");

            var viewer = data.get("data");
            if (viewer == null) {
                System.println("No 'data' field found");
                // Check if there's an errors field
                var errors = data.get("errors");
                if (errors != null) {
                    return "API errors found";
                }
                return "No data received";
            }

            viewer = (viewer as Dictionary).get("viewer");
            if (viewer == null) {
                System.println("No 'viewer' field found");
                return "Invalid data structure";
            }

            var homes = (viewer as Dictionary).get("homes");
            if (homes == null || !(homes instanceof Array) || (homes as Array).size() == 0) {
                System.println("No homes found or empty homes array");
                return "No homes found";
            }

            var home = (homes as Array)[0];
            if (!(home instanceof Dictionary)) {
                System.println("First home is not a dictionary");
                return "Invalid home data";
            }

            var subscription = (home as Dictionary).get("currentSubscription");
            if (subscription == null) {
                System.println("No currentSubscription found");
                return "No subscription found";
            }

            var priceInfo = (subscription as Dictionary).get("priceInfo");
            if (priceInfo == null) {
                System.println("No priceInfo found");
                return "No price info found";
            }

            var current = (priceInfo as Dictionary).get("current");
            if (current == null) {
                System.println("No current price found");
                return "No current price found";
            }

            var currentDict = current as Dictionary;
            var total = currentDict.get("total");
            var level = currentDict.get("level");
            var currency = currentDict.get("currency");

            if (total == null) {
                System.println("No total price found");
                return "Invalid price data";
            }

            // Convert to öre if currency is SEK (multiply by 100)
            var price = total as Float;
            if (currency != null && currency.equals("SEK")) {
                price = price * 100;
            }

            var now = Time.now();
            var timeInfo = Time.Gregorian.info(now, Time.FORMAT_SHORT);
            var timeString = timeInfo.hour.format("%02d") + ":" + timeInfo.min.format("%02d");

            System.println("Successfully parsed price: " + price.format("%.0f"));

            return {
                "current_price" => price.format("%.0f"),
                "current_time" => timeString,
                "level" => level,
                "currency" => currency
            };

        } catch (ex) {
            System.println("Exception in parseCurrentPriceData: " + ex.getErrorMessage());
            return "Parse error: " + ex.getErrorMessage();
        }
    }

    private function parseDailyPricesData(data) {
        try {
            var viewer = data.get("data");
            if (viewer == null) {
                return "No data received";
            }

            viewer = (viewer as Dictionary).get("viewer");
            if (viewer == null) {
                return "Invalid data structure";
            }

            var homes = (viewer as Dictionary).get("homes");
            if (homes == null || !(homes instanceof Array) || (homes as Array).size() == 0) {
                return "No homes found";
            }

            var home = (homes as Array)[0];
            if (!(home instanceof Dictionary)) {
                return "Invalid home data";
            }

            var subscription = (home as Dictionary).get("currentSubscription");
            if (subscription == null) {
                return "No subscription found";
            }

            var priceInfo = (subscription as Dictionary).get("priceInfo");
            if (priceInfo == null) {
                return "No price info found";
            }

            var today = (priceInfo as Dictionary).get("today");
            if (today == null || !(today instanceof Array)) {
                return "No daily prices found";
            }

            var dailyPrices = [];
            var todayArray = today as Array;

            for (var i = 0; i < todayArray.size(); i++) {
                var hourData = todayArray[i];
                if (hourData instanceof Dictionary) {
                    var hourDict = hourData as Dictionary;
                    var total = hourDict.get("total");
                    var startsAt = hourDict.get("startsAt");

                    if (total != null && startsAt != null) {
                        // Convert to öre for SEK
                        var price = (total as Float) * 100;

                        // Extract hour from startsAt (format: "2024-10-19T14:00:00.000+02:00")
                        var timeStr = startsAt as String;
                        var hour = "??";
                        if (timeStr.length() >= 13) {
                            hour = timeStr.substring(11, 13);
                        }

                        dailyPrices.add({
                            "hour" => hour + ":00",
                            "price" => price.format("%.0f")
                        });
                    }
                }
            }

            return dailyPrices;

        } catch (ex) {
            return "Error parsing daily prices";
        }
    }
}