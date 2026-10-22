import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

class TibberApiClient {
    private const TIBBER_API_URL = "https://api.tibber.com/v1-beta/gql";
    private var _responseCallback;
    private var _requestType; // "current" or "daily"
    private var _requestResolution;

    function initialize() {
        _responseCallback = null;
        _requestType = null;
        _requestResolution = null;
    }

    function getCurrentPrice(callback, resolution) {
        if (!isSupportedResolution(resolution)) {
            callback.invoke("Unsupported Tibber price resolution");
            return;
        }

        var query = {
            "query" => "{ viewer { homes { currentSubscription { priceInfo(resolution: " + resolution + ") { current { total level currency startsAt } } } } } }"
        };
        makeRequest(query, "current", resolution, callback);
    }

    function getDailyPrices(callback, resolution) {
        if (!isSupportedResolution(resolution)) {
            callback.invoke("Unsupported Tibber price resolution");
            return;
        }

        var query = {
            "query" => "{ viewer { homes { currentSubscription { priceInfo(resolution: " + resolution + ") { today { total startsAt level currency } } } } } }"
        };
        makeRequest(query, "daily", resolution, callback);
    }

    private function isSupportedResolution(resolution) {
        return resolution instanceof String && (
            (resolution as String).equals("HOURLY") ||
            (resolution as String).equals("QUARTER_HOURLY")
        );
    }

    private function getIntervalMinutes(resolution) {
        return resolution.equals("HOURLY") ? 60 : 15;
    }

    private function makeRequest(query, requestType, resolution, callback) {
        if (_responseCallback != null) {
            callback.invoke("A Tibber request is already in progress");
            return;
        }

        var token = TibberSecrets.getApiToken();
        if (token.length() == 0) {
            callback.invoke("Tibber API token is missing");
            return;
        }

        System.println("Requesting Tibber " + resolution + " prices");

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Authorization" => "Bearer " + token,
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "Accept" => "application/json",
                "User-Agent" => "Garmin Connect IQ/9.3.0 TibberWidget/1.0.0"
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        _responseCallback = callback;
        _requestType = requestType;
        _requestResolution = resolution;

        try {
            Communications.makeWebRequest(
                TIBBER_API_URL,
                query,
                options,
                method(:onApiResponse)
            );
        } catch (ex) {
            _responseCallback = null;
            _requestType = null;
            _requestResolution = null;
            callback.invoke("Unable to start Tibber API request");
        }
    }

    function onApiResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (_responseCallback == null) {
            return;
        }

        System.println("Tibber HTTP response: " + responseCode.toString());

        var callback = _responseCallback;
        var requestType = _requestType;
        var resolution = _requestResolution;
        _responseCallback = null;
        _requestType = null;
        _requestResolution = null;

        var result;
        if (responseCode == 200) {
            if (data instanceof Dictionary) {
                var graphQlError = getGraphQlError(data);
                if (graphQlError != null) {
                    result = graphQlError;
                } else if (requestType.equals("current")) {
                    result = parseCurrentPriceData(data, resolution);
                } else {
                    result = parseDailyPricesData(data, resolution);
                }
            } else {
                result = "Tibber returned an invalid response";
            }
        } else {
            result = "Tibber HTTP error " + responseCode.toString();
            if (responseCode == 401) {
                result = "Tibber rejected the API token";
            } else if (responseCode == 403) {
                result = "Tibber denied access; check the token's home scope";
            } else if (responseCode == 429) {
                result = "Tibber rate limit reached; try again later";
            } else if (responseCode < 0) {
                result = "Unable to reach Tibber; check the watch connection";
            }
        }

        if (result instanceof Dictionary && requestType.equals("current")) {
            System.println("Tibber " + resolution + " current price parsed successfully");
        } else if (result instanceof Dictionary && requestType.equals("daily")) {
            System.println("Tibber " + resolution + " daily prices parsed successfully");
        } else {
            System.println("Tibber GraphQL response returned an error");
        }

        callback.invoke(result);
    }

    private function getGraphQlError(data as Dictionary) {
        var errors = data.get("errors");
        if (errors instanceof Array && (errors as Array).size() > 0) {
            var firstError = (errors as Array)[0];
            if (firstError instanceof Dictionary) {
                var message = (firstError as Dictionary).get("message");
                if (message instanceof String) {
                    return "Tibber query failed: " + (message as String);
                }
            }
            return "Tibber query failed";
        }
        return null;
    }

    private function parseCurrentPriceData(data, resolution) {
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

            var current = (priceInfo as Dictionary).get("current");
            if (current == null) {
                return "No current price found";
            }

            var currentDict = current as Dictionary;
            var total = currentDict.get("total");
            var level = currentDict.get("level");
            var currency = currentDict.get("currency");
            var startsAt = currentDict.get("startsAt");

            if (total == null) {
                return "Invalid price data";
            }

            var price = total as Float;
            if (currency != null && currency.equals("SEK")) {
                price = price * 100;
            }

            var timeString = getCurrentTimeString(startsAt);

            return {
                "current_price" => price.format("%.0f"),
                "current_time" => timeString,
                "level" => level,
                "currency" => currency,
                "starts_at" => startsAt,
                "resolution" => resolution,
                "interval_minutes" => getIntervalMinutes(resolution)
            };

        } catch (ex) {
            System.println("Unable to parse Tibber current price response");
            return "Invalid Tibber price response";
        }
    }

    private function getCurrentTimeString(startsAt) {
        if (startsAt instanceof String && (startsAt as String).length() >= 16) {
            return (startsAt as String).substring(11, 16);
        }

        var timeInfo = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return timeInfo.hour.format("%02d") + ":" + timeInfo.min.format("%02d");
    }

    private function parseDailyPricesData(data, resolution) {
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

            var intervals = [];
            var todayArray = today as Array;

            for (var i = 0; i < todayArray.size(); i++) {
                var hourData = todayArray[i];
                if (hourData instanceof Dictionary) {
                    var hourDict = hourData as Dictionary;
                    var total = hourDict.get("total");
                    var startsAt = hourDict.get("startsAt");
                    var currency = hourDict.get("currency");
                    var level = hourDict.get("level");

                    if (total != null && startsAt != null) {
                        var timeStr = startsAt as String;
                        var startMinute = getMinuteOfDay(timeStr);
                        if (startMinute == null) {
                            continue;
                        }

                        var price = total as Float;
                        if (currency != null && currency.equals("SEK")) {
                            price = price * 100;
                        }

                        intervals.add({
                            "starts_at" => timeStr,
                            "start_time" => getCurrentTimeString(timeStr),
                            "price" => price.format("%.0f"),
                            "price_value" => price,
                            "start_minute_of_day" => startMinute,
                            "currency" => currency,
                            "level" => level,
                            "resolution" => resolution,
                            "duration_minutes" => getIntervalMinutes(resolution)
                        });
                    }
                }
            }

            return {
                "resolution" => resolution,
                "resolution_minutes" => getIntervalMinutes(resolution),
                "intervals" => intervals
            };

        } catch (ex) {
            return "Error parsing daily prices";
        }
    }

    private function getMinuteOfDay(startsAt) {
        if (!(startsAt instanceof String) || (startsAt as String).length() < 16) {
            return null;
        }

        var timeString = startsAt as String;
        var hour = timeString.substring(11, 13);
        var minute = timeString.substring(14, 16);
        if (hour == null || minute == null) {
            return null;
        }

        var hourNumber = (hour as String).toNumber();
        var minuteNumber = (minute as String).toNumber();
        if (hourNumber == null || minuteNumber == null) {
            return null;
        }

        return hourNumber * 60 + minuteNumber;
    }
}