import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

/**
 * Horizontal 24-hour bar colored by price level with a marker for the current time.
 * Levels are a 24-character string of digits "1" (very cheap) to "5" (very expensive).
 */
class HourLevelBar {
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
            dc.setColor(getLevelColor(hourLevels.substring(hour, hour + 1)), Theme.BACKGROUND);
            dc.fillRectangle(segmentStart, barY, segmentEnd - segmentStart - 1, BAR_HEIGHT);
        }

        dc.setColor(Theme.TEXT_SECONDARY, Theme.BACKGROUND);
        for (var tickHour = 0; tickHour <= 24; tickHour += 6) {
            var tickX = tickHour == 24 ? x + width - 1 : x + tickHour * width / 24;
            dc.fillRectangle(tickX, barY + BAR_HEIGHT + 1, 1, 2);
        }

        var now = System.getClockTime();
        var markerX = x + (now.hour * 60 + now.min) * width / 1440;
        var markerColor = getLevelColor(hourLevels.substring(now.hour, now.hour + 1));
        if (markerColor == Theme.LEVEL_3) {
            markerColor = Theme.TEXT_PRIMARY;
        }
        dc.setColor(Theme.BACKGROUND, Theme.BACKGROUND);
        dc.fillRectangle(markerX - 2, top, 5, MARKER_HEIGHT);
        dc.setColor(markerColor, Theme.BACKGROUND);
        dc.fillRectangle(markerX - 1, top, 3, MARKER_HEIGHT);
    }

    /** Return the color for a Tibber level code 1 (very cheap) to 5 (very expensive); unknown codes use the normal color. */
    function getColorForCode(levelCode) {
        return getLevelColor(levelCode.toString());
    }

    private function getLevelColor(levelClass) {
        if (levelClass.equals("1")) {
            return Theme.LEVEL_1;
        }
        if (levelClass.equals("2")) {
            return Theme.LEVEL_2;
        }
        if (levelClass.equals("4")) {
            return Theme.LEVEL_4;
        }
        if (levelClass.equals("5")) {
            return Theme.LEVEL_5;
        }
        return Theme.LEVEL_3;
    }
}
