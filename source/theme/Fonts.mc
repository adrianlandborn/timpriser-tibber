import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

/**
 * Devices on Connect IQ API 3.1 or older (fenix 5X) and the other button devices without glance
 * support (fenix 5 Plus family, Forerunner 645 Music) draw the custom Poppins bitmap fonts badly,
 * so they use the built-in system fonts instead. Layout is derived from font heights, so it adapts
 * to either set.
 */
module TibberFonts {
    /** True on pre-glance button devices or when the Connect IQ API is older than 3.2. */
    function useSystemFonts() as Boolean {
        var settings = System.getDeviceSettings();
        if (!(WatchUi has :GlanceView) && !settings.isTouchScreen) {
            return true;
        }
        var version = settings.monkeyVersion;
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
