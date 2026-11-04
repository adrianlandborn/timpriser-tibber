import Toybox.Application.Storage;
import Toybox.Lang;

/** Currency rules: minor-unit display (SEK/NOK/EUR x100) and Sweden-only grid fee support. */
(:glance)
module TibberCurrency {
    function isMinorUnit(currency) {
        return currency != null && (currency.equals("SEK") || currency.equals("NOK") || currency.equals("EUR"));
    }

    /** Multiplier from Tibber's major-unit price to the displayed minor unit; 1 for unknown currencies. */
    function minorUnitFactor(currency) {
        return isMinorUnit(currency) ? 100 : 1;
    }

    /**
     * Unit shown next to a price. Derived only from the currency Tibber returns, never from the watch
     * language, so a Swedish contract on a German watch still reads "öre". Unknown currencies show their code.
     */
    function unitLabel(currency) {
        if (currency == null || currency.equals("SEK")) {
            return "öre";
        }
        if (currency.equals("NOK")) {
            return "øre";
        }
        if (currency.equals("EUR")) {
            return "cent";
        }
        return currency;
    }

    /** Grid fees and energy tax model Swedish tariffs; an unknown currency (no data yet) keeps them available. */
    function feesSupported(currency) {
        return currency == null || currency.equals("SEK");
    }

    function feesActive(currency) {
        return feesSupported(currency) && Storage.getValue("tibber_network_fees_enabled") == true;
    }
}
