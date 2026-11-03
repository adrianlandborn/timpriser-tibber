import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;

class TibberApiClient {
    private const TIBBER_API_URL = "https://api.tibber.com/v1-beta/gql";
    private var _responseCallback;
    private var _requestType; // "current" or "daily"
    private var _requestResolution;
    private var _requestIncludeTomorrow;
    private var _priceCache;
    private var _mockTimer;
    private var _mockToken;

    /** Initialize the HTTP request state for this client instance. */
    function initialize() {
        _responseCallback = null;
        _requestType = null;
        _requestResolution = null;
        _requestIncludeTomorrow = false;
        _priceCache = new TibberPriceCache();
        _mockTimer = null;
        _mockToken = null;
    }

    /** Fetch the current price for the requested Tibber resolution. */
    function getCurrentPrice(responseCallback, priceResolution) {
        if (!isSupportedResolution(priceResolution)) {
            responseCallback.invoke(loadString(Rez.Strings.ErrorInvalidResolution));
            return;
        }

        var cachedPrice = TibberMock.bypassCache() ? null : _priceCache.getCurrentPrice(priceResolution);
        if (cachedPrice != null) {
            responseCallback.invoke(cachedPrice);
            return;
        }

        requestCurrentPrice(responseCallback, priceResolution);
    }

    /** Fetch the current price while bypassing cached values. */
    function refreshCurrentPrice(responseCallback, priceResolution) {
        if (!isSupportedResolution(priceResolution)) {
            responseCallback.invoke(loadString(Rez.Strings.ErrorInvalidResolution));
            return;
        }
        requestCurrentPrice(responseCallback, priceResolution);
    }

    private function requestCurrentPrice(responseCallback, priceResolution) {

        var query = {
            "query" => "{ viewer { homes { currentSubscription { priceInfo(resolution: " + priceResolution + ") { current { total energy level currency startsAt } today { total energy level startsAt currency } } } } } }"
        };
        makeRequest(query, "current", priceResolution, false, responseCallback);
    }

    /**
     * Fetch today's prices at the requested resolution, optionally including tomorrow.
     * The response dictionary contains timestamped intervals and a span_minutes value.
     */
    function getDailyPrices(responseCallback, priceResolution, includeTomorrow) {
        if (!isSupportedResolution(priceResolution)) {
            responseCallback.invoke(loadString(Rez.Strings.ErrorInvalidResolution));
            return;
        }

        var cachedPrices = TibberMock.bypassCache() ? null : _priceCache.getDailyPrices(priceResolution, includeTomorrow, false);
        if (cachedPrices != null) {
            responseCallback.invoke(cachedPrices);
            return;
        }

        requestDailyPrices(responseCallback, priceResolution, includeTomorrow);
    }

    /** Fetch daily prices while bypassing cached values. */
    function refreshDailyPrices(responseCallback, priceResolution, includeTomorrow) {
        if (!isSupportedResolution(priceResolution)) {
            responseCallback.invoke(loadString(Rez.Strings.ErrorInvalidResolution));
            return;
        }
        requestDailyPrices(responseCallback, priceResolution, includeTomorrow);
    }

