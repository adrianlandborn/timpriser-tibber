import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

/**
 * Horizontal 24-hour bar colored by price level with a marker for the current time.
 * Levels are a 24-character string of digits "1" (very cheap) to "5" (very expensive).
 */
class HourLevelBar {
    private const COLOR_LEVEL_1 = Graphics.COLOR_BLUE;
    private const COLOR_LEVEL_2 = 0x2A55AA;
    private const COLOR_LEVEL_3 = Graphics.COLOR_DK_GRAY;
    private const COLOR_LEVEL_4 = 0xAA5500;
    private const COLOR_LEVEL_5 = Graphics.COLOR_ORANGE;
    private const BAR_HEIGHT = 6;
    private const MARKER_HEIGHT = 14;

    /** Total height the bar occupies, including the marker. */
    function getHeight() {
        return MARKER_HEIGHT;
    }

    /** Return whether the value is a valid 24-hour level string. */
    function isValid(hourLevels) {
        return hourLevels instanceof String && (hourLevels as String).length() == 24;
    }

    function draw(dc, x, top, width, hourLevels as String) {
        var barY = top + (MARKER_HEIGHT - BAR_HEIGHT) / 2;
        for (var hour = 0; hour < 24; hour++) {
            var segmentStart = x + hour * width / 24;
            var segmentEnd = x + (hour + 1) * width / 24;
            dc.setColor(getLevelColor(hourLevels.substring(hour, hour + 1)), Graphics.COLOR_BLACK);
            dc.fillRectangle(segmentStart, barY, segmentEnd - segmentStart - 1, BAR_HEIGHT);
        }

        var now = System.getClockTime();
        var markerX = x + (now.hour * 60 + now.min) * width / 1440;
        var markerColor = getLevelColor(hourLevels.substring(now.hour, now.hour + 1));
        if (markerColor == COLOR_LEVEL_3) {
            markerColor = Graphics.COLOR_WHITE;
        }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(markerX - 2, top, 5, MARKER_HEIGHT);
        dc.setColor(markerColor, Graphics.COLOR_BLACK);
        dc.fillRectangle(markerX - 1, top, 3, MARKER_HEIGHT);
    }

    private function getLevelColor(levelClass) {
        if (levelClass.equals("1")) {
            return COLOR_LEVEL_1;
        }
        if (levelClass.equals("2")) {
            return COLOR_LEVEL_2;
        }
        if (levelClass.equals("4")) {
            return COLOR_LEVEL_4;
        }
        if (levelClass.equals("5")) {
            return COLOR_LEVEL_5;
        }
        return COLOR_LEVEL_3;
    }
}
