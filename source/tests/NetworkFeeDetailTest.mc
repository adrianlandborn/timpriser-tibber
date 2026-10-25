import Toybox.Application.Storage;
import Toybox.Time;

(:test)
function testNetworkFeeButtonAdjustments(logger) {
    var passed = true;
    var options = [2, 3, 5];
    for (var optionIndex = 0; optionIndex < options.size(); optionIndex += 1) {
        var feeOption = options[optionIndex];
        var key = feeOption == 5 ? "tibber_energy_tax_ore" : (feeOption == 2 ? "tibber_network_fixed_ore" : "tibber_network_variable_percent");
        var initialValue = feeOption == 5 ? 45.0 : (feeOption == 2 ? 20.0 : 5.0);
        var originalValue = Storage.getValue(key);
        var detailView = new TibberNetworkFeeDetailView(feeOption, null, null, null);
        var delegate = new TibberNetworkFeeDetailDelegate(detailView);
        Storage.setValue(key, initialValue);

        delegate.onPreviousPage();
        var firstIncrease = Storage.getValue(key);
        delegate.onPreviousPage();
        var secondIncrease = Storage.getValue(key);
        delegate.onNextPage();
        var decrease = Storage.getValue(key);

        if (originalValue == null) {
            Storage.deleteValue(key);
        } else {
            Storage.setValue(key, originalValue);
        }

        if (firstIncrease != initialValue + 1 || secondIncrease != initialValue + 2 ||
            decrease != initialValue + 1) {
            logger.debug("Fee button adjustments did not retain their values");
            passed = false;
        }
    }
    return passed;
}

(:test)
function testCurrentPriceNetworkFees(logger) {
    var keys = ["tibber_network_fees_enabled", "tibber_network_fixed_ore", "tibber_network_variable_percent", "tibber_energy_tax_ore"];
    var originalValues = [];
    for (var index = 0; index < keys.size(); index += 1) {
        originalValues.add(Storage.getValue(keys[index]));
    }
    var cache = new TibberPriceCache();
    Storage.setValue(keys[3], 45.0);
    var priceData = {
        "current_price" => "100",
        "current_spot_price" => "40",
        "current_price_value" => 100.4,
        "current_spot_value" => 40.4,
        "hourly_spot_average" => 50.0
    };
    Storage.setValue(keys[0], false);
    var unadjusted = cache.getDisplayPrice(priceData, "TOTAL");
    Storage.setValue(keys[0], true);
    Storage.setValue(keys[1], 20.5);
    Storage.setValue(keys[2], 10.0);
    var total = cache.getDisplayPrice(priceData, "TOTAL");
    var spot = cache.getDisplayPrice(priceData, "SPOT");
    Storage.setValue(keys[1], 30.5);
    var updated = cache.getDisplayPrice(priceData, "TOTAL");
    Storage.setValue(keys[0], false);
    var disabled = cache.getDisplayPrice(priceData, "TOTAL");
    for (var index = 0; index < keys.size(); index += 1) {
        if (originalValues[index] == null) {
            Storage.deleteValue(keys[index]);
        } else {
            Storage.setValue(keys[index], originalValues[index]);
        }
    }
    return unadjusted.equals("100") && total.equals("172") && spot.equals("40") &&
        updated.equals("182") && disabled.equals("100") && priceData.get("current_price").equals("100");
}

(:test)
function testCachedQuarterHourNetworkFees(logger) {
    var keys = ["tibber_network_fees_enabled", "tibber_network_fixed_ore", "tibber_network_variable_percent", "tibber_energy_tax_ore"];
    var prefixes = ["pd3qd", "pc3q"];
    var suffixes = ["r", "d", "i", "s", "m", "c", "t", "n", "p", "e"];
    for (var prefixIndex = 0; prefixIndex < prefixes.size(); prefixIndex += 1) {
        for (var suffixIndex = 0; suffixIndex < suffixes.size(); suffixIndex += 1) {
            keys.add(prefixes[prefixIndex] + suffixes[suffixIndex]);
        }
    }
    var originalValues = [];
    for (var index = 0; index < keys.size(); index += 1) {
        originalValues.add(Storage.getValue(keys[index]));
    }
    var now = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
    Storage.setValue(keys[3], 45.0);
    var hourStart = now.hour * 60;
    var cache = new TibberPriceCache();
    cache.storeDailyPrices("QUARTER_HOURLY", false, {
        "intervals" => [
            [hourStart, 100.4, 10.0],
            [hourStart + 15, 100.4, 30.0],
            [hourStart + 30, 100.4, 50.0],
            [hourStart + 45, 100.4, 70.0]
        ],
        "resolution_minutes" => 15,
        "span_minutes" => 1440,
        "currency" => "SEK",
        "tomorrow_available" => false
    });
    Storage.setValue(keys[0], true);
    Storage.setValue(keys[1], 20.5);
    Storage.setValue(keys[2], 10.0);
    var priceData = cache.getCurrentPrice("QUARTER_HOURLY");
    var total = cache.getDisplayPrice(priceData, "TOTAL");
    var repeated = cache.getDisplayPrice(cache.getCurrentPrice("QUARTER_HOURLY"), "TOTAL");
    Storage.setValue(keys[1], 30.5);
    var updated = cache.getDisplayPrice(priceData, "TOTAL");
    Storage.setValue(keys[0], false);
    var disabled = cache.getDisplayPrice(priceData, "TOTAL");
    for (var index = 0; index < keys.size(); index += 1) {
        if (originalValues[index] == null) {
            Storage.deleteValue(keys[index]);
        } else {
            Storage.setValue(keys[index], originalValues[index]);
        }
    }
    return priceData.get("hourly_spot_average") == 40.0 && total.equals("171") &&
        repeated.equals("171") && updated.equals("181") && disabled.equals("100");
}

