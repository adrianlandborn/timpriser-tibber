import Toybox.Application.Storage;

function phoneSettingsRestore(key, value) {
    if (value == null) {
        Storage.deleteValue(key);
    } else {
        Storage.setValue(key, value);
    }
}

(:test)
function testPhoneSettingLastChangeWins(logger) {
    var storageKey = "tibber_price_type";
    var markerKey = "tibber_phone_priceType";
    var savedValue = Storage.getValue(storageKey);
    var savedMarker = Storage.getValue(markerKey);
    Storage.deleteValue(markerKey);
    Storage.setValue(storageKey, "TOTAL");

    var applied = TibberPhoneSettings.applyValue("priceType", storageKey, "TOTAL", "SPOT");
    var phoneApplied = applied && "SPOT".equals(Storage.getValue(storageKey));

    // A later watch change survives while the phone value is unchanged.
    Storage.setValue(storageKey, "TOTAL");
    var unchanged = !TibberPhoneSettings.applyValue("priceType", storageKey, "TOTAL", "SPOT")
        && "TOTAL".equals(Storage.getValue(storageKey));

    // Changing the phone value again overrides the watch.
    var reapplied = TibberPhoneSettings.applyValue("priceType", storageKey, "TOTAL", "TOTAL")
        && "TOTAL".equals(Storage.getValue(storageKey));

    phoneSettingsRestore(storageKey, savedValue);
    phoneSettingsRestore(markerKey, savedMarker);
    return phoneApplied && unchanged && reapplied;
}

(:test)
function testPhoneSettingDefaultKeepsWatchValue(logger) {
    var storageKey = "tibber_network_fixed_ore";
    var markerKey = "tibber_phone_networkFixedFeeOre";
    var savedValue = Storage.getValue(storageKey);
    var savedMarker = Storage.getValue(markerKey);
    Storage.deleteValue(markerKey);
    Storage.setValue(storageKey, 33);

    // No marker and a phone value equal to the default: leave the watch's 33 alone.
    var untouched = !TibberPhoneSettings.applyValue("networkFixedFeeOre", storageKey, 20, 20)
        && Storage.getValue(storageKey) == 33;
    var applied = TibberPhoneSettings.applyValue("networkFixedFeeOre", storageKey, 20, 25)
        && Storage.getValue(storageKey) == 25;

    phoneSettingsRestore(storageKey, savedValue);
    phoneSettingsRestore(markerKey, savedMarker);
    return untouched && applied;
}

(:test)
function testPhoneSettingRejectsInvalidValues(logger) {
    var storageKey = "tibber_network_variable_percent";
    var markerKey = "tibber_phone_networkVariablePercent";
    var savedValue = Storage.getValue(storageKey);
    var savedMarker = Storage.getValue(markerKey);
    Storage.setValue(storageKey, 7);
    Storage.deleteValue(markerKey);

    var rejected = !TibberPhoneSettings.applyValue("networkVariablePercent", storageKey, 5, 101)
        && !TibberPhoneSettings.applyValue("networkVariablePercent", storageKey, 5, -1)
        && !TibberPhoneSettings.applyValue("networkVariablePercent", storageKey, 5, null)
        && !TibberPhoneSettings.applyValue("priceType", "tibber_price_type", "TOTAL", "BOGUS")
        && !TibberPhoneSettings.applyValue("priceResolution", "tibber_price_resolution", "QUARTER_HOURLY", 5)
        && !TibberPhoneSettings.applyValue("networkFeesEnabled", "tibber_network_fees_enabled", false, "yes");
    var kept = Storage.getValue(storageKey) == 7;

    phoneSettingsRestore(storageKey, savedValue);
    phoneSettingsRestore(markerKey, savedMarker);
    return rejected && kept;
}
