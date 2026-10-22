import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

class TibberApiClient {
    private const TIBBER_API_URL = "https://api.tibber.com/v1-beta/gql";
    private var _responseCallback;
    private var _requestType; // "current" or "daily"
    private var _requestResolution;
    private var _requestIncludeTomorrow;

    /** Initialize the HTTP request state for this client instance. */
    function initialize() {
        _responseCallback = null;
        _requestType = null;
        _requestResolution = null;
        _requestIncludeTomorrow = false;
    }

    /** Fetch the current price for the requested Tibber resolution. */
    function getCurrentPrice(responseCallback, priceResolution) {
        if (!isSupportedResolution(priceResolution)) {
            responseCallback.invoke("Unsupported Tibber price resolution");
            return;
        }

        var query = {
            "query" => "{ viewer { homes { currentSubscription { priceInfo(resolution: " + priceResolution + ") { current { total level currency startsAt } } } } } }"
        };
        makeRequest(query, "current", priceResolution, false, responseCallback);
    }

    /**
     * Fetch today's prices at the requested resolution, optionally including tomorrow.
     * The response dictionary contains timestamped intervals and a span_minutes value.
     */
    function getDailyPrices(responseCallback, priceResolution, includeTomorrow) {
        if (!isSupportedResolution(priceResolution)) {
            responseCallback.invoke("Unsupported Tibber price resolution");
            return;
        }

        var requestedPriceFields = "today { total startsAt level currency }";
        if (includeTomorrow) {
            requestedPriceFields += " tomorrow { total startsAt level currency }";
        }
        var query = {
            "query" => "{ viewer { homes { currentSubscription { priceInfo(resolution: " + priceResolution + ") { " + requestedPriceFields + " } } } } }"
        };
        makeRequest(query, "daily", priceResolution, includeTomorrow, responseCallback);
    }

    /** Return whether a resolution is supported by Tibber's PriceInfo API. */
    private function isSupportedResolution(priceResolution) {
        return priceResolution instanceof String && (
            (priceResolution as String).equals("HOURLY") ||
            (priceResolution as String).equals("QUARTER_HOURLY")
        );
    }

    /** Convert Tibber's resolution enum to its interval length in minutes. */
    private function getIntervalMinutes(priceResolution) {
        return priceResolution.equals("HOURLY") ? 60 : 15;
    }

    /** Send one authenticated GraphQL request and remember its response context. */
    private function makeRequest(graphQlRequest, requestKind, priceResolution, includeTomorrow, responseCallback) {
        if (_responseCallback != null) {
            responseCallback.invoke("A Tibber request is already in progress");
            return;
        }

        var accessToken = TibberSecrets.getApiToken();
        if (accessToken.length() == 0) {
            responseCallback.invoke("Tibber API token is missing");
            return;
        }

        System.println("Requesting Tibber " + priceResolution + " prices");

        var requestOptions = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
            "Authorization" => "Bearer " + accessToken,
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "Accept" => "application/json",
                "User-Agent" => "Garmin Connect IQ/9.3.0 TibberWidget/1.0.0"
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        _responseCallback = responseCallback;
        _requestType = requestKind;
        _requestResolution = priceResolution;
        _requestIncludeTomorrow = includeTomorrow;

        try {
            Communications.makeWebRequest(
                TIBBER_API_URL,
                graphQlRequest,
                requestOptions,
                method(:onApiResponse)
            );
        } catch (ex) {
            _responseCallback = null;
            _requestType = null;
            _requestResolution = null;
            _requestIncludeTomorrow = false;
            responseCallback.invoke("Unable to start Tibber API request");
        }
    }

    /** Route an HTTP response through the matching parser and invoke its callback. */
    function onApiResponse(responseCode as Number, responseData as Dictionary or String or Null) as Void {
        if (_responseCallback == null) {
            return;
        }

        System.println("Tibber HTTP response: " + responseCode.toString());

        var pendingCallback = _responseCallback;
        var requestKind = _requestType;
        var priceResolution = _requestResolution;
        var includeTomorrow = _requestIncludeTomorrow;
        _responseCallback = null;
        _requestType = null;
        _requestResolution = null;
        _requestIncludeTomorrow = false;

        var parsedResult;
        if (responseCode == 200) {
            if (responseData instanceof Dictionary) {
                var graphQlError = getGraphQlError(responseData as Dictionary);
                if (graphQlError != null) {
                    parsedResult = graphQlError;
                } else if (requestKind.equals("current")) {
                    parsedResult = parseCurrentPriceData(responseData as Dictionary, priceResolution);
                } else {
                    parsedResult = parseDailyPricesData(responseData as Dictionary, priceResolution, includeTomorrow);
                }
            } else {
                parsedResult = "Tibber returned an invalid response";
            }
        } else {
            parsedResult = "Tibber HTTP error " + responseCode.toString();
            if (responseCode == 401) {
                parsedResult = "Tibber rejected the API token";
            } else if (responseCode == 403) {
                parsedResult = "Tibber denied access; check the token's home scope";
            } else if (responseCode == 429) {
                parsedResult = "Tibber rate limit reached; try again later";
            } else if (responseCode < 0) {
                parsedResult = "Unable to reach Tibber; check the watch connection";
            }
        }

        if (parsedResult instanceof Dictionary && requestKind.equals("current")) {
            System.println("Tibber " + priceResolution + " current price parsed successfully");
        } else if (parsedResult instanceof Dictionary && requestKind.equals("daily")) {
            System.println("Tibber " + priceResolution + " daily prices parsed successfully");
        } else {
            System.println("Tibber GraphQL response returned an error");
        }

        pendingCallback.invoke(parsedResult);
    }

