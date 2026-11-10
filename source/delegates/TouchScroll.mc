import Toybox.System;
import Toybox.WatchUi;

/**
 * Older touch-only devices (vivoactive4, venu): a tap reaches the app only as "select" with no
 * position, and a vertical swipe makes the system exit the widget. There a tap scrolls through
 * the screens instead: main, quarter-hour graph, hourly graph, then back to main.
 */
module TibberTouchScroll {
    /** True on touchscreens without glance support (Connect IQ 3.x); other devices keep the default input. */
    function isEnabled() {
        return System.getDeviceSettings().isTouchScreen && !(WatchUi has :GlanceView);
    }
}
