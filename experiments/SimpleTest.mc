import Toybox.Application;
import Toybox.Graphics;
import Toybox.WatchUi;

class SimpleTestApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [ new SimpleTestView() ];
    }
}

class SimpleTestView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_WHITE);
        dc.clear();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(100, 100, Graphics.FONT_LARGE, "TIBBER", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(100, 140, Graphics.FONT_MEDIUM, "ENERGY", Graphics.TEXT_JUSTIFY_LEFT);
    }
}