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
    private var _priceCache;

    /** Initialize the HTTP request state for this client instance. */
    function initialize() {
        _responseCallback = null;
        _requestType = null;
        _requestResolution = null;
        _requestIncludeTomorrow = false;
        _priceCache = new TibberPriceCache();
    }

    /** Fetch the current price for the requested Tibber resolution. */
    function getCurrentPrice(responseCallback, priceResolution) {
        if (!isSupportedResolution(priceResolution)) {
            responseCallback.invoke("Ogiltig prisupplösning");
            return;
        }

        var cachedPrice = _priceCache.getCurrentPrice(priceResolution);
        if (cachedPrice != null) {
            responseCallback.invoke(cachedPrice);
            return;
        }

        requestCurrentPrice(responseCallback, priceResolution);
    }

    /** Fetch the current price while bypassing cached values. */
    function refreshCurrentPrice(responseCallback, priceResolution) {
        if (!isSupportedResolution(priceResolution)) {
            responseCallback.invoke("Ogiltig prisupplösning");
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
            responseCallback.invoke("Ogiltig prisupplösning");
            return;
        }

        var cachedPrices = _priceCache.getDailyPrices(priceResolution, includeTomorrow, false);
        if (cachedPrices != null) {
            responseCallback.invoke(cachedPrices);
            return;
        }

        requestDailyPrices(responseCallback, priceResolution, includeTomorrow);
    }

    /** Fetch daily prices while bypassing cached values. */
    function refreshDailyPrices(responseCallback, priceResolution, includeTomorrow) {
        if (!isSupportedResolution(priceResolution)) {
            responseCallback.invoke("Ogiltig prisupplösning");
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
            responseCallback.invoke("En Tibber-förfrågan pågår redan");
            return;
        }

        var accessToken = TibberSecrets.getApiToken();
        if (accessToken.length() == 0) {
            responseCallback.invoke("Tibber-token saknas");
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

        _responseCallback = responseCallback;
        _requestType = requestKind;
        _requestResolution = priceResolution;
        _requestIncludeTomorrow = includeTomorrow;

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
            responseCallback.invoke("Kunde inte starta Tibber-förfrågan");
        }
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
                parsedResult = "Tibber returnerade ett ogiltigt svar";
            }
        } else {
            parsedResult = "Tibber HTTP-fel " + responseCode.toString();
            if (responseCode == 401) {
                parsedResult = "Tibber avvisade API-token";
            } else if (responseCode == 403) {
                parsedResult = "Åtkomst nekad. Kontrollera tokenens behörighet.";
            } else if (responseCode == 429) {
                parsedResult = "Tibbers anropsgräns nåddes. Försök senare.";
            } else if (responseCode < 0) {
                parsedResult = "Ingen kontakt med Tibber. Kontrollera klockans anslutning.";
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
                    return "Tibber-förfrågan misslyckades";
                }
            }
            return "Tibber-förfrågan misslyckades";
        }
        return null;
    }

    /** Parse current-price fields and convert SEK values to the displayed öre unit. */
    private function parseCurrentPriceData(responseData, priceResolution) {
        try {
            var responseBody = responseData.get("data");
            if (responseBody == null) {
                return "Ingen data hämtades";
            }

            var viewerData = (responseBody as Dictionary).get("viewer");
            if (viewerData == null) {
                return "Ogiltigt svarsformat";
            }

            var userHomes = (viewerData as Dictionary).get("homes");
            if (userHomes == null || !(userHomes instanceof Array) || (userHomes as Array).size() == 0) {
                return "Inget Tibber-hem hittades";
            }

            var selectedHome = (userHomes as Array)[0];
            if (!(selectedHome instanceof Dictionary)) {
                return "Ogiltiga hemuppgifter";
            }

            var subscription = (selectedHome as Dictionary).get("currentSubscription");
            if (subscription == null) {
                return "Inget aktivt elavtal hittades";
            }

            var priceInfo = (subscription as Dictionary).get("priceInfo");
            if (priceInfo == null) {
                return "Prisdata saknas";
            }

            var current = (priceInfo as Dictionary).get("current");
            if (current == null) {
                return "Aktuellt pris saknas";
            }

            var currentDict = current as Dictionary;
            var total = currentDict.get("total");
            var energy = currentDict.get("energy");
            var level = currentDict.get("level");
            var currency = currentDict.get("currency");
            var startsAt = currentDict.get("startsAt");

            if (total == null || energy == null) {
                return "Ogiltiga prisuppgifter";
            }

            var price = total as Float;
            var spotPrice = energy as Float;
            if (currency != null && currency.equals("SEK")) {
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
            return "Ogiltigt prissvar från Tibber";
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
                return "Ingen data hämtades";
            }

            var viewerData = (responseBody as Dictionary).get("viewer");
            if (viewerData == null) {
                return "Ogiltigt svarsformat";
            }

            var userHomes = (viewerData as Dictionary).get("homes");
            if (userHomes == null || !(userHomes instanceof Array) || (userHomes as Array).size() == 0) {
                return "Inget Tibber-hem hittades";
            }

            var selectedHome = (userHomes as Array)[0];
            if (!(selectedHome instanceof Dictionary)) {
                return "Ogiltiga hemuppgifter";
            }

            var subscription = (selectedHome as Dictionary).get("currentSubscription");
            if (subscription == null) {
                return "Inget aktivt elavtal hittades";
            }

            var priceInfo = (subscription as Dictionary).get("priceInfo");
            if (priceInfo == null) {
                return "Prisdata saknas";
            }

            var todayPrices = (priceInfo as Dictionary).get("today");
            if (todayPrices == null || !(todayPrices instanceof Array)) {
                return "Dagens priser saknas";
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
            return "Kunde inte läsa dagspriser";
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
                    if (currency != null && currency.equals("SEK")) {
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