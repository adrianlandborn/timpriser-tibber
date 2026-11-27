import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

/** Reduced background response: current { currency } plus today { total energy level }, no startsAt. */
(:test)
class TibberBgFetchFake {
    static function response(count as Number, currency) as Dictionary {
        var today = [];
        for (var i = 0; i < count; i++) {
            today.add({"total" => 1.0 + i, "energy" => 0.5, "level" => i == 0 ? "VERY_CHEAP" : "NORMAL"});
        }
        var priceInfo = {"today" => today};
        if (currency != null) {
            priceInfo.put("current", {"currency" => currency});
        }
        return {"data" => {"viewer" => {"homes" => [{"currentSubscription" => {"priceInfo" => priceInfo}}]}}};
    }
}

(:test)
function testBackgroundParseQuarterHourly(logger) {
    var parsed = TibberBackgroundDelegate.parseToday(TibberBgFetchFake.response(96, "SEK"), "QUARTER_HOURLY") as Dictionary;
    var intervals = parsed.get("intervals") as Array;
    Test.assertEqual(intervals.size(), 96);
    Test.assertEqual(parsed.get("resolution_minutes"), 15);
    Test.assertEqual(parsed.get("span_minutes"), 1440);
    Test.assertEqual(parsed.get("tomorrow_available"), false);
    Test.assertEqual(parsed.get("currency"), "SEK");
    // Start minute comes from the index; SEK is converted to öre; level maps to its code.
    var first = intervals[0] as Array;
    var last = intervals[95] as Array;
    Test.assertEqual(first[0], 0);
    Test.assertEqual(last[0], 95 * 15);
    Test.assertEqual((first[1] as Float).toNumber(), 100);
    Test.assertEqual((first[2] as Float).toNumber(), 50);
    Test.assertEqual(first[3], 1);
    Test.assertEqual((intervals[1] as Array)[3], 3);
    return true;
}

(:test)
function testBackgroundParseHourlyUnknownCurrency(logger) {
    var parsed = TibberBackgroundDelegate.parseToday(TibberBgFetchFake.response(24, "USD"), "HOURLY") as Dictionary;
    var intervals = parsed.get("intervals") as Array;
    Test.assertEqual(intervals.size(), 24);
    Test.assertEqual(parsed.get("resolution_minutes"), 60);
    Test.assertEqual((intervals[23] as Array)[0], 23 * 60);
    // No minor-unit conversion for an unknown currency.
    Test.assertEqual(((intervals[0] as Array)[1] as Float).toNumber(), 1);
    return true;
}

(:test)
function testBackgroundParseRejectsDstAndBadData(logger) {
    // DST change days have 92 or 100 quarters; index-based times would be wrong.
    Test.assert(TibberBackgroundDelegate.parseToday(TibberBgFetchFake.response(92, "SEK"), "QUARTER_HOURLY") == null);
    Test.assert(TibberBackgroundDelegate.parseToday(TibberBgFetchFake.response(100, "SEK"), "QUARTER_HOURLY") == null);
    Test.assert(TibberBackgroundDelegate.parseToday(TibberBgFetchFake.response(96, "SEK"), "HOURLY") == null);
    Test.assert(TibberBackgroundDelegate.parseToday({"errors" => []}, "QUARTER_HOURLY") == null);
    Test.assert(TibberBackgroundDelegate.parseToday({"data" => {"viewer" => {"homes" => []}}}, "QUARTER_HOURLY") == null);
    return true;
}

(:test)
function testBackgroundTokenFallsBackToDevMirror(logger) {
    var originalSetting = Application.Properties.getValue("tibberToken");
    var originalMirror = Storage.getValue("tibber_dev_token");
    Application.Properties.setValue("tibberToken", "");
    Storage.setValue("tibber_dev_token", "mirroredDevToken1234");
    var fromMirror = TibberTokenStore.getBackgroundToken();
    Application.Properties.setValue("tibberToken", "settingsToken12345678");
    var fromSetting = TibberTokenStore.getBackgroundToken();

    Application.Properties.setValue("tibberToken", originalSetting == null ? "" : originalSetting);
    if (originalMirror == null) {
        Storage.deleteValue("tibber_dev_token");
    } else {
        Storage.setValue("tibber_dev_token", originalMirror);
    }

    Test.assertEqual(fromMirror, "mirroredDevToken1234");
    Test.assertEqual(fromSetting, "settingsToken12345678");
    return true;
}
