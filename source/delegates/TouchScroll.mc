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

    /**
     * True on devices without glance support (Connect IQ 3.x), touch or button. On the main screen of
     * such a widget the system keeps UP/DOWN for its widget loop and exits the app, so START opens
     * the graphs from there. Button devices still use UP/DOWN on the graph and settings screens.
     */
    function startOpensGraphs() {
        return !(WatchUi has :GlanceView);
    }
}
