import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;

/**
 * Defaults edited in the Garmin Connect app (resources/settings/settings.xml) are copied into the
 * same Storage keys the watch's own settings screen writes, so pricing code reads one place.
 * A phone value is applied only when it differs from the last value applied (marker key), so a
 * later change on the watch stays until the phone setting changes again: the last change wins.
 * Defaults below must match resources/properties.xml. Grid fees and energy tax only apply to
 * Swedish (SEK) contracts: TibberCurrency.feesActive ignores them for other currencies, and their
 * setting titles say "Sweden only".
 */
(:glance)
module TibberPhoneSettings {
    const MARKER_PREFIX = "tibber_phone_";

    /** Copy changed phone settings into Storage. Returns true when any value was applied. */
    function apply() {
        var changed = false;
        changed = applyValue("priceType", "tibber_price_type", "TOTAL", fromIndex(readProperty("priceType"), ["TOTAL", "SPOT"])) || changed;
        changed = applyValue("priceResolution", "tibber_price_resolution", "QUARTER_HOURLY", fromIndex(readProperty("priceResolution"), ["QUARTER_HOURLY", "HOURLY"])) || changed;
        changed = applyValue("networkFeesEnabled", "tibber_network_fees_enabled", false, readProperty("networkFeesEnabled")) || changed;
        changed = applyValue("networkFixedFeeOre", "tibber_network_fixed_ore", 20, readProperty("networkFixedFeeOre")) || changed;
        changed = applyValue("networkVariablePercent", "tibber_network_variable_percent", 5, readProperty("networkVariablePercent")) || changed;
        changed = applyValue("energyTaxOre", "tibber_energy_tax_ore", 45, readProperty("energyTaxOre")) || changed;
        return changed;
    }

    /** Apply one phone value if it is valid and differs from the last applied (or default) value. */
    function applyValue(propertyId, storageKey, defaultValue, value) {
        if (!isValid(propertyId, value)) {
            return false;
        }
        var markerKey = MARKER_PREFIX + propertyId;
        var applied = Storage.getValue(markerKey);
        if (applied == null) {
            applied = defaultValue;
        }
        if (isSame(value, applied)) {
            return false;
        }
        Storage.setValue(storageKey, value);
        Storage.setValue(markerKey, value);
        return true;
    }

    /** List settings are numeric indexes in the app settings; map one to its Storage string, or null if invalid. */
    function fromIndex(index, values as Array<String>) {
        if (index instanceof Number && index >= 0 && index < values.size()) {
            return values[index as Number];
        }
        return null;
    }

    function readProperty(propertyId) {
        try {
            return Application.Properties.getValue(propertyId);
        } catch (e) {
            return null;
        }
    }

    function isSame(left, right) {
        if (left instanceof String) {
            return right instanceof String && left.equals(right);
        }
        return left == right;
    }

    function isValid(propertyId, value) {
        if (value == null) {
            return false;
        }
        if (propertyId.equals("priceType")) {
            return value instanceof String && (value.equals("TOTAL") || value.equals("SPOT"));
        } else if (propertyId.equals("priceResolution")) {
            return value instanceof String && (value.equals("QUARTER_HOURLY") || value.equals("HOURLY"));
        } else if (propertyId.equals("networkFeesEnabled")) {
            return value instanceof Boolean;
        } else if (propertyId.equals("networkVariablePercent")) {
            return (value instanceof Number || value instanceof Float) && value >= 0 && value <= 100;
        }
        return (value instanceof Number || value instanceof Float) && value >= 0 && value <= 1000;
    }
}