    private function requestDailyPrices(responseCallback, priceResolution, includeTomorrow) {

        var requestedPriceFields = "today { total energy level startsAt currency }";
        if (includeTomorrow) {
            requestedPriceFields += " tomorrow { total energy level startsAt currency }";
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
            responseCallback.invoke(loadString(Rez.Strings.ErrorRequestInProgress));
            return;
        }

        var accessToken = TibberTokenStore.getApiToken();
        if (accessToken.length() == 0) {
            responseCallback.invoke(loadString(Rez.Strings.ErrorTokenMissing));
            return;
        }

        _responseCallback = responseCallback;
        _requestType = requestKind;
        _requestResolution = priceResolution;
        _requestIncludeTomorrow = includeTomorrow;

        if (TibberMock.isMockToken(accessToken)) {
            // Development only: answer from TibberMock instead of the network (see docs/mock-data.md).
            System.println("Tibber MOCK " + accessToken + " " + requestKind + " " + priceResolution);
            _mockToken = accessToken;
            _mockTimer = new Timer.Timer();
            _mockTimer.start(method(:onMockResponse), 50, false);
            return;
        }

        System.println("Tibber POST " + TIBBER_API_URL + " " + requestKind + " " + priceResolution);

        var requestOptions = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
            "Authorization" => "Bearer " + accessToken,
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "Accept" => "application/json",
                "User-Agent" => "Garmin Connect IQ/9.3.0 TibberWidget/1.0.0"
            }
        };

        try {
            Communications.makeJsonRequest(
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
            responseCallback.invoke(loadString(Rez.Strings.ErrorRequestStart));
        }
    }

    /** Deliver the mock answer asynchronously, like a real HTTP response. */
    function onMockResponse() as Void {
        _mockTimer = null;
        var body = TibberMock.buildResponse(_mockToken, _requestType, _requestResolution, _requestIncludeTomorrow);
        onApiResponse(200, body);
    }

    /** Route an HTTP response through the matching parser and invoke its callback. */
    function onApiResponse(responseCode as Number, responseData as Dictionary or String or Null) as Void {
        if (_responseCallback == null) {
            return;
        }

        System.println("Tibber HTTP " + responseCode.toString() + " from " + TIBBER_API_URL + " " + _requestType + " " + _requestResolution);

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
                    if (parsedResult instanceof Dictionary) {
                        _priceCache.storeCurrentPrice(priceResolution, parsedResult as Dictionary);
                        var dailyPrices = parseDailyPricesData(responseData as Dictionary, priceResolution, false);
                        if (dailyPrices instanceof Dictionary) {
                            _priceCache.storeDailyPrices(priceResolution, false, dailyPrices);
                            var derivedPrice = _priceCache.getCurrentPrice(priceResolution);
                            if (derivedPrice instanceof Dictionary) {
                                parsedResult = derivedPrice;
                            }
                        }
                    }
                } else {
                    parsedResult = parseDailyPricesData(responseData as Dictionary, priceResolution, includeTomorrow);
                    if (parsedResult instanceof Dictionary) {
                        _priceCache.storeDailyPrices(priceResolution, includeTomorrow, parsedResult as Dictionary);
                    }
                }
            } else {
                parsedResult = loadString(Rez.Strings.ErrorInvalidResponse);
            }
        } else {
            parsedResult = loadString(Rez.Strings.ErrorHttpPrefix) + responseCode.toString();
            if (responseCode == 401) {
                parsedResult = loadString(Rez.Strings.ErrorTokenRejected);
            } else if (responseCode == 403) {
                parsedResult = loadString(Rez.Strings.ErrorAccessDenied);
            } else if (responseCode == 429) {
                parsedResult = loadString(Rez.Strings.ErrorRateLimited);
            } else if (responseCode < 0) {
                parsedResult = loadString(Rez.Strings.ErrorNoConnection);
            }
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
                    return loadString(Rez.Strings.ErrorRequestFailed);
                }
            }
            return loadString(Rez.Strings.ErrorRequestFailed);
        }
        return null;
    }

    /** Parse current-price fields and convert SEK/NOK/EUR values to the displayed minor unit (öre/øre/cent). */
    private function parseCurrentPriceData(responseData, priceResolution) {
        try {
            var responseBody = responseData.get("data");
            if (responseBody == null) {
                return loadString(Rez.Strings.ErrorNoData);
            }

            var viewerData = (responseBody as Dictionary).get("viewer");
            if (viewerData == null) {
                return loadString(Rez.Strings.ErrorInvalidFormat);
            }

            var userHomes = (viewerData as Dictionary).get("homes");
            if (userHomes == null || !(userHomes instanceof Array) || (userHomes as Array).size() == 0) {
                return loadString(Rez.Strings.ErrorNoHome);
            }

            var selectedHome = (userHomes as Array)[0];
            if (!(selectedHome instanceof Dictionary)) {
                return loadString(Rez.Strings.ErrorInvalidHome);
            }

            var subscription = (selectedHome as Dictionary).get("currentSubscription");
            if (subscription == null) {
                return loadString(Rez.Strings.ErrorNoSubscription);
            }

            var priceInfo = (subscription as Dictionary).get("priceInfo");
            if (priceInfo == null) {
                return loadString(Rez.Strings.ErrorPriceDataMissing);
            }

            var current = (priceInfo as Dictionary).get("current");
            if (current == null) {
                return loadString(Rez.Strings.ErrorCurrentPriceMissing);
            }

            var currentDict = current as Dictionary;
            var total = currentDict.get("total");
            var energy = currentDict.get("energy");
            var level = currentDict.get("level");
            var currency = currentDict.get("currency");
            var startsAt = currentDict.get("startsAt");

            if (total == null || energy == null) {
                return loadString(Rez.Strings.ErrorInvalidPriceFields);
            }

            var price = total as Float;
            var spotPrice = energy as Float;
            if (TibberCurrency.isMinorUnit(currency)) {
                price = price * 100;
                spotPrice = spotPrice * 100;
            }

            var currentPriceTime = getCurrentTimeString(startsAt);

            return {
                "current_price" => price.format("%.0f"),
                "current_spot_price" => spotPrice.format("%.0f"),
                "current_time" => currentPriceTime,
                "level" => level,
                "currency" => currency,
                "starts_at" => startsAt,
                "resolution" => priceResolution,
                "interval_minutes" => getIntervalMinutes(priceResolution)
            };

        } catch (ex) {
            return loadString(Rez.Strings.ErrorInvalidPriceResponse);
        }
    }

    /** Use the HH:mm clock fields from a Tibber ISO timestamp (not timezone-converted). */
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
                return loadString(Rez.Strings.ErrorNoData);
            }

            var viewerData = (responseBody as Dictionary).get("viewer");
            if (viewerData == null) {
                return loadString(Rez.Strings.ErrorInvalidFormat);
            }

            var userHomes = (viewerData as Dictionary).get("homes");
            if (userHomes == null || !(userHomes instanceof Array) || (userHomes as Array).size() == 0) {
                return loadString(Rez.Strings.ErrorNoHome);
            }

            var selectedHome = (userHomes as Array)[0];
            if (!(selectedHome instanceof Dictionary)) {
                return loadString(Rez.Strings.ErrorInvalidHome);
            }

            var subscription = (selectedHome as Dictionary).get("currentSubscription");
            if (subscription == null) {
                return loadString(Rez.Strings.ErrorNoSubscription);
            }

            var priceInfo = (subscription as Dictionary).get("priceInfo");
            if (priceInfo == null) {
                return loadString(Rez.Strings.ErrorPriceDataMissing);
            }

            var todayPrices = (priceInfo as Dictionary).get("today");
            if (todayPrices == null || !(todayPrices instanceof Array)) {
                return loadString(Rez.Strings.ErrorTodayPricesMissing);
            }

            var currency = null;
            if ((todayPrices as Array).size() > 0 && (todayPrices as Array)[0] instanceof Dictionary) {
                currency = ((todayPrices as Array)[0] as Dictionary).get("currency");
            }

            var priceIntervals = [];
            appendPriceIntervals(priceIntervals, todayPrices as Array, priceResolution, 0, currency);

            var tomorrowAvailable = false;
            if (includeTomorrow) {
                var tomorrowPrices = (priceInfo as Dictionary).get("tomorrow");
                if (tomorrowPrices instanceof Array && (tomorrowPrices as Array).size() > 0) {
                    appendPriceIntervals(priceIntervals, tomorrowPrices as Array, priceResolution, 1440, currency);
                    tomorrowAvailable = true;
                }
            }

            return {
                "resolution" => priceResolution,
                "resolution_minutes" => getIntervalMinutes(priceResolution),
                "currency" => currency,
                "span_minutes" => tomorrowAvailable ? 2880 : 1440,
                "tomorrow_available" => tomorrowAvailable,
                "intervals" => priceIntervals
            };

        } catch (ex) {
            return loadString(Rez.Strings.ErrorDailyPrices);
        }
    }

    /** Append validated price records using a local-day offset for graph placement. */
    private function appendPriceIntervals(priceIntervals, sourcePrices, priceResolution, dayOffset, currency) as Void {
        for (var priceIndex = 0; priceIndex < sourcePrices.size(); priceIndex++) {
            var priceEntry = sourcePrices[priceIndex];
            if (priceEntry instanceof Dictionary) {
                var total = (priceEntry as Dictionary).get("total");
                var energy = (priceEntry as Dictionary).get("energy");
                var startsAt = (priceEntry as Dictionary).get("startsAt");

                if (total != null && energy != null && startsAt != null) {
                    var startMinuteOfDay = getMinuteOfDay(startsAt);
                    if (startMinuteOfDay == null) {
                        continue;
                    }

                    var displayPrice = total as Float;
                    var spotPrice = energy as Float;
                    if (TibberCurrency.isMinorUnit(currency)) {
                        displayPrice = displayPrice * 100;
                        spotPrice = spotPrice * 100;
                    }

                    priceIntervals.add([dayOffset + startMinuteOfDay, displayPrice, spotPrice, getLevelCode((priceEntry as Dictionary).get("level"))]);
                }
            }
        }
    }

    /** Map Tibber's price level enum to 1 (very cheap) .. 5 (very expensive); 0 when unknown. */
    private function getLevelCode(level) {
        if (!(level instanceof String)) {
            return 0;
        }
        var levels = ["VERY_CHEAP", "CHEAP", "NORMAL", "EXPENSIVE", "VERY_EXPENSIVE"];
        for (var index = 0; index < levels.size(); index++) {
            if ((level as String).equals(levels[index])) {
                return index + 1;
            }
        }
        return 0;
    }

    /** Extract HH:mm clock fields from an ISO 8601 timestamp (not timezone-converted). */
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

    private function loadString(resource) {
        return Application.loadResource(resource) as String;
    }
}