(:test)
function testKraftringenNetworkFeeIncludingVat(logger) {
    var fixedKey = "tibber_network_fixed_ore";
    var percentKey = "tibber_network_variable_percent";
    var taxKey = "tibber_energy_tax_ore";
    var originalFixed = Storage.getValue(fixedKey);
    var originalPercent = Storage.getValue(percentKey);
    var originalTax = Storage.getValue(taxKey);
    Storage.setValue(fixedKey, 20.0);
    Storage.setValue(percentKey, 5.0);
    Storage.setValue(taxKey, 45.0);
    var calculator = new TibberPriceCache();
    var fee = calculator.getNetworkFee(120.0);
    var zeroSpotFee = calculator.getNetworkFee(0.0);
    var finalPrice = calculator.getPriceWithNetworkFees(200.0, 120.0);
    if (originalFixed == null) {
        Storage.deleteValue(fixedKey);
    } else {
        Storage.setValue(fixedKey, originalFixed);
    }
    if (originalPercent == null) {
        Storage.deleteValue(percentKey);
    } else {
        Storage.setValue(percentKey, originalPercent);
    }
    if (originalTax == null) {
        Storage.deleteValue(taxKey);
    } else {
        Storage.setValue(taxKey, originalTax);
    }
    return fee == 72.5 && fee * 10 / 100 == 7.25 && zeroSpotFee == 65.0 && finalPrice == 272.5;
}

(:test)
function testEnergyTaxOverride(logger) {
    var keys = ["tibber_energy_tax_ore", "tibber_network_fees_enabled", "tibber_network_fixed_ore", "tibber_network_variable_percent"];
    var originalValues = [];
    for (var index = 0; index < keys.size(); index += 1) {
        originalValues.add(Storage.getValue(keys[index]));
    }
    var cache = new TibberPriceCache();
    var priceData = {
        "current_price" => "100",
        "current_spot_price" => "40",
        "current_price_value" => 100.0,
        "hourly_spot_average" => 50.0
    };
    Storage.deleteValue(keys[0]);
    Storage.setValue(keys[1], false);
    var defaultTax = cache.getEnergyTax();
    var standardTotal = cache.getDisplayPrice(priceData, "TOTAL");
    Storage.setValue(keys[0], 33.0);
    var reducedTotal = cache.getDisplayPrice(priceData, "TOTAL");
    Storage.setValue(keys[1], true);
    Storage.setValue(keys[2], 20.0);
    Storage.setValue(keys[3], 5.0);
    var withNetwork = cache.getDisplayPrice(priceData, "TOTAL");
    var spot = cache.getDisplayPrice(priceData, "SPOT");
    var detail = new TibberNetworkFeeDetailView(5, null, null, null);
    Storage.setValue(keys[0], 0);
    detail.adjust(-1);
    var minimum = Storage.getValue(keys[0]);
    Storage.setValue(keys[0], 1000);
    detail.adjust(1);
    var maximum = Storage.getValue(keys[0]);
    for (var index = 0; index < keys.size(); index += 1) {
        if (originalValues[index] == null) {
            Storage.deleteValue(keys[index]);
        } else {
            Storage.setValue(keys[index], originalValues[index]);
        }
    }
    return defaultTax == 45.0 && standardTotal.equals("100") && reducedTotal.equals("100") &&
        withNetwork.equals("156") && spot.equals("40") && minimum == 0 && maximum == 1000 &&
        priceData.get("current_price").equals("100");
}

(:test)
function testConfirmedTibberPriceBaseline(logger) {
    var keys = ["tibber_network_fixed_ore", "tibber_network_variable_percent", "tibber_energy_tax_ore"];
    var originalValues = [];
    for (var index = 0; index < keys.size(); index += 1) {
        originalValues.add(Storage.getValue(keys[index]));
    }
    Storage.setValue(keys[0], 20.0);
    Storage.setValue(keys[1], 5.0);
    var cases = [
        [200.0, 120.0, 45.0, 272.5],
        [200.0, 0.0, 45.0, 265.0],
        [200.0, 120.0, 33.0, 260.5],
        [200.0, 120.0, 0.0, 227.5]
    ];
    var calculator = new TibberPriceCache();
    var passed = true;
    for (var caseIndex = 0; caseIndex < cases.size(); caseIndex += 1) {
        var reference = cases[caseIndex];
        Storage.setValue(keys[2], reference[2]);
        var actual = calculator.getPriceWithNetworkFees(reference[0], reference[1]);
        if (actual != reference[3]) {
            logger.debug("Price baseline case " + caseIndex + ": expected " + reference[3] + ", got " + actual);
            passed = false;
        }
    }
    for (var index = 0; index < keys.size(); index += 1) {
        if (originalValues[index] == null) {
            Storage.deleteValue(keys[index]);
        } else {
            Storage.setValue(keys[index], originalValues[index]);
        }
    }
    return passed;
}