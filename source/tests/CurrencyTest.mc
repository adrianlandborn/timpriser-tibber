import Toybox.Application.Storage;
import Toybox.Test;

(:test)
function testCurrencyMinorUnits(logger) {
    Test.assertEqual(TibberCurrency.minorUnitFactor("SEK"), 100);
    Test.assertEqual(TibberCurrency.minorUnitFactor("NOK"), 100);
    Test.assertEqual(TibberCurrency.minorUnitFactor("EUR"), 100);
    Test.assertEqual(TibberCurrency.minorUnitFactor("USD"), 1);
    Test.assertEqual(TibberCurrency.minorUnitFactor(null), 1);
    // Unit follows the API currency only, never the watch language.
    Test.assertEqual(TibberCurrency.unitLabel("SEK"), "öre");
    Test.assertEqual(TibberCurrency.unitLabel("NOK"), "øre");
    Test.assertEqual(TibberCurrency.unitLabel("EUR"), "cent");
    Test.assertEqual(TibberCurrency.unitLabel("USD"), "USD");
    return true;
}

(:test)
function testCurrencyFeesOnlyForSweden(logger) {
    var key = "tibber_network_fees_enabled";
    var original = Storage.getValue(key);
    Storage.setValue(key, true);
    var sweden = TibberCurrency.feesActive("SEK");
    var unknown = TibberCurrency.feesActive(null);
    var norway = TibberCurrency.feesActive("NOK");
    var euro = TibberCurrency.feesActive("EUR");
    if (original == null) {
        Storage.deleteValue(key);
    } else {
        Storage.setValue(key, original);
    }
    return sweden && unknown && !norway && !euro && !TibberCurrency.feesSupported("EUR");
}

(:test)
function testNonSwedishPriceIgnoresFees(logger) {
    var keys = ["tibber_network_fees_enabled", "tibber_network_fixed_ore"];
    var originals = [Storage.getValue(keys[0]), Storage.getValue(keys[1])];
    Storage.setValue(keys[0], true);
    Storage.setValue(keys[1], 20.0);
    var priceData = {
        "current_price" => "30",
        "current_spot_price" => "20",
        "current_price_value" => 30.0,
        "currency" => "EUR",
        "hourly_spot_average" => 20.0
    };
    var shown = new TibberPriceCache().getDisplayPrice(priceData, "TOTAL");
    for (var index = 0; index < keys.size(); index += 1) {
        if (originals[index] == null) {
            Storage.deleteValue(keys[index]);
        } else {
            Storage.setValue(keys[index], originals[index]);
        }
    }
    return shown.equals("30");
}

(:test)
function testMockScenarioCurrencies(logger) {
    Test.assertEqual(TibberMock.describe("mock-se", "daily", "HOURLY", true), "SEK|24|24|-");
    Test.assertEqual(TibberMock.describe("mock-no", "daily", "HOURLY", true), "NOK|24|24|-");
    Test.assertEqual(TibberMock.describe("mock-de", "daily", "HOURLY", true), "EUR|24|24|-");
    Test.assertEqual(TibberMock.describe("mock-nl", "daily", "HOURLY", true), "EUR|24|24|-");
    Test.assertEqual(TibberMock.describe("mock-us", "daily", "HOURLY", true), "USD|24|24|-");
    return true;
}

(:test)
function testMockResolutionAndTomorrow(logger) {
    Test.assertEqual(TibberMock.describe("mock-no", "daily", "QUARTER_HOURLY", true), "NOK|96|96|-");
    Test.assertEqual(TibberMock.describe("mock-de-today", "daily", "HOURLY", true), "EUR|24|0|-");
    Test.assertEqual(TibberMock.describe("mock-nl", "current", "HOURLY", false), "EUR|24|0|EUR");
    return true;
}

(:test)
function testMockTokenDetection(logger) {
    Test.assertEqual(TibberMock.isMockToken("mock-no"), true);
    Test.assertEqual(TibberMock.isMockToken("abc123"), false);
    Test.assertEqual(TibberMock.isMockToken(null), false);
    return true;
}
