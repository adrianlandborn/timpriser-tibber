import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

/**
 * Development-only fake of Tibber's GraphQL answers, so Norwegian/German/Dutch (and Swedish)
 * contracts can be tried in the simulator without an account. Activated by setting the Tibber
 * token to "mock-se", "mock-no", "mock-de", "mock-nl" or "mock-usd"; append "-today" to leave out
 * tomorrow's prices. Store builds (monkey-release.jungle) replace this class with
 * release/config/ReleaseMock.mc, which never activates. See docs/mock-data.md.
 */
class TibberMock {
    private static const USED_KEY = "tibber_mock_used";
    // Relative hourly price shape (hundredths); scaled per scenario into major currency units.
    private static const HOUR_PROFILE as Array<Number> = [40, 38, 36, 35, 36, 42, 60, 85, 95, 80, 65, 55, 50, 48, 50, 58, 75, 100, 110, 95, 80, 65, 52, 45];

    static function isMockToken(token) as Boolean {
        return token instanceof String && (token as String).find("mock-") == 0;
    }

    /**
     * True while a mock token is active. Switching back to a real token wipes the cached mock
     * prices once (this clears all app Storage, including fee settings), so they are never shown
     * as real data.
     */
    static function bypassCache() as Boolean {
        var active = isMockToken(TibberTokenStore.getApiToken());
        var used = Storage.getValue(USED_KEY) == true;
        if (active) {
            if (!used) {
                Storage.setValue(USED_KEY, true);
            }
        } else if (used) {
            Storage.clearValues();
        }
        return active;
    }

    /** Build the parsed-JSON body Tibber would return for this request kind and resolution. */
    static function buildResponse(token, requestKind, priceResolution, includeTomorrow) {
        var scenario = (token as String).substring(5, (token as String).length());
        var todayOnly = scenario.find("-today") != null;
        var code = scenario.substring(0, 2);
        var params = getScenario(code);
        var step = priceResolution.equals("HOURLY") ? 60 : 15;

        var today = buildDay(params, step, 0, 0);
        var priceInfo = {"today" => today};
        if (requestKind.equals("current")) {
            priceInfo.put("current", getCurrentEntry(today, step));
        } else if (includeTomorrow && !todayOnly) {
            priceInfo.put("tomorrow", buildDay(params, step, 1, 3));
        }
        return {"data" => {"viewer" => {"homes" => [{"currentSubscription" => {"priceInfo" => priceInfo}}]}}};
    }

    /** Currency code a mock token answers with. */
    static function scenarioCurrency(token) as String {
        return getScenario((token as String).substring(5, 7))[0] as String;
    }

    /** "currency|today count|tomorrow count|current currency" of a response, for tests and logs. */
    static function describe(token, requestKind, priceResolution, includeTomorrow) as String {
        var body = buildResponse(token, requestKind, priceResolution, includeTomorrow) as Dictionary;
        var viewer = (body.get("data") as Dictionary).get("viewer") as Dictionary;
        var home = (viewer.get("homes") as Array)[0] as Dictionary;
        var info = (home.get("currentSubscription") as Dictionary).get("priceInfo") as Dictionary;
        var today = info.get("today") as Array;
        var tomorrow = info.get("tomorrow");
        var current = info.get("current");
        return (today[0] as Dictionary).get("currency") + "|" + today.size() + "|" +
            (tomorrow instanceof Array ? (tomorrow as Array).size() : 0) + "|" +
            (current instanceof Dictionary ? (current as Dictionary).get("currency") : "-");
    }

    // [currency, spot scale, VAT factor, fixed add-on to total]
    private static function getScenario(code) as Array {
        if (code.equals("no")) {
            return ["NOK", 0.012, 1.25, 0.0];
        } else if (code.equals("de")) {
            return ["EUR", 0.0009, 1.19, 0.22];
        } else if (code.equals("nl")) {
            return ["EUR", 0.001, 1.21, 0.14];
        } else if (code.equals("us")) {
            return ["USD", 0.001, 1.0, 0.0];
        }
        return ["SEK", 0.01, 1.25, 0.5];
    }

    private static function buildDay(params as Array, step as Number, dayOffset as Number, hourShift as Number) as Array {
        var date = Time.Gregorian.info(Time.now().add(new Time.Duration(dayOffset * 86400)), Time.FORMAT_SHORT);
        var prefix = date.year.format("%04d") + "-" + date.month.format("%02d") + "-" + date.day.format("%02d") + "T";
        var entries = [];
        for (var minute = 0; minute < 1440; minute += step) {
            var hour = minute / 60;
            var shape = HOUR_PROFILE[(hour + 24 - hourShift) % 24] + (minute % 60) / 15;
            var spot = shape * params[1];
            entries.add({
                "total" => spot * params[2] + params[3],
                "energy" => spot,
                "level" => getLevel(shape),
                "startsAt" => prefix + hour.format("%02d") + ":" + (minute % 60).format("%02d") + ":00.000+01:00",
                "currency" => params[0]
            });
        }
        return entries;
    }

    private static function getCurrentEntry(today as Array, step as Number) {
        var now = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var minute = now.hour * 60 + now.min;
        return today[(minute - (minute % step)) / step];
    }

    private static function getLevel(shape) {
        if (shape < 45) {
            return "VERY_CHEAP";
        } else if (shape < 60) {
            return "CHEAP";
        } else if (shape < 85) {
            return "NORMAL";
        } else if (shape < 100) {
            return "EXPENSIVE";
        }
        return "VERY_EXPENSIVE";
    }
}
