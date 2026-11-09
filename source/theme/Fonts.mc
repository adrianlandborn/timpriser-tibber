import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

/**
 * Devices on Connect IQ API 3.1 or older (fenix 5X) draw the custom Poppins bitmap fonts as
 * garbled glyphs once more than the first screen is shown, so they use the built-in system
 * fonts instead. Layout is derived from font heights, so it adapts to either set.
 */
module TibberFonts {
    /** True when the device's Connect IQ API is older than 3.2 and system fonts must be used. */
    function useSystemFonts() as Boolean {
        var version = System.getDeviceSettings().monkeyVersion;
        if (version == null || version.size() < 2) {
            return false;
        }
        return version[0] < 3 || (version[0] == 3 && version[1] < 2);
    }

    /** Describe the font choice for the log, e.g. "system fonts (API 3.1.6)". */
    function describe() as String {
        var version = System.getDeviceSettings().monkeyVersion;
        var apiText = version == null ? "unknown" : version.toString();
        return (useSystemFonts() ? "system fonts" : "Poppins fonts") + " (Connect IQ API " + apiText + ")";
    }
}
