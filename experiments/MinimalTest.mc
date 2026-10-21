import Toybox.Application;
import Toybox.Graphics;
import Toybox.WatchUi;

class MinimalTestApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [ new MinimalTestView() ];
    }
}

class MinimalTestView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.clear();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(50, 50, Graphics.FONT_MEDIUM, "TEST", Graphics.TEXT_JUSTIFY_LEFT);
    }
}