    /** Extract a safe user-facing message from a GraphQL errors array. */
    private function getGraphQlError(responseData as Dictionary) {
        var graphQlErrors = responseData.get("errors");
        if (graphQlErrors instanceof Array && (graphQlErrors as Array).size() > 0) {
            var firstError = (graphQlErrors as Array)[0];
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

    /** Parse current-price fields and convert SEK values to the displayed öre unit. */
    private function parseCurrentPriceData(responseData, priceResolution) {
        try {
            var responseBody = responseData.get("data");
            if (responseBody == null) {
                return "No data received";
            }

            var viewerData = (responseBody as Dictionary).get("viewer");
            if (viewerData == null) {
                return "Invalid data structure";
            }

            var userHomes = (viewerData as Dictionary).get("homes");
            if (userHomes == null || !(userHomes instanceof Array) || (userHomes as Array).size() == 0) {
                return "No homes found";
            }

            var selectedHome = (userHomes as Array)[0];
            if (!(selectedHome instanceof Dictionary)) {
                return "Invalid home data";
            }

            var subscription = (selectedHome as Dictionary).get("currentSubscription");
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

            var currentPriceTime = getCurrentTimeString(startsAt);

            return {
                "current_price" => price.format("%.0f"),
                "current_time" => currentPriceTime,
                "level" => level,
                "currency" => currency,
                "starts_at" => startsAt,
                "resolution" => priceResolution,
                "interval_minutes" => getIntervalMinutes(priceResolution)
            };

        } catch (ex) {
            System.println("Unable to parse Tibber current price response");
            return "Invalid Tibber price response";
        }
    }

    /** Format a Tibber ISO timestamp as local HH:mm, falling back to watch time. */
    private function getCurrentTimeString(startsAt) {
        if (startsAt instanceof String && (startsAt as String).length() >= 16) {
            return (startsAt as String).substring(11, 16);
        }

        var timeInfo = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return timeInfo.hour.format("%02d") + ":" + timeInfo.min.format("%02d");
    }

    /** Parse today's prices and append tomorrow with a 24-hour plotting offset when present. */
    private function parseDailyPricesData(responseData, priceResolution, includeTomorrow) {
        try {
            var responseBody = responseData.get("data");
            if (responseBody == null) {
                return "No data received";
            }

            var viewerData = (responseBody as Dictionary).get("viewer");
            if (viewerData == null) {
                return "Invalid data structure";
            }

            var userHomes = (viewerData as Dictionary).get("homes");
            if (userHomes == null || !(userHomes instanceof Array) || (userHomes as Array).size() == 0) {
                return "No homes found";
            }

            var selectedHome = (userHomes as Array)[0];
            if (!(selectedHome instanceof Dictionary)) {
                return "Invalid home data";
            }

            var subscription = (selectedHome as Dictionary).get("currentSubscription");
            if (subscription == null) {
                return "No subscription found";
            }

            var priceInfo = (subscription as Dictionary).get("priceInfo");
            if (priceInfo == null) {
                return "No price info found";
            }

            var todayPrices = (priceInfo as Dictionary).get("today");
            if (todayPrices == null || !(todayPrices instanceof Array)) {
                return "No daily prices found";
            }

            var priceIntervals = [];
            appendPriceIntervals(priceIntervals, todayPrices as Array, priceResolution, 0);

            var tomorrowAvailable = false;
            if (includeTomorrow) {
                var tomorrowPrices = (priceInfo as Dictionary).get("tomorrow");
                if (tomorrowPrices instanceof Array && (tomorrowPrices as Array).size() > 0) {
                    appendPriceIntervals(priceIntervals, tomorrowPrices as Array, priceResolution, 1440);
                    tomorrowAvailable = true;
                }
            }

            return {
                "resolution" => priceResolution,
                "resolution_minutes" => getIntervalMinutes(priceResolution),
                "span_minutes" => tomorrowAvailable ? 2880 : 1440,
                "tomorrow_available" => tomorrowAvailable,
                "intervals" => priceIntervals
            };

        } catch (ex) {
            return "Error parsing daily prices";
        }
    }

    /** Append validated price records using a local-day offset for graph placement. */
    private function appendPriceIntervals(priceIntervals, sourcePrices, priceResolution, dayOffset) as Void {
        for (var priceIndex = 0; priceIndex < sourcePrices.size(); priceIndex++) {
            var priceEntry = sourcePrices[priceIndex];
            if (priceEntry instanceof Dictionary) {
                var total = (priceEntry as Dictionary).get("total");
                var startsAt = (priceEntry as Dictionary).get("startsAt");
                var currency = (priceEntry as Dictionary).get("currency");
                var level = (priceEntry as Dictionary).get("level");

                if (total != null && startsAt != null) {
                    var startTimestamp = startsAt as String;
                    var startMinuteOfDay = getMinuteOfDay(startTimestamp);
                    if (startMinuteOfDay == null) {
                        continue;
                    }

                    var displayPrice = total as Float;
                    if (currency != null && currency.equals("SEK")) {
                        displayPrice = displayPrice * 100;
                    }

                    priceIntervals.add({
                        "starts_at" => startTimestamp,
                        "start_time" => getCurrentTimeString(startTimestamp),
                        "price" => displayPrice.format("%.0f"),
                        "price_value" => displayPrice,
                        "start_minute_of_day" => startMinuteOfDay,
                        "plot_minute" => dayOffset + startMinuteOfDay,
                        "currency" => currency,
                        "level" => level,
                        "resolution" => priceResolution,
                        "duration_minutes" => getIntervalMinutes(priceResolution)
                    });
                }
            }
        }
    }

    /** Extract local minutes since midnight from an ISO 8601 price timestamp. */
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