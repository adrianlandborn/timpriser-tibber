import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

/**
 * One-shot background fetch requested by the glance when no price data exists for today.
 * Fetches only today's prices, stores them in the shared price cache and exits; the glance re-reads
 * the cache. Runs in the small background heap, so it avoids resources and error strings.
 * Excluded on Tier B devices (see monkey.jungle, :bgFetch).
 */
(:background :bgFetch)
class TibberBackgroundDelegate extends System.ServiceDelegate {
    private const API_URL = "https://api.tibber.com/v1-beta/gql";
    private var _resolution;

    function initialize() {
        ServiceDelegate.initialize();
        _resolution = "QUARTER_HOURLY";
    }

    function onTemporalEvent() as Void {
        var resolution = Storage.getValue("tibber_price_resolution");
        if (resolution instanceof String && (resolution as String).equals("HOURLY")) {
            _resolution = "HOURLY";
        }

        if (new TibberPriceCache().getCurrentPrice(_resolution) != null) {
            Background.exit(0);
            return;
        }

        // TibberSecrets is not available in background scope; the dev token comes from its Storage mirror.
        var token = TibberTokenStore.getBackgroundToken();
        if (!TibberTokenStore.looksValid(token)) {
            Background.exit(-1);
            return;
        }

        // Minimal fields: the full per-interval payload (startsAt, currency) does not fit the background
        // heap at 15-minute resolution (-403 out of memory). Interval start is derived from the index.
        var body = {
            "query" => "{ viewer { homes { currentSubscription { priceInfo(resolution: " + _resolution +
                ") { current { currency } today { total energy level } } } } } }"
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers => {
                "Authorization" => "Bearer " + token,
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "Accept" => "application/json",
                "User-Agent" => "Garmin Connect IQ/9.3.0 TibberWidget/1.0.0"
            }
        };
        try {
            Communications.makeWebRequest(API_URL, body, options, method(:onResponse));
        } catch (ex) {
            Background.exit(-2);
        }
    }

    function onResponse(responseCode as Number, responseData as Dictionary or String or Null) as Void {
        if (responseCode != 200 || !(responseData instanceof Dictionary)) {
            Background.exit(responseCode);
            return;
        }

        var prices = parseToday(responseData as Dictionary, _resolution);
        responseData = null;
        if (prices == null) {
            Background.exit(-3);
            return;
        }

        new TibberPriceCache().storeDailyPrices(_resolution, false, prices);
        Background.exit(200);
    }

    /**
     * Build the same daily-prices dictionary the foreground client stores (today only), or null.
     * Without startsAt the start minute is index * step, which only holds on a normal 24-hour day;
     * on DST change days (23/25 hours) it gives up and the app fetches when opened.
     */
    static function parseToday(response as Dictionary, resolution as String) {
        try {
            var data = response.get("data") as Dictionary?;
            var homes = data != null ? ((data.get("viewer") as Dictionary).get("homes") as Array) : null;
            if (homes == null || homes.size() == 0) {
                return null;
            }
            var subscription = (homes[0] as Dictionary).get("currentSubscription") as Dictionary?;
            if (subscription == null) {
                return null;
            }
            var priceInfo = subscription.get("priceInfo") as Dictionary;
            var today = priceInfo.get("today") as Array?;
            var step = resolution.equals("HOURLY") ? 60 : 15;
            if (today == null || today.size() * step != 1440) {
                return null;
            }

            var current = priceInfo.get("current") as Dictionary?;
            var currency = current != null ? current.get("currency") : null;
            var factor = TibberCurrency.minorUnitFactor(currency);

            var intervals = [];
            for (var i = 0; i < today.size(); i++) {
                var entry = today[i] as Dictionary;
                var total = entry.get("total");
                var energy = entry.get("energy");
                if (total == null || energy == null) {
                    return null;
                }
                intervals.add([i * step, (total as Float) * factor, (energy as Float) * factor, levelCode(entry.get("level"))]);
            }

            return {
                "resolution" => resolution,
                "resolution_minutes" => step,
                "currency" => currency,
                "span_minutes" => 1440,
                "tomorrow_available" => false,
                "intervals" => intervals
            };
        } catch (ex) {
            return null;
        }
    }

    /** 1 (very cheap) .. 5 (very expensive); 0 when unknown. */
    private static function levelCode(level) {
        if (!(level instanceof String)) {
            return 0;
        }
        var levels = ["VERY_CHEAP", "CHEAP", "NORMAL", "EXPENSIVE", "VERY_EXPENSIVE"];
        for (var i = 0; i < levels.size(); i++) {
            if ((level as String).equals(levels[i])) {
                return i + 1;
            }
        }
        return 0;
    }
}
